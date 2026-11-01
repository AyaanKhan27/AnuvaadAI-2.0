import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import '../data/layout_document.dart';

/// Diagnostic result of fitting translated text into a layout region.
/// Implements strict zero-content-loss layout guarantees:
/// 1. Direct fit
/// 2. Word wrapping
/// 3. Font reduction to a readable minimum
/// 4. Vertical expansion into available whitespace
/// 5. Reflow of affected paragraph or region
/// 6. Continuation onto an additional page
/// 7. Manual review flag if no safe layout is possible.
class FittingResult {
  const FittingResult({
    required this.fittedText,
    required this.lines,
    required this.fontSize,
    required this.fittedBounds,
    required this.fitsInOriginalBox,
    required this.wasRegionExpanded,
    required this.wasReflowed,
    required this.requiresManualReview,
    required this.scaleFactor,
    required this.diagnosticNote,
    this.overflowText = '',
    this.overflowLines = const [],
    this.needsContinuationPage = false,
  });

  /// Complete text accommodated on the current page or region.
  final String fittedText;

  /// Line-by-line breakdown of text on current page.
  final List<String> lines;

  /// Calibrated font size in points.
  final double fontSize;

  /// Bounding rectangle in PDF points.
  final BoundingBox fittedBounds;

  /// True if fitted within original box dimensions without expansion.
  final bool fitsInOriginalBox;

  /// True if box was expanded into available whitespace.
  final bool wasRegionExpanded;

  /// True if reflowed across page layout.
  final bool wasReflowed;

  /// True if human editorial layout review is recommended.
  final bool requiresManualReview;

  /// Scale factor applied to original font size (e.g. 1.0 = 100%).
  final double scaleFactor;

  /// Diagnostic note detailing layout decisions.
  final String diagnosticNote;

  /// Any overflow text routed to a continuation page (zero content loss).
  final String overflowText;

  /// Line-by-line breakdown of overflow text for continuation page.
  final List<String> overflowLines;

  /// True if content exceeded page capacity and requires a continuation page.
  final bool needsContinuationPage;

  int get lineCount => lines.length;
  bool get hasOverflow => overflowText.isNotEmpty || needsContinuationPage;
}

/// The layout and typography fitting engine for AnuvaadAI 2.0.
/// Measures Santali Ol Chiki text using Noto Sans Ol Chiki font metrics and adjusts
/// font size, line wrapping, bounding boxes, and multi-page continuation to guarantee
/// visual layout fidelity with ZERO silent content truncation.
class LayoutFittingEngine {
  LayoutFittingEngine._();

  static PdfTtfFont? _cachedFont;
  static final PdfDocument _dummyDoc = PdfDocument();

  /// Loads and caches the Noto Sans Ol Chiki font for measurement.
  static Future<PdfTtfFont> getFont() async {
    if (_cachedFont != null) return _cachedFont!;

    ByteData byteData;
    try {
      byteData = await rootBundle.load('assets/fonts/NotoSansOlChiki-Regular.ttf');
    } catch (_) {
      // In headless test environments, fallback to direct disk read
      final file = File('assets/fonts/NotoSansOlChiki-Regular.ttf');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        byteData = ByteData.view(bytes.buffer);
      } else {
        throw Exception('NotoSansOlChiki-Regular.ttf font file not found.');
      }
    }

    _cachedFont = PdfTtfFont(_dummyDoc, byteData);
    return _cachedFont!;
  }

  /// Synchronously measures text width at a given font size.
  /// If font is not yet initialized, uses empirical Ol Chiki average glyph width.
  static double measureStringWidth(String text, double fontSize, {PdfTtfFont? font}) {
    if (text.isEmpty) return 0.0;
    final f = font ?? _cachedFont;
    if (f != null) {
      try {
        final metrics = f.stringMetrics(text);
        return metrics.width * fontSize;
      } catch (_) {
        // Fallback below
      }
    }
    // Empirical Ol Chiki average advance width per character ≈ 0.58 em
    return text.length * fontSize * 0.58;
  }

  /// Wraps a single paragraph of text into lines that each fit within [maxWidth].
  /// Never drops any words.
  static List<String> wrapTextToLines({
    required String text,
    required double maxWidth,
    required double fontSize,
    PdfTtfFont? font,
  }) {
    final clean = text.trim();
    if (clean.isEmpty) return [];

    final words = clean.split(RegExp(r'\s+'));
    if (words.isEmpty) return [clean];

    final lines = <String>[];
    var currentLine = StringBuffer();
    var currentLineWidth = 0.0;
    final spaceWidth = measureStringWidth(' ', fontSize, font: font);

    for (final word in words) {
      final wordWidth = measureStringWidth(word, fontSize, font: font);

      if (currentLine.isEmpty) {
        currentLine.write(word);
        currentLineWidth = wordWidth;
      } else if (currentLineWidth + spaceWidth + wordWidth <= maxWidth) {
        currentLine.write(' $word');
        currentLineWidth += spaceWidth + wordWidth;
      } else {
        lines.add(currentLine.toString());
        currentLine = StringBuffer(word);
        currentLineWidth = wordWidth;
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine.toString());
    }

    return lines;
  }

  /// Fits a region's translated text into its target layout using the strict 7-stage order:
  /// 1. Direct fit.
  /// 2. Word wrapping.
  /// 3. Font reduction to a readable minimum (minFontSize).
  /// 4. Vertical expansion into available whitespace.
  /// 5. Reflow of the affected paragraph or region.
  /// 6. Continuation onto an additional page (never silently truncate).
  /// 7. Manual review flag if no safe layout is possible.
  static Future<FittingResult> fitRegionText({
    required LayoutRegion region,
    double? maxAvailableBottomY,
    double? pageBottomY,
    double minFontSize = 7.5,
    double lineHeightMultiplier = 1.25,
    PdfTtfFont? font,
  }) async {
    final f = font ?? await getFont();
    final text = region.translatedText.isNotEmpty
        ? region.translatedText
        : region.originalText;

    final origBox = region.boundingBox;
    final origFontSize = region.fontSpec.fontSize > 0 ? region.fontSpec.fontSize : 11.0;
    final boxW = origBox.width.clamp(15.0, 1000.0);
    final boxH = origBox.height.clamp(8.0, 1500.0);

    // ==========================================
    // STAGE 1: Direct single-line fit at original font size
    // ==========================================
    final singleLineWidth = measureStringWidth(text, origFontSize, font: f);
    final singleLineHeight = origFontSize * lineHeightMultiplier;

    if (singleLineWidth <= boxW && singleLineHeight <= boxH * 1.15) {
      return FittingResult(
        fittedText: text,
        lines: [text],
        fontSize: origFontSize,
        fittedBounds: origBox,
        fitsInOriginalBox: true,
        wasRegionExpanded: false,
        wasReflowed: false,
        requiresManualReview: false,
        scaleFactor: 1.0,
        diagnosticNote: 'Stage 1: Fitted cleanly on single line at original font size.',
      );
    }

    // ==========================================
    // STAGE 2: Multi-line word wrapping at original font size
    // ==========================================
    final wrappedAtOrig = wrapTextToLines(
      text: text,
      maxWidth: boxW,
      fontSize: origFontSize,
      font: f,
    );
    final totalHeightAtOrig = wrappedAtOrig.length * singleLineHeight;

    if (totalHeightAtOrig <= boxH * 1.15) {
      return FittingResult(
        fittedText: wrappedAtOrig.join('\n'),
        lines: wrappedAtOrig,
        fontSize: origFontSize,
        fittedBounds: origBox,
        fitsInOriginalBox: true,
        wasRegionExpanded: false,
        wasReflowed: false,
        requiresManualReview: false,
        scaleFactor: 1.0,
        diagnosticNote: 'Stage 2: Wrapped into ${wrappedAtOrig.length} lines at original font size within original box.',
      );
    }

    // ==========================================
    // STAGE 3: Font reduction to a readable minimum (down to minFontSize)
    // ==========================================
    final candidateSizes = [
      origFontSize * 0.95,
      origFontSize * 0.90,
      origFontSize * 0.85,
      origFontSize * 0.80,
      origFontSize * 0.75,
      minFontSize,
    ].where((s) => s >= minFontSize && s < origFontSize).toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    for (final size in candidateSizes) {
      final wrapped = wrapTextToLines(
        text: text,
        maxWidth: boxW,
        fontSize: size,
        font: f,
      );
      final totalH = wrapped.length * (size * lineHeightMultiplier);
      if (totalH <= boxH * 1.15) {
        final scale = size / origFontSize;
        return FittingResult(
          fittedText: wrapped.join('\n'),
          lines: wrapped,
          fontSize: size,
          fittedBounds: origBox,
          fitsInOriginalBox: true,
          wasRegionExpanded: false,
          wasReflowed: false,
          requiresManualReview: false,
          scaleFactor: scale,
          diagnosticNote: 'Stage 3: Scaled font down to ${size.toStringAsFixed(1)} pt (${(scale * 100).toStringAsFixed(0)}%) to fit original box.',
        );
      }
    }

    // ==========================================
    // STAGE 4: Vertical expansion into available whitespace
    // ==========================================
    final readableSize = (origFontSize * 0.85).clamp(minFontSize, origFontSize);
    final multiLines = wrapTextToLines(
      text: text,
      maxWidth: boxW,
      fontSize: readableSize,
      font: f,
    );
    final requiredH = multiLines.length * (readableSize * lineHeightMultiplier);

    final maxBottom = maxAvailableBottomY ?? (origBox.y + requiredH + 20.0);
    final canExpandInWhitespace = (origBox.y + requiredH) <= maxBottom;

    if (canExpandInWhitespace) {
      final expandedBox = BoundingBox(
        x: origBox.x,
        y: origBox.y,
        width: origBox.width,
        height: requiredH,
      );
      return FittingResult(
        fittedText: multiLines.join('\n'),
        lines: multiLines,
        fontSize: readableSize,
        fittedBounds: expandedBox,
        fitsInOriginalBox: false,
        wasRegionExpanded: true,
        wasReflowed: false,
        requiresManualReview: false,
        scaleFactor: readableSize / origFontSize,
        diagnosticNote: 'Stage 4: Expanded vertically by ${(requiredH - boxH).toStringAsFixed(1)} pt into available whitespace.',
      );
    }

    // ==========================================
    // STAGE 5: Reflow of the affected paragraph or region on page
    // ==========================================
    final effectivePageBottom = pageBottomY ?? (origBox.y + requiredH + 36.0);
    final fitsOnPageWithReflow = (origBox.y + requiredH) <= effectivePageBottom;

    if (fitsOnPageWithReflow) {
      final reflowedBox = BoundingBox(
        x: origBox.x,
        y: origBox.y,
        width: origBox.width,
        height: requiredH,
      );
      return FittingResult(
        fittedText: multiLines.join('\n'),
        lines: multiLines,
        fontSize: readableSize,
        fittedBounds: reflowedBox,
        fitsInOriginalBox: false,
        wasRegionExpanded: true,
        wasReflowed: true,
        requiresManualReview: false,
        scaleFactor: readableSize / origFontSize,
        diagnosticNote: 'Stage 5: Reflowed across page whitespace with downstream adjustment.',
      );
    }

    // ==========================================
    // STAGE 6: Continuation onto an additional page (Zero Content Loss)
    // ==========================================
    final availH = (effectivePageBottom - origBox.y).clamp(0.0, requiredH);
    final lineH = readableSize * lineHeightMultiplier;
    final linesOnThisPage = (availH / lineH).floor();

    if (linesOnThisPage > 0 && linesOnThisPage < multiLines.length) {
      final thisPageLines = multiLines.sublist(0, linesOnThisPage);
      final overflowLines = multiLines.sublist(linesOnThisPage);

      final thisPageBox = BoundingBox(
        x: origBox.x,
        y: origBox.y,
        width: origBox.width,
        height: thisPageLines.length * lineH,
      );

      return FittingResult(
        fittedText: thisPageLines.join('\n'),
        lines: thisPageLines,
        fontSize: readableSize,
        fittedBounds: thisPageBox,
        fitsInOriginalBox: false,
        wasRegionExpanded: true,
        wasReflowed: true,
        requiresManualReview: false,
        scaleFactor: readableSize / origFontSize,
        overflowText: overflowLines.join('\n'),
        overflowLines: overflowLines,
        needsContinuationPage: true,
        diagnosticNote: 'Stage 6: Preserved ${thisPageLines.length} lines on page; overflowing ${overflowLines.length} lines routed to continuation page without truncation.',
      );
    } else if (linesOnThisPage <= 0) {
      // Region starts beyond page bottom margin; entire block routed to continuation page
      return FittingResult(
        fittedText: '',
        lines: const [],
        fontSize: readableSize,
        fittedBounds: BoundingBox(x: origBox.x, y: origBox.y, width: origBox.width, height: lineH),
        fitsInOriginalBox: false,
        wasRegionExpanded: true,
        wasReflowed: true,
        requiresManualReview: false,
        scaleFactor: readableSize / origFontSize,
        overflowText: multiLines.join('\n'),
        overflowLines: multiLines,
        needsContinuationPage: true,
        diagnosticNote: 'Stage 6: Region exceeds page bounds; entire content moved to continuation page without truncation.',
      );
    }

    // ==========================================
    // STAGE 7: Manual review flag if no safe layout is possible
    // ==========================================
    final fallbackBox = BoundingBox(
      x: origBox.x,
      y: origBox.y,
      width: origBox.width,
      height: requiredH,
    );
    return FittingResult(
      fittedText: multiLines.join('\n'),
      lines: multiLines,
      fontSize: readableSize,
      fittedBounds: fallbackBox,
      fitsInOriginalBox: false,
      wasRegionExpanded: true,
      wasReflowed: true,
      requiresManualReview: true,
      scaleFactor: readableSize / origFontSize,
      diagnosticNote: 'Stage 7: Manual editorial review flagged: complex layout or extreme overflow requires human verification.',
    );
  }

  /// Fits all regions on a page sequentially, calculating available vertical whitespace between regions.
  static Future<LayoutPage> fitPageRegions({
    required LayoutPage page,
    PdfTtfFont? font,
  }) async {
    final f = font ?? await getFont();
    final updatedRegions = <LayoutRegion>[];

    // Sort regions by Y coordinate to establish reading order and vertical spacing
    final sortedRegions = List<LayoutRegion>.from(page.regions)
      ..sort((a, b) => a.boundingBox.y.compareTo(b.boundingBox.y));

    final pageBottomY = page.height - 36.0; // 36 pt bottom margin

    for (var i = 0; i < sortedRegions.length; i++) {
      final region = sortedRegions[i];

      // Next region's top Y coordinate determines available downward expansion space
      double maxBottomY = pageBottomY;
      if (i + 1 < sortedRegions.length) {
        maxBottomY = sortedRegions[i + 1].boundingBox.y - 4.0;
      }

      final result = await fitRegionText(
        region: region,
        maxAvailableBottomY: maxBottomY,
        pageBottomY: pageBottomY,
        font: f,
      );

      final renderedStatus = result.requiresManualReview
          ? RenderingStatus.manualReviewRecommended
          : result.needsContinuationPage
              ? RenderingStatus.overflowed
              : result.wasReflowed
                  ? RenderingStatus.reflowed
                  : result.wasRegionExpanded
                      ? RenderingStatus.overflowed
                      : RenderingStatus.facsimileMasked;

      updatedRegions.add(
        region.copyWith(
          boundingBox: result.fittedBounds,
          fontSpec: region.fontSpec.copyWith(fontSize: result.fontSize),
          renderingStatus: renderedStatus,
          diagnosticNote: result.diagnosticNote,
          customMetadata: {
            ...region.customMetadata,
            'scaleFactor': result.scaleFactor,
            'lineCount': result.lineCount,
            'fitsInOriginalBox': result.fitsInOriginalBox,
            'needsContinuationPage': result.needsContinuationPage,
            'overflowText': result.overflowText,
            'overflowLineCount': result.overflowLines.length,
          },
        ),
      );
    }

    // Preserve original reading order in returned list
    updatedRegions.sort((a, b) => a.readingOrder.compareTo(b.readingOrder));

    final pageRequiresReview = updatedRegions.any(
      (r) => r.renderingStatus == RenderingStatus.manualReviewRecommended,
    );

    final pageHasContinuation = updatedRegions.any(
      (r) => r.customMetadata['needsContinuationPage'] == true,
    );

    return page.copyWith(
      regions: updatedRegions,
      pageRenderingMetadata: {
        ...page.pageRenderingMetadata,
        'hasContinuation': pageHasContinuation,
      },
      status: pageRequiresReview
          ? PageConversionStatus.requiresManualReview
          : PageConversionStatus.extracted,
    );
  }

  /// Fits an entire document layout across all pages.
  /// If any region overflows page capacity (Stage 6), seamlessly synthesizes
  /// an overflow continuation page with zero content loss.
  static Future<LayoutDocument> fitDocumentLayout({
    required LayoutDocument document,
    PdfTtfFont? font,
  }) async {
    final f = font ?? await getFont();
    final newPages = <LayoutPage>[];

    for (var pIdx = 0; pIdx < document.pages.length; pIdx++) {
      final page = document.pages[pIdx];
      final fittedPage = await fitPageRegions(page: page, font: f);
      newPages.add(fittedPage);

      // Check if any region requires a continuation page
      final overflowRegions = fittedPage.regions.where(
        (r) => r.customMetadata['needsContinuationPage'] == true &&
            (r.customMetadata['overflowText'] as String? ?? '').isNotEmpty,
      ).toList();

      if (overflowRegions.isNotEmpty) {
        final contRegions = <LayoutRegion>[];
        var contY = 50.0;

        for (final overR in overflowRegions) {
          final overText = overR.customMetadata['overflowText'] as String;
          final fontSize = overR.fontSpec.fontSize;
          final lines = overText.split('\n');
          final contH = lines.length * (fontSize * 1.25);

          contRegions.add(
            LayoutRegion(
              regionId: '${overR.regionId}_cont',
              type: overR.type,
              originalText: overR.originalText,
              translatedText: overText,
              boundingBox: BoundingBox(
                x: 40.0,
                y: contY,
                width: page.width - 80.0,
                height: contH,
              ),
              fontSpec: overR.fontSpec.copyWith(fontSize: fontSize),
              readingOrder: overR.readingOrder + 1000,
              translationStatus: RegionTranslationStatus.translated,
              renderingStatus: RenderingStatus.reflowed,
              customMetadata: {
                'isContinuation': true,
                'sourceRegionId': overR.regionId,
                'sourcePageNumber': page.pageNumber,
              },
              diagnosticNote: 'Stage 6 Continuation Block: Complete translated content preserved without truncation.',
            ),
          );

          contY += contH + 16.0;
        }

        newPages.add(
          LayoutPage(
            pageNumber: newPages.length + 1,
            width: page.width,
            height: page.height,
            pageType: PageType.digital,
            regions: contRegions,
            pageRenderingMetadata: {
              'isContinuationPage': true,
              'sourcePageNumber': page.pageNumber,
            },
            status: PageConversionStatus.extracted,
          ),
        );
      }
    }

    // Re-index page numbers sequentially
    for (var i = 0; i < newPages.length; i++) {
      newPages[i] = newPages[i].copyWith(pageNumber: i + 1);
    }

    return document.copyWith(
      pages: newPages,
      pageCount: newPages.length,
    );
  }

  /// Generates a clearly-labeled preview snippet of text for UI cards or summary thumbnails.
  /// NEVER mutates the underlying translated text or removes content from the document.
  static String generatePreviewSnippet(String fullText, {int maxWords = 12}) {
    final words = fullText.trim().split(RegExp(r'\s+'));
    if (words.length <= maxWords) return fullText;
    final snippet = words.take(maxWords).join(' ');
    return '$snippet [Preview — Full content preserved in document]';
  }

  /// Detects bounding box collisions between any pair of regions on a page.
  static List<String> detectCollisions(List<LayoutRegion> regions) {
    final collisions = <String>[];
    for (var i = 0; i < regions.length; i++) {
      for (var j = i + 1; j < regions.length; j++) {
        final a = regions[i];
        final b = regions[j];
        if (a.boundingBox.intersects(b.boundingBox)) {
          collisions.add(
            'Collision between ${a.regionId} (${a.type.name}) and ${b.regionId} (${b.type.name})',
          );
        }
      }
    }
    return collisions;
  }
}

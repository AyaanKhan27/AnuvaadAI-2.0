import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/layout_document.dart';
import 'layout_fitting_engine.dart';
import 'translation_service.dart';

enum PageRenderingMode {
  facsimile,
  reflowReader,
}

/// Diagnostic assessment of background restoration for an individual region.
class RegionRestorationDiagnostics {
  const RegionRestorationDiagnostics({
    required this.regionId,
    required this.confidence,
    required this.colorVariationStdDev,
    required this.nearbyTableBorderDetected,
    required this.nearbyStrongEdgeDetected,
    required this.overlapsImage,
    required this.conservativeMaskApplied,
    required this.requiresManualReview,
    required this.note,
  });

  final String regionId;
  final String confidence; // 'high', 'medium', 'low'
  final double colorVariationStdDev;
  final bool nearbyTableBorderDetected;
  final bool nearbyStrongEdgeDetected;
  final bool overlapsImage;
  final bool conservativeMaskApplied;
  final bool requiresManualReview;
  final String note;
}

/// Comprehensive background restoration report for a page.
class BackgroundRestorationResult {
  const BackgroundRestorationResult({
    required this.imageBytes,
    required this.highConfidenceCount,
    required this.mediumConfidenceCount,
    required this.lowConfidenceCount,
    required this.diagnostics,
  });

  final Uint8List imageBytes;
  final int highConfidenceCount;
  final int mediumConfidenceCount;
  final int lowConfidenceCount;
  final List<RegionRestorationDiagnostics> diagnostics;

  bool get hasLowConfidenceRegions => lowConfidenceCount > 0;
}

/// Hybrid PDF Reconstruction Engine for AnuvaadAI 2.0.
/// Provides:
///  - Mode A (Facsimile): Preserves visual layout, background graphics, tables, and images by masking source text with complexity detection and overlaying selectable Ol Chiki text at exact coordinates.
///  - Mode B (Reflow Reader): Structured classroom flow layout with clean typography for text-heavy or high-reflow pages.
class HybridPdfService {
  HybridPdfService._();

  /// Translates all untranslated regions in a [LayoutDocument] to Santali (Ol Chiki)
  /// using the on-device IndicTrans2 translation engine with delimiter-safe sentence chunking.
  /// Applies whole-document layout fitting with continuation page support (zero content loss).
  static Future<LayoutDocument> translateDocument({
    required LayoutDocument document,
    String srcLang = 'hin_Deva',
    String tgtLang = 'sat_Olck',
    void Function(double progress, String task)? onProgress,
  }) async {
    final updatedPages = <LayoutPage>[];
    final totalRegions = document.totalRegions;
    var completed = 0;

    for (final page in document.pages) {
      final updatedRegions = <LayoutRegion>[];

      for (final region in page.regions) {
        final progress = totalRegions > 0 ? (completed / totalRegions) : 0.0;
        onProgress?.call(
          progress,
          'Translating Page ${page.pageNumber} (${region.type.name} #${region.readingOrder})...',
        );

        // Skip non-text or decorative regions
        if (region.type == RegionType.image ||
            region.originalText.trim().isEmpty) {
          updatedRegions.add(region);
          completed++;
          continue;
        }

        // If already translated or manually edited, keep existing
        if (region.translationStatus == RegionTranslationStatus.manuallyEdited &&
            region.translatedText.isNotEmpty) {
          updatedRegions.add(region);
          completed++;
          continue;
        }

        try {
          final translated = await _translateTextSafely(region.originalText, srcLang, tgtLang);
          updatedRegions.add(
            region.copyWith(
              translatedText: translated,
              translationStatus: RegionTranslationStatus.translated,
            ),
          );
        } catch (e) {
          updatedRegions.add(
            region.copyWith(
              translatedText: region.originalText, // fallback to source text
              translationStatus: RegionTranslationStatus.failed,
              diagnosticNote: 'Translation error: $e',
            ),
          );
        }

        completed++;
      }

      updatedPages.add(page.copyWith(regions: updatedRegions));
    }

    onProgress?.call(1.0, 'Translation complete! Running document layout fitting...');

    final translatedDoc = document.copyWith(
      pages: updatedPages,
      conversionStatus: ConversionStatus.translated,
    );

    // Run whole-document layout fitting with multi-page overflow continuation
    final fittedDoc = await LayoutFittingEngine.fitDocumentLayout(document: translatedDoc);

    return fittedDoc;
  }

  /// Sentence-chunked translation using native IndicTrans2 engine.
  static Future<String> _translateTextSafely(
    String text,
    String srcLang,
    String tgtLang,
  ) async {
    final clean = text.trim();
    if (clean.isEmpty) return '';

    // If small sentence or phrase (< 80 chars), translate directly
    if (clean.length < 80) {
      final res = await TranslationService.translate(clean, srcLang: srcLang, tgtLang: tgtLang);
      return res.text;
    }

    // Split on Hindi danda (।), English period (.), exclamation (!), or question mark (?)
    final sentenceRegex = RegExp(r'([^।\.!\?]+[।\.!\?]?)');
    final matches = sentenceRegex.allMatches(clean);

    if (matches.isEmpty) {
      final res = await TranslationService.translate(clean, srcLang: srcLang, tgtLang: tgtLang);
      return res.text;
    }

    final buffer = StringBuffer();
    for (final m in matches) {
      final s = m.group(0)?.trim() ?? '';
      if (s.isEmpty) continue;
      final res = await TranslationService.translate(s, srcLang: srcLang, tgtLang: tgtLang);
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(res.text);
    }

    return buffer.toString().trim();
  }

  /// Samples border pixels around bounding box to estimate background color and inpaint/mask source Hindi text.
  /// Hardened for Phase 2.2 with background-complexity detection, edge analysis, table border protection,
  /// and conservative masking for uncertain regions.
  static Uint8List maskPageImageBackground({
    required Uint8List imageBytes,
    required List<LayoutRegion> regions,
    required double pageWidthPt,
    required double pageHeightPt,
    void Function(BackgroundRestorationResult report)? onReport,
  }) {
    final result = maskPageImageBackgroundDetailed(
      imageBytes: imageBytes,
      regions: regions,
      pageWidthPt: pageWidthPt,
      pageHeightPt: pageHeightPt,
    );
    onReport?.call(result);
    return result.imageBytes;
  }

  /// Detailed background masking that computes color variance, strong edges, table lines,
  /// and returns complete diagnostics without silently degrading visual quality.
  static BackgroundRestorationResult maskPageImageBackgroundDetailed({
    required Uint8List imageBytes,
    required List<LayoutRegion> regions,
    required double pageWidthPt,
    required double pageHeightPt,
  }) {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      return BackgroundRestorationResult(
        imageBytes: imageBytes,
        highConfidenceCount: 0,
        mediumConfidenceCount: 0,
        lowConfidenceCount: 0,
        diagnostics: const [],
      );
    }

    final imgW = image.width;
    final imgH = image.height;
    final scaleX = imgW / pageWidthPt;
    final scaleY = imgH / pageHeightPt;

    final imageRegions = regions.where((r) => r.type == RegionType.image).toList();
    final diagnostics = <RegionRestorationDiagnostics>[];
    int highCount = 0, medCount = 0, lowCount = 0;

    for (final region in regions) {
      // Never mask images or empty text regions
      if (region.type == RegionType.image || region.originalText.trim().isEmpty) {
        continue;
      }

      final box = region.boundingBox;
      final pxX = (box.x * scaleX).round().clamp(0, imgW - 1);
      final pxY = (box.y * scaleY).round().clamp(0, imgH - 1);
      final pxW = (box.width * scaleX).round().clamp(1, imgW - pxX);
      final pxH = (box.height * scaleY).round().clamp(1, imgH - pxY);

      // 1. Check if overlapping or touching any image region
      bool overlapsImg = false;
      for (final ir in imageRegions) {
        if (box.intersects(ir.boundingBox)) {
          overlapsImg = true;
          break;
        }
      }

      // 2. Sample perimeter boundary pixels (2 pixels outside)
      final samplesR = <int>[];
      final samplesG = <int>[];
      final samplesB = <int>[];
      final samplesLum = <double>[];

      void sample(int x, int y) {
        if (x >= 0 && x < imgW && y >= 0 && y < imgH) {
          final p = image.getPixel(x, y);
          samplesR.add(p.r.toInt());
          samplesG.add(p.g.toInt());
          samplesB.add(p.b.toInt());
          samplesLum.add(p.luminance.toDouble());
        }
      }

      // Sample along top and bottom edges (2 pixels outside)
      final step = (pxW > 60) ? (pxW ~/ 20).clamp(2, 6) : 2;
      for (var x = pxX; x < pxX + pxW; x += step) {
        sample(x, pxY - 2);
        sample(x, pxY + pxH + 2);
      }
      // Sample along left and right edges (2 pixels outside)
      final stepY = (pxH > 60) ? (pxH ~/ 20).clamp(2, 6) : 2;
      for (var y = pxY; y < pxY + pxH; y += stepY) {
        sample(pxX - 2, y);
        sample(pxX + pxW + 2, y);
      }

      // Compute statistics
      double meanR = 255.0, meanG = 255.0, meanB = 255.0;
      double colorStdDev = 0.0;
      if (samplesR.isNotEmpty) {
        meanR = samplesR.reduce((a, b) => a + b) / samplesR.length;
        meanG = samplesG.reduce((a, b) => a + b) / samplesG.length;
        meanB = samplesB.reduce((a, b) => a + b) / samplesB.length;

        double varR = 0, varG = 0, varB = 0;
        for (var i = 0; i < samplesR.length; i++) {
          varR += (samplesR[i] - meanR) * (samplesR[i] - meanR);
          varG += (samplesG[i] - meanG) * (samplesG[i] - meanG);
          varB += (samplesB[i] - meanB) * (samplesB[i] - meanB);
        }
        colorStdDev = math.sqrt((varR + varG + varB) / samplesR.length);
      }

      // 3. Detect nearby table borders (dark grid lines along margins)
      bool hasTopBorder = false, hasBottomBorder = false, hasLeftBorder = false, hasRightBorder = false;
      int darkTop = 0, darkBottom = 0, darkLeft = 0, darkRight = 0;
      int countH = 0, countV = 0;

      for (var x = pxX; x < pxX + pxW; x += 2) {
        countH++;
        for (var dy = 1; dy <= 3; dy++) {
          if (pxY - dy >= 0 && image.getPixel(x, pxY - dy).luminance < 110) {
            darkTop++;
            break;
          }
        }
        for (var dy = 1; dy <= 3; dy++) {
          if (pxY + pxH + dy < imgH && image.getPixel(x, pxY + pxH + dy).luminance < 110) {
            darkBottom++;
            break;
          }
        }
      }
      for (var y = pxY; y < pxY + pxH; y += 2) {
        countV++;
        for (var dx = 1; dx <= 3; dx++) {
          if (pxX - dx >= 0 && image.getPixel(pxX - dx, y).luminance < 110) {
            darkLeft++;
            break;
          }
        }
        for (var dx = 1; dx <= 3; dx++) {
          if (pxX + pxW + dx < imgW && image.getPixel(pxX + pxW + dx, y).luminance < 110) {
            darkRight++;
            break;
          }
        }
      }

      if (countH > 0) {
        hasTopBorder = (darkTop / countH) > 0.40;
        hasBottomBorder = (darkBottom / countH) > 0.40;
      }
      if (countV > 0) {
        hasLeftBorder = (darkLeft / countV) > 0.40;
        hasRightBorder = (darkRight / countV) > 0.40;
      }
      final tableBorderDetected = hasTopBorder || hasBottomBorder || hasLeftBorder || hasRightBorder;

      // 4. Detect strong edges (contrast across perimeter)
      bool strongEdgeDetected = false;
      if (samplesLum.length >= 8) {
        double minLum = samplesLum.reduce(math.min);
        double maxLum = samplesLum.reduce(math.max);
        if (maxLum - minLum > 60.0) {
          strongEdgeDetected = true;
        }
      }

      // 5. Determine Confidence & Conservative Masking Policy
      String confidence;
      bool manualReview = false;
      bool conservativeMask = false;
      String note;

      if (overlapsImg) {
        confidence = 'low';
        manualReview = true;
        conservativeMask = true;
        note = 'Region overlaps photograph/illustration; conservative masking applied to prevent graphic damage.';
        lowCount++;
      } else if (tableBorderDetected || (colorStdDev > 35.0) || strongEdgeDetected) {
        confidence = (colorStdDev > 40.0 || overlapsImg) ? 'low' : 'medium';
        manualReview = (confidence == 'low');
        conservativeMask = true;
        note = tableBorderDetected
            ? 'Table border grid lines detected nearby; masking coordinates inset to protect borders.'
            : 'Complex background texture (stdDev: ${colorStdDev.toStringAsFixed(1)}); conservative masking applied.';
        if (confidence == 'low') {
          lowCount++;
        } else {
          medCount++;
        }
      } else if (colorStdDev >= 15.0) {
        confidence = 'medium';
        note = 'Moderate background variation (stdDev: ${colorStdDev.toStringAsFixed(1)}); standard median inpaint applied.';
        medCount++;
      } else {
        confidence = 'high';
        note = 'Uniform background (stdDev: ${colorStdDev.toStringAsFixed(1)}); high confidence perimeter inpaint.';
        highCount++;
      }

      // 6. Apply Inpainting with Conservative Margin Inset
      if (overlapsImg) {
        // Do NOT aggressively obliterate photos!
        // Skip inpainting and let vector text overlay or manual editorial adjustment handle it.
      } else {
        final insetL = hasLeftBorder ? 2 : (conservativeMask ? 1 : 0);
        final insetR = hasRightBorder ? 2 : (conservativeMask ? 1 : 0);
        final insetT = hasTopBorder ? 2 : (conservativeMask ? 1 : 0);
        final insetB = hasBottomBorder ? 2 : (conservativeMask ? 1 : 0);

        final fillX1 = (pxX + insetL).clamp(0, imgW - 1);
        final fillY1 = (pxY + insetT).clamp(0, imgH - 1);
        final fillX2 = (pxX + pxW - insetR).clamp(fillX1 + 1, imgW);
        final fillY2 = (pxY + pxH - insetB).clamp(fillY1 + 1, imgH);

        final fillColor = img.ColorRgb8(meanR.round(), meanG.round(), meanB.round());

        img.fillRect(
          image,
          x1: fillX1,
          y1: fillY1,
          x2: fillX2,
          y2: fillY2,
          color: fillColor,
        );
      }

      // Record diagnostic evidence in region metadata
      region.customMetadata = Map<String, dynamic>.from(region.customMetadata);
      region.customMetadata['backgroundComplexity'] = (colorStdDev > 35.0 || overlapsImg || strongEdgeDetected)
          ? 'complex'
          : (colorStdDev >= 15.0 ? 'moderate' : 'uniform');
      region.customMetadata['restorationConfidence'] = confidence;
      region.customMetadata['colorVariationStdDev'] = double.parse(colorStdDev.toStringAsFixed(1));
      region.customMetadata['nearbyTableBorderDetected'] = tableBorderDetected;
      region.customMetadata['nearbyStrongEdgeDetected'] = strongEdgeDetected;
      region.customMetadata['overlapsImage'] = overlapsImg;
      region.customMetadata['requiresManualReview'] = manualReview;
      region.diagnosticNote = note;

      diagnostics.add(
        RegionRestorationDiagnostics(
          regionId: region.regionId,
          confidence: confidence,
          colorVariationStdDev: colorStdDev,
          nearbyTableBorderDetected: tableBorderDetected,
          nearbyStrongEdgeDetected: strongEdgeDetected,
          overlapsImage: overlapsImg,
          conservativeMaskApplied: conservativeMask,
          requiresManualReview: manualReview,
          note: note,
        ),
      );
    }

    final encodedJpg = Uint8List.fromList(img.encodeJpg(image, quality: 85));
    return BackgroundRestorationResult(
      imageBytes: encodedJpg,
      highConfidenceCount: highCount,
      mediumConfidenceCount: medCount,
      lowConfidenceCount: lowCount,
      diagnostics: diagnostics,
    );
  }

  /// Generates the final publication-ready Santali PDF document embedding Noto Sans Ol Chiki.
  /// Supports both Mode A (Facsimile for both digital vector and scanned pages) and Mode B (Reflow Reader).
  static Future<Uint8List> generateSantaliPdf({
    required LayoutDocument document,
    PageRenderingMode defaultMode = PageRenderingMode.facsimile,
    String schoolTitle = 'ᱟᱱᱩᱵᱟᱫᱽ ᱮ.ᱟᱭᱤ. - ᱥᱟᱱᱛᱟᱲᱤ ᱥᱮᱪᱮᱫ ᱥᱴᱩᱰᱤᱭᱳ',
  }) async {
    final pdf = pw.Document();

    // 1. Load TrueType Fonts
    ByteData olChikiBytes;
    try {
      olChikiBytes = await rootBundle.load('assets/fonts/NotoSansOlChiki-Regular.ttf');
    } catch (_) {
      final file = File('assets/fonts/NotoSansOlChiki-Regular.ttf');
      final bytes = await file.readAsBytes();
      olChikiBytes = ByteData.view(bytes.buffer);
    }
    final olChikiFont = pw.Font.ttf(olChikiBytes);

    pw.Font? devanagariFont;
    try {
      final devaBytes = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
      devanagariFont = pw.Font.ttf(devaBytes);
    } catch (_) {
      try {
        final file = File('assets/fonts/NotoSansDevanagari-Regular.ttf');
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          devanagariFont = pw.Font.ttf(ByteData.view(bytes.buffer));
        }
      } catch (_) {}
    }

    final helvetica = pw.Font.helvetica();

    final fallbacks = <pw.Font>[
      olChikiFont,
      ?devanagariFont,
      helvetica,
    ];

    // 2. Render each page
    for (final page in document.pages) {
      final hasRasterBg = (page.backgroundImagePath != null &&
          File(page.backgroundImagePath!).existsSync());
      final isFacsimileMode = (defaultMode == PageRenderingMode.facsimile);

      if (isFacsimileMode && hasRasterBg) {
        // --- MODE A1: FACSIMILE PRESERVATION (SCANNED / RASTERIZED BACKGROUND) ---
        final rawBytes = await File(page.backgroundImagePath!).readAsBytes();
        final maskedResult = maskPageImageBackgroundDetailed(
          imageBytes: rawBytes,
          regions: page.regions,
          pageWidthPt: page.width,
          pageHeightPt: page.height,
        );

        final bgImage = pw.MemoryImage(maskedResult.imageBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height),
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.Stack(
                children: [
                  // Full-page background image with inpainted text regions
                  pw.Positioned.fill(
                    child: pw.Image(bgImage, fit: pw.BoxFit.fill),
                  ),

                  // Positioned selectable Santali Ol Chiki text overlays
                  ...page.regions
                      .where((region) => region.type != RegionType.image && region.originalText.trim().isNotEmpty)
                      .map((region) {
                    final text = region.translatedText.isNotEmpty
                        ? region.translatedText
                        : region.originalText;

                    final box = region.boundingBox;
                    final fontSize = region.fontSpec.fontSize > 0
                        ? region.fontSpec.fontSize
                        : 11.0;

                    return pw.Positioned(
                      left: box.x,
                      top: box.y,
                      child: pw.SizedBox(
                        width: box.width,
                        height: box.height,
                        child: pw.Container(
                          alignment: region.alignment == TextAlignment.center
                              ? pw.Alignment.center
                              : region.alignment == TextAlignment.right
                                  ? pw.Alignment.centerRight
                                  : pw.Alignment.topLeft,
                          child: pw.Text(
                            text,
                            style: pw.TextStyle(
                              font: olChikiFont,
                              fontFallback: fallbacks,
                              fontSize: fontSize,
                              fontWeight: region.fontSpec.isBold
                                  ? pw.FontWeight.bold
                                  : pw.FontWeight.normal,
                              color: PdfColors.black,
                              lineSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        );
      } else if (isFacsimileMode && !hasRasterBg) {
        // --- MODE A2: DIGITAL VECTOR FACSIMILE (NATIVE VECTOR GRAPHICS & SPATIAL POSITIONS) ---
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height),
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.Stack(
                children: [
                  // Crisp white vector background
                  pw.Positioned.fill(
                    child: pw.Container(color: PdfColors.white),
                  ),

                  // Vector Table Cell Outlines & Shading
                  ...page.regions
                      .where((r) => r.isTable || r.type == RegionType.tableCell)
                      .map((tr) {
                    final isHead = tr.type == RegionType.heading ||
                        tr.customMetadata['isHeaderCell'] == true;
                    return pw.Positioned(
                      left: tr.boundingBox.x,
                      top: tr.boundingBox.y,
                      child: pw.Container(
                        width: tr.boundingBox.width,
                        height: tr.boundingBox.height,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.teal800, width: 0.8),
                          color: isHead ? PdfColors.teal50 : null,
                        ),
                      ),
                    );
                  }),

                  // Positioned Selectable Santali Text Overlays
                  ...page.regions
                      .where((r) => r.type != RegionType.image && r.originalText.trim().isNotEmpty)
                      .map((region) {
                    final text = region.translatedText.isNotEmpty
                        ? region.translatedText
                        : region.originalText;

                    final box = region.boundingBox;
                    final fontSize = region.fontSpec.fontSize > 0
                        ? region.fontSpec.fontSize
                        : 11.0;

                    return pw.Positioned(
                      left: box.x,
                      top: box.y,
                      child: pw.SizedBox(
                        width: box.width,
                        height: box.height,
                        child: pw.Container(
                          alignment: region.alignment == TextAlignment.center
                              ? pw.Alignment.center
                              : region.alignment == TextAlignment.right
                                  ? pw.Alignment.centerRight
                                  : pw.Alignment.topLeft,
                          child: pw.Text(
                            text,
                            style: pw.TextStyle(
                              font: olChikiFont,
                              fontFallback: fallbacks,
                              fontSize: fontSize,
                              fontWeight: region.fontSpec.isBold
                                  ? pw.FontWeight.bold
                                  : pw.FontWeight.normal,
                              color: region.type == RegionType.heading
                                  ? PdfColors.teal900
                                  : PdfColors.black,
                              lineSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        );
      } else {
        // --- MODE B: STRUCTURAL REFLOW READER ---
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height),
            margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Container(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.teal800, width: 1.5),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          schoolTitle,
                          style: pw.TextStyle(
                            font: olChikiFont,
                            fontFallback: fallbacks,
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal900,
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.teal50,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            'ᱥᱟᱱᱛᱟᱲᱤ (Ol Chiki)',
                            style: pw.TextStyle(
                              font: olChikiFont,
                              fontFallback: fallbacks,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 14),

                  // Document Content Reflow
                  ...page.regions.map((region) {
                    final text = region.translatedText.isNotEmpty
                        ? region.translatedText
                        : region.originalText;

                    if (region.type == RegionType.heading) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
                        child: pw.Text(
                          text,
                          style: pw.TextStyle(
                            font: olChikiFont,
                            fontFallback: fallbacks,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal900,
                          ),
                        ),
                      );
                    } else if (region.type == RegionType.table) {
                      // Render as formatted table
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8),
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            text,
                            style: pw.TextStyle(
                              font: olChikiFont,
                              fontFallback: fallbacks,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      );
                    } else if (region.type == RegionType.image) {
                      return pw.SizedBox();
                    } else {
                      // Paragraph / text block
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 8),
                        child: pw.Text(
                          text,
                          textAlign: region.alignment == TextAlignment.center
                              ? pw.TextAlign.center
                              : region.alignment == TextAlignment.right
                                  ? pw.TextAlign.right
                                  : pw.TextAlign.left,
                          style: pw.TextStyle(
                            font: olChikiFont,
                            fontFallback: fallbacks,
                            fontSize: 11,
                            lineSpacing: 1.4,
                            color: PdfColors.grey900,
                          ),
                        ),
                      );
                    }
                  }),

                  pw.Spacer(),

                  // Footer
                  pw.Container(
                    padding: const pw.EdgeInsets.only(top: 8),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'AnuvaadAI 2.0 - Offline Education',
                          style: pw.TextStyle(
                            font: olChikiFont,
                            fontFallback: fallbacks,
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.Text(
                          'Page ${page.pageNumber}',
                          style: pw.TextStyle(
                            font: olChikiFont,
                            fontFallback: fallbacks,
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }
    }

    return pdf.save();
  }
}

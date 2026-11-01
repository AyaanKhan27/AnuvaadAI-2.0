import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../data/layout_document.dart';

/// Service bridging Flutter to native Android PDF extraction and OCR.
class PdfExtractorService {
  static const MethodChannel _channel = MethodChannel('anuvaad/pdf_layout');

  /// Analyzes a PDF file to determine page count, dimensions, and digital/scanned classification per page.
  static Future<LayoutDocument> analyzeDocument(File pdfFile) async {
    if (!await pdfFile.exists()) {
      throw Exception('PDF file does not exist: ${pdfFile.path}');
    }

    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'analyzeDocument',
        {'filePath': pdfFile.path},
      );

      if (res == null) {
        throw Exception('Native PDF analysis returned null.');
      }

      final pageCount = res['pageCount'] as int? ?? 1;
      final docTypeStr = res['documentType'] as String? ?? 'scanned';
      final rawPages = res['pages'] as List<dynamic>? ?? [];

      final pages = <LayoutPage>[];
      for (final p in rawPages) {
        if (p is Map) {
          final pageNum = p['pageNumber'] as int? ?? (pages.length + 1);
          final width = (p['width'] as num?)?.toDouble() ?? 595.28;
          final height = (p['height'] as num?)?.toDouble() ?? 841.89;
          final rot = p['rotation'] as int? ?? 0;
          final pageTypeStr = p['pageType'] as String? ?? 'scanned';

          pages.add(
            LayoutPage(
              pageNumber: pageNum,
              width: width,
              height: height,
              rotation: rot,
              pageType: PageType.fromString(pageTypeStr),
              regions: [],
              status: PageConversionStatus.pending,
            ),
          );
        }
      }

      final fileName = pdfFile.path.split(RegExp(r'[/\\]')).last;
      return LayoutDocument(
        documentId: 'doc_${DateTime.now().millisecondsSinceEpoch}',
        sourceFileName: fileName,
        pageCount: pageCount,
        documentType: DocumentType.fromString(docTypeStr),
        conversionStatus: ConversionStatus.classified,
        pages: pages,
        sourceFilePath: pdfFile.path,
      );
    } on PlatformException catch (e) {
      // Fallback for non-Android or if native channel is unavailable: create single default page
      final fileName = pdfFile.path.split(RegExp(r'[/\\]')).last;
      return LayoutDocument(
        documentId: 'doc_fallback_${DateTime.now().millisecondsSinceEpoch}',
        sourceFileName: fileName,
        pageCount: 1,
        documentType: DocumentType.scanned,
        conversionStatus: ConversionStatus.classified,
        pages: [
          LayoutPage(
            pageNumber: 1,
            width: 595.28,
            height: 841.89,
            pageType: PageType.scanned,
            regions: [],
          ),
        ],
        sourceFilePath: pdfFile.path,
        metadata: {'platform_error': e.message},
      );
    }
  }

  /// Extracts text and spatial coordinates from a digital PDF page using PDFBox-Android.
  static Future<LayoutPage> extractDigitalPage({
    required File pdfFile,
    required int pageNumber,
    double fallbackWidth = 595.28,
    double fallbackHeight = 841.89,
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'extractPageText',
        {
          'filePath': pdfFile.path,
          'pageNumber': pageNumber,
        },
      );

      if (res != null) {
        final width = (res['width'] as num?)?.toDouble() ?? fallbackWidth;
        final height = (res['height'] as num?)?.toDouble() ?? fallbackHeight;
        final rot = res['rotation'] as int? ?? 0;
        final rawRegions = res['regions'] as List<dynamic>? ?? [];

        final regions = <LayoutRegion>[];
        for (var i = 0; i < rawRegions.length; i++) {
          final r = rawRegions[i];
          if (r is Map) {
            regions.add(
              LayoutRegion.fromJson(Map<String, dynamic>.from(r)),
            );
          }
        }

        return LayoutPage(
          pageNumber: pageNumber,
          width: width,
          height: height,
          rotation: rot,
          pageType: PageType.digital,
          regions: regions,
          status: PageConversionStatus.extracted,
        );
      }
    } catch (_) {
      // Fall through to fallback
    }

    return LayoutPage(
      pageNumber: pageNumber,
      width: fallbackWidth,
      height: fallbackHeight,
      pageType: PageType.digital,
      regions: [],
      status: PageConversionStatus.failed,
    );
  }

  /// Rasterizes a page to a PNG bitmap file using native PdfRenderer.
  static Future<Map<String, dynamic>> renderPageToImage({
    required File pdfFile,
    required int pageNumber,
    int dpi = 180,
  }) async {
    final res = await _channel.invokeMapMethod<String, dynamic>(
      'renderPageToImage',
      {
        'filePath': pdfFile.path,
        'pageNumber': pageNumber,
        'dpi': dpi,
      },
    );

    if (res == null) {
      throw Exception('Failed to rasterize page $pageNumber');
    }
    return res;
  }

  /// Performs ML Kit OCR on a page image and converts bounding boxes from pixel coordinates to PDF point coordinates.
  static Future<LayoutPage> extractScannedPageWithOcr({
    required File imageFile,
    required int pageNumber,
    required double pageWidthPt,
    required double pageHeightPt,
    String script = 'hin_Deva',
  }) async {
    final recogScript = (script == 'hin_Deva')
        ? TextRecognitionScript.devanagiri
        : TextRecognitionScript.latin;

    final textRecognizer = TextRecognizer(script: recogScript);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      final regions = <LayoutRegion>[];
      var regionIndex = 0;

      // Estimate image pixel dimensions or use fallback
      // In ML Kit, boundingBox is in pixel coordinates of imageFile
      // We compute scale factors from image pixels to PDF points (72 pt/inch)
      double maxPixelX = 1.0;
      double maxPixelY = 1.0;
      for (final b in recognizedText.blocks) {
        if (b.boundingBox.right > maxPixelX) maxPixelX = b.boundingBox.right;
        if (b.boundingBox.bottom > maxPixelY) maxPixelY = b.boundingBox.bottom;
      }
      final scaleX = (maxPixelX > 100) ? (pageWidthPt / maxPixelX) : 1.0;
      final scaleY = (maxPixelY > 100) ? (pageHeightPt / maxPixelY) : 1.0;

      for (final block in recognizedText.blocks) {
        final text = block.text.trim();
        if (text.isEmpty) continue;

        final pxRect = block.boundingBox;
        final ptBox = BoundingBox(
          x: (pxRect.left * scaleX).clamp(0.0, pageWidthPt - 10.0),
          y: (pxRect.top * scaleY).clamp(0.0, pageHeightPt - 10.0),
          width: (pxRect.width * scaleX).clamp(10.0, pageWidthPt),
          height: (pxRect.height * scaleY).clamp(8.0, pageHeightPt),
        );

        final lines = block.lines;
        final isHeading = (lines.length == 1 && text.length < 60 && ptBox.height > 18);
        final isList = text.contains(RegExp(r'^[0-9]+[\.\)]|^\*|^\-|^•|^[०-९]+[\.\)]'));

        final type = isHeading
            ? RegionType.heading
            : isList
                ? RegionType.list
                : RegionType.paragraph;

        final estimatedFontSize = (lines.isNotEmpty)
            ? (ptBox.height / lines.length).clamp(8.0, 28.0)
            : 11.0;

        // Extract line and element children for high-precision masking and fitting
        final childRegions = <LayoutRegion>[];
        var lineIdx = 0;
        for (final line in lines) {
          final linePtBox = BoundingBox(
            x: (line.boundingBox.left * scaleX).clamp(0.0, pageWidthPt),
            y: (line.boundingBox.top * scaleY).clamp(0.0, pageHeightPt),
            width: (line.boundingBox.width * scaleX).clamp(5.0, pageWidthPt),
            height: (line.boundingBox.height * scaleY).clamp(6.0, pageHeightPt),
          );

          childRegions.add(
            LayoutRegion(
              regionId: 'ocr_p${pageNumber}_r${regionIndex}_l$lineIdx',
              type: RegionType.paragraph,
              originalText: line.text.trim(),
              boundingBox: linePtBox,
              fontSpec: FontSpec(fontSize: estimatedFontSize),
              readingOrder: lineIdx++,
              ocrConfidence: 0.95,
            ),
          );
        }

        regions.add(
          LayoutRegion(
            regionId: 'ocr_p${pageNumber}_r$regionIndex',
            type: type,
            originalText: text,
            boundingBox: ptBox,
            fontSpec: FontSpec(
              fontSize: estimatedFontSize,
              isBold: isHeading,
            ),
            readingOrder: regionIndex++,
            ocrConfidence: 0.95,
            children: childRegions,
            translationStatus: RegionTranslationStatus.untranslated,
            renderingStatus: RenderingStatus.original,
          ),
        );
      }

      return LayoutPage(
        pageNumber: pageNumber,
        width: pageWidthPt,
        height: pageHeightPt,
        pageType: PageType.scanned,
        backgroundImagePath: imageFile.path,
        regions: regions,
        status: PageConversionStatus.extracted,
      );
    } finally {
      await textRecognizer.close();
    }
  }

  /// Unifies digital and scanned extraction: analyzes the page, extracts vector text if digital,
  /// or renders bitmap + runs ML Kit OCR if scanned or if digital extraction found no selectable text.
  static Future<LayoutPage> extractPageUnified({
    required File pdfFile,
    required int pageNumber,
    required PageType classifiedType,
    double pageWidthPt = 595.28,
    double pageHeightPt = 841.89,
    String script = 'hin_Deva',
  }) async {
    if (classifiedType == PageType.digital) {
      final digitalPage = await extractDigitalPage(
        pdfFile: pdfFile,
        pageNumber: pageNumber,
        fallbackWidth: pageWidthPt,
        fallbackHeight: pageHeightPt,
      );

      // If digital extraction succeeded and returned meaningful text regions, use it!
      if (digitalPage.regions.isNotEmpty &&
          digitalPage.regions.any((r) => r.originalText.trim().length >= 10)) {
        return digitalPage;
      }
    }

    // Otherwise, or if classified as scanned/mixed: render page to image and run OCR
    try {
      final renderResult = await renderPageToImage(
        pdfFile: pdfFile,
        pageNumber: pageNumber,
        dpi: 180,
      );

      final imagePath = renderResult['imagePath'] as String?;
      if (imagePath != null) {
        final imageFile = File(imagePath);
        final width = (renderResult['width'] as num?)?.toDouble() ?? pageWidthPt;
        final height = (renderResult['height'] as num?)?.toDouble() ?? pageHeightPt;

        final scannedPage = await extractScannedPageWithOcr(
          imageFile: imageFile,
          pageNumber: pageNumber,
          pageWidthPt: width,
          pageHeightPt: height,
          script: script,
        );
        return scannedPage;
      }
    } catch (_) {
      // If rendering failed, return a blank fallback page
    }

    return LayoutPage(
      pageNumber: pageNumber,
      width: pageWidthPt,
      height: pageHeightPt,
      pageType: PageType.scanned,
      regions: [],
      status: PageConversionStatus.failed,
    );
  }
}

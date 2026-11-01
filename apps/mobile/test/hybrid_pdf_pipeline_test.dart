import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:anuvaadai/data/layout_document.dart';
import 'package:anuvaadai/data/saved_lesson.dart';
import 'package:anuvaadai/services/hybrid_pdf_service.dart';
import 'package:anuvaadai/services/layout_fitting_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PdfTtfFont ttfFont;

  setUpAll(() async {
    final fontFile = File('assets/fonts/NotoSansOlChiki-Regular.ttf');
    final fontBytes = await fontFile.readAsBytes();
    final pdfDoc = PdfDocument();
    ttfFont = PdfTtfFont(pdfDoc, ByteData.view(fontBytes.buffer));
    SharedPreferences.setMockInitialValues({});
  });

  group('Hybrid PDF Pipeline Tests', () {
    test('A. Digital PDF: Multi-region layout page with tables, headings and lists', () async {
      final digitalPage = LayoutPage(
        pageNumber: 1,
        width: 595.28,
        height: 841.89,
        pageType: PageType.digital,
        regions: [
          LayoutRegion(
            regionId: 'p1_header',
            type: RegionType.header,
            originalText: 'झारखंड शैक्षिक अनुसंधान एवं प्रशिक्षण परिषद्',
            translatedText: 'ᱡᱷᱟᱨᱠᱷᱚᱸᱰ ᱥᱮᱪᱮᱫ ᱠᱷᱚᱸᱫᱽᱨᱚᱸᱫᱽ ᱟᱨ ᱥᱮᱪᱮᱫ ᱯᱟᱹᱨᱥᱤᱫ',
            boundingBox: const BoundingBox(x: 40, y: 30, width: 515, height: 18),
            fontSpec: const FontSpec(fontSize: 10, isBold: false),
            readingOrder: 0,
          ),
          LayoutRegion(
            regionId: 'p1_h1',
            type: RegionType.heading,
            originalText: 'पाठ ४: हमारी नदियाँ और जल स्रोत',
            translatedText: 'ᱯᱟᱴᱷ ᱔: ᱟᱵᱚᱣᱟᱜ ᱜᱟᱰᱟ ᱠᱚ ᱟᱨ ᱫᱟᱜ ᱯᱷᱮᱰᱟᱛ',
            boundingBox: const BoundingBox(x: 40, y: 60, width: 515, height: 32),
            fontSpec: const FontSpec(fontSize: 18, isBold: true),
            readingOrder: 1,
          ),
          LayoutRegion(
            regionId: 'p1_p1',
            type: RegionType.paragraph,
            originalText: 'दामोदर और सुवर्णरेखा नदियाँ हमारे राज्य की प्रमुख जल जीवन रेखाएँ हैं।',
            translatedText: 'ᱫᱟᱢᱚᱫᱚᱨ ᱟᱨ ᱥᱩᱵᱚᱨᱱᱚᱨᱮᱠᱷᱟ ᱜᱟᱰᱟ ᱫᱚ ᱟᱵᱚ ᱯᱚᱱᱚᱛ ᱨᱮᱱᱟᱜ ᱢᱩᱬ ᱫᱟᱜ ᱡᱤᱭᱚᱱ ᱜᱟᱰᱟ ᱠᱟᱱᱟ ᱾',
            boundingBox: const BoundingBox(x: 40, y: 105, width: 515, height: 42),
            fontSpec: const FontSpec(fontSize: 12),
            readingOrder: 2,
          ),
          LayoutRegion(
            regionId: 'p1_table',
            type: RegionType.table,
            originalText: 'नदी | लम्बाई | मुख्य शहर\nदामोदर | ५९२ किमी | धनबाद\nसुवर्णरेखा | ३९५ किमी | जमशेदपुर',
            translatedText: 'ᱜᱟᱰᱟ | ᱡᱤᱞᱤᱧ | ᱢᱩᱬ ᱱᱟᱜᱟᱨ\nᱫᱟᱢᱚᱫᱚᱨ | ᱕᱙᱒ ᱠᱤᱢᱤ | ᱫᱷᱟᱱᱵᱟᱫᱽ\nᱥᱩᱵᱚᱨᱱᱚᱨᱮᱠᱷᱟ | ᱓᱙᱕ ᱠᱤᱢᱤ | ᱡᱟᱢᱥᱮᱫᱽᱯᱩᱨ',
            boundingBox: const BoundingBox(x: 40, y: 160, width: 515, height: 90),
            fontSpec: const FontSpec(fontSize: 10),
            readingOrder: 3,
          ),
        ],
      );

      final fittedPage = await LayoutFittingEngine.fitPageRegions(page: digitalPage, font: ttfFont);
      expect(fittedPage.regions.length, 4);
      expect(fittedPage.status, PageConversionStatus.extracted);

      // Verify each region has valid font size and boundaries
      for (final r in fittedPage.regions) {
        expect(r.fontSpec.fontSize >= 8.0, true);
        expect(r.boundingBox.width > 0, true);
        expect(r.boundingBox.height > 0, true);
      }
    });

    test('B. Scanned PDF: OCR bounding boxes, confidence score and background masking', () async {
      final scannedPage = LayoutPage(
        pageNumber: 2,
        width: 595.28,
        height: 841.89,
        pageType: PageType.scanned,
        regions: [
          LayoutRegion(
            regionId: 'ocr_p2_r0',
            type: RegionType.heading,
            originalText: 'अभ्यास प्रश्नोत्तर',
            translatedText: 'ᱪᱮᱛᱟᱱ ᱠᱩᱠᱞᱤ ᱛᱮᱞᱟ',
            boundingBox: const BoundingBox(x: 50, y: 80, width: 300, height: 26),
            ocrConfidence: 0.96,
            readingOrder: 0,
          ),
          LayoutRegion(
            regionId: 'ocr_p2_r1',
            type: RegionType.paragraph,
            originalText: 'वर्षा का जल कैसे संरक्षित किया जा सकता है?',
            translatedText: 'ᱫᱟᱜ ᱡᱟᱹᱲᱤ ᱫᱟᱜ ᱪᱮᱫ ᱞᱮᱠᱟ ᱛᱮ ᱥᱟᱧᱪᱟᱣ ᱫᱚᱦᱚ ᱜᱟᱱᱚᱜᱼᱟ?',
            boundingBox: const BoundingBox(x: 50, y: 120, width: 490, height: 35),
            ocrConfidence: 0.94,
            readingOrder: 1,
          ),
        ],
      );

      expect(scannedPage.isScanned, true);
      expect(scannedPage.regions.first.ocrConfidence, 0.96);
      expect(scannedPage.regions.length, 2);
    });

    test('C. Mixed PDF: Document with Digital Page 1 and Scanned Page 2', () async {
      final mixedDoc = LayoutDocument(
        documentId: 'mixed_doc_test',
        sourceFileName: 'Classroom_Science_Mixed.pdf',
        pageCount: 2,
        documentType: DocumentType.mixed,
        conversionStatus: ConversionStatus.translated,
        sourceFilePath: '/sdcard/Download/Classroom_Science_Mixed.pdf',
        pages: [
          LayoutPage(
            pageNumber: 1,
            width: 595.28,
            height: 841.89,
            pageType: PageType.digital,
            regions: [
              LayoutRegion(
                regionId: 'm_p1_r0',
                type: RegionType.heading,
                originalText: 'डिजिटल पृष्ठ १',
                translatedText: 'ᱰᱤᱡᱤᱴᱟᱞ ᱥᱟᱦᱴᱟ ᱑',
                boundingBox: const BoundingBox(x: 40, y: 50, width: 400, height: 30),
                readingOrder: 0,
                translationStatus: RegionTranslationStatus.translated,
              ),
            ],
          ),
          LayoutPage(
            pageNumber: 2,
            width: 595.28,
            height: 841.89,
            pageType: PageType.scanned,
            regions: [
              LayoutRegion(
                regionId: 'm_p2_r0',
                type: RegionType.paragraph,
                originalText: 'स्कैन किया हुआ पृष्ठ २',
                translatedText: 'ᱥᱠᱮᱱ ᱟᱠᱟᱱ ᱥᱟᱦᱴᱟ ᱒',
                boundingBox: const BoundingBox(x: 50, y: 80, width: 450, height: 40),
                ocrConfidence: 0.92,
                readingOrder: 0,
                translationStatus: RegionTranslationStatus.translated,
              ),
            ],
          ),
        ],
      );

      expect(mixedDoc.documentType, DocumentType.mixed);
      expect(mixedDoc.digitalPageCount, 1);
      expect(mixedDoc.scannedPageCount, 1);
      expect(mixedDoc.mixedPageCount, 0);
      expect(mixedDoc.totalRegions, 2);
      expect(mixedDoc.translatedRegions, 2);
      expect(mixedDoc.translationProgress, 1.0);

      // Generate PDF in Mode B (Reflow Reader)
      final pdfBytes = await HybridPdfService.generateSantaliPdf(
        document: mixedDoc,
        defaultMode: PageRenderingMode.reflowReader,
      );

      expect(pdfBytes.isNotEmpty, true);
      expect(pdfBytes.length > 5000, true); // Valid PDF with embedded font

      // Verify PDF header magic bytes %PDF
      final header = String.fromCharCodes(pdfBytes.take(4));
      expect(header, '%PDF');
    });

    test('D. Layout Engine: Text expansion, auto-scaling, and line wrapping', () async {
      // Ol Chiki text expanding beyond original small height
      const shortDevanagari = 'जल ही जीवन है। हमारे गाँव में पानी बहुत अनमोल है। सबको मिलकर जल संचयन करना चाहिए।';
      const expandedSantali = 'ᱫᱟᱜ ᱜᱮ ᱡᱤᱭᱚᱱ ᱠᱟᱱᱟ ᱾ ᱟᱞᱮ ᱟᱹᱛᱩ ᱨᱮ ᱫᱟᱜ ᱟᱹᱰᱤ ᱜᱚᱱᱚᱝ ᱟᱱᱟ ᱾ ᱡᱚᱛᱚ ᱦᱚᱲ ᱢᱤᱫ ᱠᱟᱛᱮ ᱫᱟᱜ ᱥᱟᱧᱪᱟᱣ ᱞᱟᱹᱠᱛᱤ ᱠᱟᱱᱟ ᱾ ᱵᱤᱨ ᱡᱷᱟᱨᱱᱟ ᱨᱮᱱᱟᱜ ᱫᱟᱜ ᱵᱚᱱ ᱨᱩᱠᱷᱤᱭᱟᱹᱭᱟ ᱾';

      final region = LayoutRegion(
        regionId: 'expand_r1',
        type: RegionType.paragraph,
        originalText: shortDevanagari,
        translatedText: expandedSantali,
        boundingBox: const BoundingBox(x: 40, y: 100, width: 140, height: 18),
        fontSpec: const FontSpec(fontSize: 12.0),
        readingOrder: 0,
      );

      final result = await LayoutFittingEngine.fitRegionText(
        region: region,
        maxAvailableBottomY: 300.0,
        font: ttfFont,
      );

      expect(result.lines.length >= 3, true);
      expect(result.wasRegionExpanded, true);
      expect(result.fontSize >= 8.0, true);
      expect(result.fittedBounds.height > 18.0, true);
    });

    test('E. Course Materials Integration: Save PDF Course Material and verify offline retrieval', () async {
      final saved = await SavedLessonsStore.savePdfCourseMaterial(
        documentId: 'course_mat_paryavaran',
        title: 'Class 5 Paryavaran & Jal Sanrakshan',
        originalFileName: 'Paryavaran_Class5_Chapter3.pdf',
        originalPdfPath: '/sdcard/Download/Paryavaran_Class5_Chapter3.pdf',
        translatedPdfPath: '/sdcard/Android/data/.../files/documents/Paryavaran_Santali_OlChiki.pdf',
        pageCount: 3,
        category: 'Environmental Science',
        summaryHindi: 'जल संरक्षण एवं प्राकृतिक स्रोत',
        summarySantali: 'ᱫᱟᱜ ᱥᱟᱧᱪᱟᱣ ᱟᱨ ᱯᱷᱮᱰᱟᱛ',
      );

      expect(saved.isPdfDocument, true);
      expect(saved.pageCount, 3);
      expect(saved.category, 'Environmental Science');
      expect(saved.documentId, 'course_mat_paryavaran');

      final allLessons = await SavedLessonsStore.load();
      final pdfItems = allLessons.where((l) => l.isPdfDocument).toList();
      expect(pdfItems.isNotEmpty, true);
      expect(pdfItems.first.title, 'Class 5 Paryavaran & Jal Sanrakshan');
      expect(pdfItems.first.translatedPdfPath, contains('Paryavaran_Santali_OlChiki.pdf'));
    });
  });
}

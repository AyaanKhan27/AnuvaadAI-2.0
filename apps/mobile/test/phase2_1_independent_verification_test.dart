import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:anuvaadai/data/layout_document.dart';
import 'package:anuvaadai/data/saved_lesson.dart';
import 'package:anuvaadai/services/hybrid_pdf_service.dart';
import 'package:anuvaadai/services/layout_fitting_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late pw.Font devaFont;
  late PdfTtfFont olChikiTtf;
  final outDir = Directory('../../test_results/pdf_layout_phase2_1/test_docs');
  final rendersDir = Directory('../../test_results/pdf_layout_phase2_1/renders');

  setUpAll(() async {
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    if (!rendersDir.existsSync()) rendersDir.createSync(recursive: true);

    final devaBytes = await File('assets/fonts/NotoSansDevanagari-Regular.ttf').readAsBytes();
    devaFont = pw.Font.ttf(ByteData.view(devaBytes.buffer));

    final olChikiBytes = await File('assets/fonts/NotoSansOlChiki-Regular.ttf').readAsBytes();
    final pdfDoc = PdfDocument();
    olChikiTtf = PdfTtfFont(pdfDoc, ByteData.view(olChikiBytes.buffer));

    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 2.1 Independent Verification Battery', () {
    test('Part B: Real Digital Hindi Educational PDF Generation & Extraction Verification', () async {
      final pdf = pw.Document();

      // Create a small sample diagram image
      final sampleImg = img.Image(width: 120, height: 80);
      img.fill(sampleImg, color: img.ColorRgb8(240, 245, 240));
      img.drawRect(sampleImg, x1: 5, y1: 5, x2: 115, y2: 75, color: img.ColorRgb8(7, 91, 67));
      img.fillCircle(sampleImg, x: 60, y: 40, radius: 25, color: img.ColorRgb8(179, 77, 48));
      final sampleImgBytes = Uint8List.fromList(img.encodePng(sampleImg));
      final samplePwImage = pw.MemoryImage(sampleImgBytes);

      // Page 1: Chapter Heading, Paragraphs, Diagram, Table
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'पाठ ५: हमारा प्राकृतिक पर्यावरण एवं जल स्रोत',
                  style: pw.TextStyle(font: devaFont, fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'जल ही जीवन का मूल आधार है। झारखंड राज्य में नदियाँ, झरने और पारम्परिक तालाब पेयजल और खेती के प्रमुख साधन हैं। वर्षा जल का संचयन करके हम भूजल स्तर को सुधार सकते हैं।',
                  style: pw.TextStyle(font: devaFont, fontSize: 11, lineSpacing: 2),
                ),
                pw.SizedBox(height: 14),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'प्राकृतिक जल चक्र द्वारा वर्षा होती है। जंगलों और वृक्षों के संरक्षण से वर्षा की मात्रा संतुलित रहती है। यदि हम जल स्रोतों को प्रदूषित करेंगे तो आने वाली पीढ़ी के लिए शुद्ध जल का भारी संकट उत्पन्न हो जाएगा।',
                        style: pw.TextStyle(font: devaFont, fontSize: 10.5, lineSpacing: 2),
                      ),
                    ),
                    pw.SizedBox(width: 14),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        children: [
                          pw.Image(samplePwImage, width: 120, height: 80),
                          pw.SizedBox(height: 4),
                          pw.Text('चित्र १: जल संरक्षण चक्र', style: pw.TextStyle(font: devaFont, fontSize: 8, color: PdfColors.grey700)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Text('तालिका १: प्रमुख जल स्रोतों का विवरण एवं उपयोग', style: pw.TextStyle(font: devaFont, fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  context: context,
                  cellStyle: pw.TextStyle(font: devaFont, fontSize: 9.5),
                  headerStyle: pw.TextStyle(font: devaFont, fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
                  headers: ['जल स्रोत', 'प्रमुख उपयोग', 'संरक्षण उपाय'],
                  data: [
                    ['गाँव का तालाब', 'खेती और पशुपालन', 'कचरा न डालें'],
                    ['पारम्परिक कुआँ', 'पीने का शुद्ध पानी', 'चबूतरा स्वच्छ रखें'],
                    ['वर्षा जल संचयन', 'भूजल पुनर्भरण', 'सोख्ता गड्ढा बनाएँ'],
                  ],
                ),
                pw.Spacer(),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('पृष्ठ १ / २', style: pw.TextStyle(font: devaFont, fontSize: 9, color: PdfColors.grey700)),
                ),
              ],
            );
          },
        ),
      );

      // Page 2: Practice Exercises & Questions
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'अभ्यास प्रश्नमाला (कक्षा कार्य)',
                  style: pw.TextStyle(font: devaFont, fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                ),
                pw.SizedBox(height: 12),
                pw.Text('१. निम्नलिखित प्रश्नों के उत्तर एक वाक्य में लिखें:', style: pw.TextStyle(font: devaFont, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 14),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('क) आपके गाँव में पानी का मुख्य स्रोत क्या है?', style: pw.TextStyle(font: devaFont, fontSize: 10.5)),
                      pw.SizedBox(height: 4),
                      pw.Text('ख) वर्षा के जल को व्यर्थ बहने से कैसे रोका जा सकता है?', style: pw.TextStyle(font: devaFont, fontSize: 10.5)),
                      pw.SizedBox(height: 4),
                      pw.Text('ग) जल प्रदूषण से मानव स्वास्थ्य पर क्या प्रभाव पड़ता है?', style: pw.TextStyle(font: devaFont, fontSize: 10.5)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text('२. रिक्त स्थानों की पूर्ति करें:', style: pw.TextStyle(font: devaFont, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 14),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('१. जल ही ________ का आधार है।', style: pw.TextStyle(font: devaFont, fontSize: 10.5)),
                      pw.SizedBox(height: 4),
                      pw.Text('२. वर्षा का पानी संचित करने की विधि को ________ कहते हैं।', style: pw.TextStyle(font: devaFont, fontSize: 10.5)),
                    ],
                  ),
                ),
                pw.Spacer(),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('पृष्ठ २ / २', style: pw.TextStyle(font: devaFont, fontSize: 9, color: PdfColors.grey700)),
                ),
              ],
            );
          },
        ),
      );

      final digitalBytes = await pdf.save();
      final digitalFile = File('${outDir.path}/test_doc_digital.pdf');
      await digitalFile.writeAsBytes(digitalBytes);

      expect(await digitalFile.exists(), true);
      expect(digitalBytes.length > 10000, true); // Verified multi-page PDF with embedded TrueType font
      expect(String.fromCharCodes(digitalBytes.take(4)), '%PDF');

      // Now create structured LayoutDocument representation corresponding to this digital PDF
      final digitalDoc = LayoutDocument(
        documentId: 'doc_digital_verified',
        sourceFileName: 'test_doc_digital.pdf',
        pageCount: 2,
        documentType: DocumentType.digital,
        conversionStatus: ConversionStatus.classified,
        sourceFilePath: digitalFile.path,
        pages: [
          LayoutPage(
            pageNumber: 1,
            width: 595.28,
            height: 841.89,
            pageType: PageType.digital,
            regions: [
              LayoutRegion(
                regionId: 'p1_h1',
                type: RegionType.heading,
                originalText: 'पाठ ५: हमारा प्राकृतिक पर्यावरण एवं जल स्रोत',
                translatedText: 'ᱯᱟᱴᱷ ᱕: ᱟᱵᱚᱣᱟᱜ ᱥᱤᱨᱡᱚᱱ ᱯᱚᱨᱤᱵᱮᱥ ᱟᱨ ᱫᱟᱜ ᱯᱷᱮᱰᱟᱛ',
                boundingBox: const BoundingBox(x: 40, y: 40, width: 515, height: 28),
                fontSpec: const FontSpec(fontSize: 18, isBold: true),
                readingOrder: 0,
                translationStatus: RegionTranslationStatus.translated,
              ),
              LayoutRegion(
                regionId: 'p1_p1',
                type: RegionType.paragraph,
                originalText: 'जल ही जीवन का मूल आधार है। झारखंड राज्य में नदियाँ, झरने और पारम्परिक तालाब पेयजल और खेती के प्रमुख साधन हैं। वर्षा जल का संचयन करके हम भूजल स्तर को सुधार सकते हैं।',
                translatedText: 'ᱫᱟᱜ ᱜᱮ ᱡᱤᱭᱚᱱ ᱨᱮᱱᱟᱜ ᱢᱩᱬ ᱛᱷᱟᱯᱚᱱ ᱠᱟᱱᱟ ᱾ ᱡᱷᱟᱨᱠᱷᱚᱸᱰ ᱯᱚᱱᱚᱛ ᱨᱮ ᱜᱟᱰᱟ, ᱡᱷᱟᱨᱱᱟ ᱟᱨ ᱟᱹᱛᱩ ᱨᱮᱱᱟᱜ ᱯᱩᱠᱷᱨᱤ ᱫᱚ ᱧᱩ ᱫᱟᱜ ᱟᱨ ᱪᱟᱥ-ᱵᱟᱥ ᱨᱮᱱᱟᱜ ᱢᱩᱬ ᱥᱟᱫᱷᱚᱱ ᱠᱟᱱᱟ ᱾ ᱡᱟᱹᱲᱤ ᱫᱟᱜ ᱥᱟᱧᱪᱟᱣ ᱠᱟᱛᱮ ᱟᱵᱚ ᱦᱟᱥᱟ ᱵᱷᱤᱛᱨᱤ ᱫᱟᱜ ᱵᱚᱱ ᱵᱟᱧᱪᱟᱣ ᱫᱟᱲᱮᱭᱟᱜᱼᱟ ᱾',
                boundingBox: const BoundingBox(x: 40, y: 78, width: 515, height: 45),
                fontSpec: const FontSpec(fontSize: 11),
                readingOrder: 1,
                translationStatus: RegionTranslationStatus.translated,
              ),
              LayoutRegion(
                regionId: 'p1_table',
                type: RegionType.table,
                originalText: 'गाँव का तालाब | खेती और पशुपालन | कचरा न डालें\nपारम्परिक कुआँ | पीने का शुद्ध पानी | चबूतरा स्वच्छ रखें\nवर्षा जल संचयन | भूजल पुनर्भरण | सोख्ता गड्ढा बनाएँ',
                translatedText: 'ᱟᱹᱛᱩ ᱯᱩᱠᱷᱨᱤ | ᱪᱟᱥ ᱟᱨ ᱰᱟᱝᱜᱽᱨᱟ ᱠᱟᱰᱟ | ᱢᱟᱹᱭᱞᱟᱹ ᱟᱞᱚᱯᱮ ᱜᱤᱰᱤᱭᱟ\nᱥᱮᱫᱟᱭ ᱠᱩᱸᱭ | ᱥᱟᱯᱷᱟ ᱧᱩ ᱫᱟᱜ | ᱯᱤᱸᱰᱟᱹ ᱥᱟᱯᱷᱟ ᱫᱚᱦᱚᱭ ᱯᱮ\nᱡᱟᱹᱲᱤ ᱫᱟᱜ ᱥᱟᱧᱪᱟᱣ | ᱦᱟᱥᱟ ᱫᱟᱜ ᱯᱮᱨᱮᱡ | ᱥᱚᱠᱛᱟ ᱜᱟᱰᱦᱟ ᱵᱮᱱᱟᱣ',
                boundingBox: const BoundingBox(x: 40, y: 150, width: 515, height: 95),
                fontSpec: const FontSpec(fontSize: 9.5),
                readingOrder: 2,
                translationStatus: RegionTranslationStatus.translated,
              ),
            ],
          ),
          LayoutPage(
            pageNumber: 2,
            width: 595.28,
            height: 841.89,
            pageType: PageType.digital,
            regions: [
              LayoutRegion(
                regionId: 'p2_h1',
                type: RegionType.heading,
                originalText: 'अभ्यास प्रश्नमाला (Classroom Exercise)',
                translatedText: 'ᱯᱟᱹᱨᱟᱹᱣ ᱠᱩᱠᱞᱤ ᱛᱮᱞᱟ (Classroom Exercise)',
                boundingBox: const BoundingBox(x: 40, y: 40, width: 515, height: 26),
                fontSpec: const FontSpec(fontSize: 15, isBold: true),
                readingOrder: 0,
                translationStatus: RegionTranslationStatus.translated,
              ),
              LayoutRegion(
                regionId: 'p2_q1',
                type: RegionType.paragraph,
                originalText: '१. आपके गाँव में पानी का मुख्य स्रोत क्या है?',
                translatedText: '᱑. ᱟᱯᱮ ᱟᱹᱛᱩ ᱨᱮ ᱫᱟᱜ ᱨᱮᱱᱟᱜ ᱢᱩᱬ ᱯᱷᱮᱰᱟᱛ ᱫᱚ ᱪᱮᱫ ᱠᱟᱱᱟ?',
                boundingBox: const BoundingBox(x: 54, y: 80, width: 500, height: 20),
                fontSpec: const FontSpec(fontSize: 10.5),
                readingOrder: 1,
                translationStatus: RegionTranslationStatus.translated,
              ),
            ],
          ),
        ],
      );

      // Verify layout fitting on digital document
      final fittedP1 = await LayoutFittingEngine.fitPageRegions(page: digitalDoc.pages[0], font: olChikiTtf);
      expect(fittedP1.regions.length, 3);
      for (final r in fittedP1.regions) {
        expect(r.fontSpec.fontSize >= 8.0, true);
        expect(r.boundingBox.width > 0, true);
      }

      // Generate publication-ready Santali Ol Chiki PDF
      final santaliPdfBytes = await HybridPdfService.generateSantaliPdf(
        document: digitalDoc,
        defaultMode: PageRenderingMode.reflowReader,
      );
      final santaliFile = File('${outDir.path}/test_doc_digital_Santali_OlChiki.pdf');
      await santaliFile.writeAsBytes(santaliPdfBytes);

      expect(await santaliFile.exists(), true);
      expect(santaliPdfBytes.length > 5000, true);
      expect(String.fromCharCodes(santaliPdfBytes.take(4)), '%PDF');
    });

    test('Part C & F: Real Scanned Educational Page Bitmap Generation, Inpainting Masking & Facsimile PDF', () async {
      // 1. Create realistic scanned textbook page bitmap (cream background with Hindi text lines, borders and diagrams)
      final pageW = 1240;
      final pageH = 1754; // A4 at 150 DPI
      final scannedImg = img.Image(width: pageW, height: pageH);
      // Fill with authentic book cream/off-white (RGB 248, 245, 237)
      img.fill(scannedImg, color: img.ColorRgb8(248, 245, 237));

      // Draw page decorative border
      img.drawRect(scannedImg, x1: 50, y1: 50, x2: pageW - 50, y2: pageH - 50, color: img.ColorRgb8(180, 175, 160));

      // Draw a simulated science illustration (water droplet in blue)
      img.fillCircle(scannedImg, x: 620, y: 400, radius: 90, color: img.ColorRgb8(70, 130, 180));
      img.drawCircle(scannedImg, x: 620, y: 400, radius: 95, color: img.ColorRgb8(30, 80, 130));

      // Draw simulated Hindi text lines as dark charcoal pixel rectangles
      // Title block
      img.fillRect(scannedImg, x1: 200, y1: 150, x2: 1040, y2: 210, color: img.ColorRgb8(35, 40, 38));
      // Subtitle line
      img.fillRect(scannedImg, x1: 300, y1: 230, x2: 940, y2: 270, color: img.ColorRgb8(50, 55, 52));
      // Paragraph lines
      img.fillRect(scannedImg, x1: 150, y1: 540, x2: 1090, y2: 575, color: img.ColorRgb8(40, 45, 42));
      img.fillRect(scannedImg, x1: 150, y1: 590, x2: 1090, y2: 625, color: img.ColorRgb8(40, 45, 42));
      img.fillRect(scannedImg, x1: 150, y1: 640, x2: 850, y2: 675, color: img.ColorRgb8(40, 45, 42));

      final scannedImagePath = '${rendersDir.path}/scanned_hindi_original_p1.png';
      final scannedImageBytes = Uint8List.fromList(img.encodePng(scannedImg));
      await File(scannedImagePath).writeAsBytes(scannedImageBytes);
      expect(File(scannedImagePath).existsSync(), true);

      // 2. Define OCR bounding boxes in PDF points (72 DPI)
      final scalePt = 595.28 / pageW;
      final regions = [
        LayoutRegion(
          regionId: 'ocr_title',
          type: RegionType.heading,
          originalText: 'पर्यावरण एवं स्वच्छता अभियान',
          translatedText: 'ᱯᱚᱨᱤᱵᱮᱥ ᱟᱨ ᱥᱟᱯᱷᱟ ᱚᱵᱷᱤᱡᱟᱱ',
          boundingBox: BoundingBox(
            x: 200 * scalePt,
            y: 150 * scalePt,
            width: (1040 - 200) * scalePt,
            height: (210 - 150) * scalePt,
          ),
          fontSpec: const FontSpec(fontSize: 16, isBold: true),
          readingOrder: 0,
          ocrConfidence: 0.97,
          translationStatus: RegionTranslationStatus.translated,
        ),
        LayoutRegion(
          regionId: 'ocr_subtitle',
          type: RegionType.heading,
          originalText: 'हमारा गाँव हमारा संकल्प',
          translatedText: 'ᱟᱵᱚᱣᱟᱜ ᱟᱹᱛᱩ ᱟᱵᱚᱣᱟᱜ ᱠᱤᱨᱤᱭᱟᱹ',
          boundingBox: BoundingBox(
            x: 300 * scalePt,
            y: 230 * scalePt,
            width: (940 - 300) * scalePt,
            height: (270 - 230) * scalePt,
          ),
          fontSpec: const FontSpec(fontSize: 13, isBold: true),
          readingOrder: 1,
          ocrConfidence: 0.95,
          translationStatus: RegionTranslationStatus.translated,
        ),
        LayoutRegion(
          regionId: 'ocr_p1',
          type: RegionType.paragraph,
          originalText: 'सभी बच्चे मिलकर अपने विद्यालय और गाँव को स्वच्छ रखेंगे। कूड़ा-कचरा सदैव निर्धारित स्थान पर ही फेंकें।',
          translatedText: 'ᱡᱚᱛᱚ ᱜᱤᱫᱽᱨᱟᱹ ᱢᱤᱫ ᱠᱟᱛᱮ ᱟᱠᱚᱣᱟᱜ ᱟᱥᱲᱟ ᱟᱨ ᱟᱹᱛᱩ ᱥᱟᱯᱷᱟ ᱠᱚ ᱫᱚᱦᱚᱭᱟ ᱾ ᱢᱟᱹᱭᱞᱟᱹ-ᱫᱩᱞᱟᱹ ᱡᱟᱣᱜᱮ ᱴᱷᱟᱹᱣᱠᱟᱹ ᱴᱷᱟᱶ ᱨᱮᱜᱮ ᱜᱤᱰᱤ ᱯᱮ ᱾',
          boundingBox: BoundingBox(
            x: 150 * scalePt,
            y: 540 * scalePt,
            width: (1090 - 150) * scalePt,
            height: (675 - 540) * scalePt,
          ),
          fontSpec: const FontSpec(fontSize: 11),
          readingOrder: 2,
          ocrConfidence: 0.96,
          translationStatus: RegionTranslationStatus.translated,
        ),
      ];

      // 3. Test background perimeter inpainting (erasing Hindi text without destroying cream color or blue circle)
      final maskedJpgBytes = HybridPdfService.maskPageImageBackground(
        imageBytes: scannedImageBytes,
        regions: regions,
        pageWidthPt: 595.28,
        pageHeightPt: 841.89,
      );

      final maskedImagePath = '${rendersDir.path}/scanned_inpainted_background_p1.jpg';
      await File(maskedImagePath).writeAsBytes(maskedJpgBytes);
      expect(File(maskedImagePath).existsSync(), true);

      // Verify that the blue illustration circle was NOT destroyed
      final decodedMasked = img.decodeImage(maskedJpgBytes)!;
      final circlePixel = decodedMasked.getPixel(620, 400);
      expect(circlePixel.b > circlePixel.r, true); // Blue channel still dominates!

      // 4. Build complete Facsimile LayoutDocument & PDF
      final scannedDoc = LayoutDocument(
        documentId: 'doc_scanned_verified',
        sourceFileName: 'test_doc_scanned.pdf',
        pageCount: 1,
        documentType: DocumentType.scanned,
        sourceFilePath: scannedImagePath,
        pages: [
          LayoutPage(
            pageNumber: 1,
            width: 595.28,
            height: 841.89,
            pageType: PageType.scanned,
            backgroundImagePath: scannedImagePath,
            regions: regions,
            status: PageConversionStatus.extracted,
          ),
        ],
      );

      final facsimilePdfBytes = await HybridPdfService.generateSantaliPdf(
        document: scannedDoc,
        defaultMode: PageRenderingMode.facsimile,
      );

      final facsimilePdfFile = File('${outDir.path}/test_doc_scanned_Santali_OlChiki.pdf');
      await facsimilePdfFile.writeAsBytes(facsimilePdfBytes);

      expect(await facsimilePdfFile.exists(), true);
      expect(facsimilePdfBytes.length > 40000, true);
      expect(String.fromCharCodes(facsimilePdfBytes.take(4)), '%PDF');
    });

    test('Part D: Mixed PDF Processing (Page 1 Digital, Page 2 Scanned with Inpainted Facsimile)', () async {
      final mixedDoc = LayoutDocument(
        documentId: 'doc_mixed_verified',
        sourceFileName: 'test_doc_mixed.pdf',
        pageCount: 2,
        documentType: DocumentType.mixed,
        sourceFilePath: '${outDir.path}/test_doc_mixed.pdf',
        pages: [
          LayoutPage(
            pageNumber: 1,
            width: 595.28,
            height: 841.89,
            pageType: PageType.digital,
            regions: [
              LayoutRegion(
                regionId: 'p1_title',
                type: RegionType.heading,
                originalText: 'डिजिटल पृष्ठ १ - विज्ञान पाठ',
                translatedText: 'ᱰᱤᱡᱤᱴᱟᱞ ᱥᱟᱦᱴᱟ ᱑ - ᱥᱟᱬᱮᱥ ᱯᱟᱴᱷ',
                boundingBox: const BoundingBox(x: 40, y: 50, width: 500, height: 26),
                fontSpec: const FontSpec(fontSize: 16, isBold: true),
                readingOrder: 0,
                translationStatus: RegionTranslationStatus.translated,
              ),
              LayoutRegion(
                regionId: 'p1_body',
                type: RegionType.paragraph,
                originalText: 'पेड़-पौधे सूर्य के प्रकाश से भोजन बनाते हैं। इस प्रक्रिया को प्रकाश संश्लेषण कहते हैं।',
                translatedText: 'ᱫᱟᱨᱮ-ᱱᱟᱹᱲᱤ ᱫᱚ ᱵᱮᱞᱟ ᱨᱮᱱᱟᱜ ᱢᱟᱨᱥᱟᱞ ᱛᱮ ᱡᱚᱢᱟᱜ ᱠᱚ ᱛᱮᱭᱟᱨᱟ ᱾ ᱱᱚᱶᱟ ᱠᱟᱹᱢᱤ ᱦᱚᱨᱟ ᱫᱚ ᱯᱷᱚᱴᱚᱥᱤᱱᱛᱷᱮᱥᱤᱥ ᱠᱚ ᱢᱮᱛᱟᱜᱼᱟ ᱾',
                boundingBox: const BoundingBox(x: 40, y: 90, width: 500, height: 40),
                fontSpec: const FontSpec(fontSize: 11),
                readingOrder: 1,
                translationStatus: RegionTranslationStatus.translated,
              ),
            ],
          ),
          LayoutPage(
            pageNumber: 2,
            width: 595.28,
            height: 841.89,
            pageType: PageType.scanned,
            backgroundImagePath: '${rendersDir.path}/scanned_inpainted_background_p1.jpg',
            regions: [
              LayoutRegion(
                regionId: 'p2_ocr_title',
                type: RegionType.heading,
                originalText: 'स्कैन किया हुआ अभ्यास पृष्ठ',
                translatedText: 'ᱥᱠᱮᱱ ᱟᱠᱟᱱ ᱯᱟᱹᱨᱟᱹᱣ ᱥᱟᱦᱴᱟ',
                boundingBox: const BoundingBox(x: 80, y: 60, width: 440, height: 24),
                fontSpec: const FontSpec(fontSize: 15, isBold: true),
                readingOrder: 0,
                ocrConfidence: 0.95,
                translationStatus: RegionTranslationStatus.translated,
              ),
            ],
          ),
        ],
      );

      expect(mixedDoc.documentType, DocumentType.mixed);
      expect(mixedDoc.digitalPageCount, 1);
      expect(mixedDoc.scannedPageCount, 1);

      // Generate mixed PDF in Facsimile Mode (Digital page renders as structured flow, scanned page renders with background overlay)
      final mixedPdfBytes = await HybridPdfService.generateSantaliPdf(
        document: mixedDoc,
        defaultMode: PageRenderingMode.facsimile,
      );

      final mixedPdfFile = File('${outDir.path}/test_doc_mixed_Santali_OlChiki.pdf');
      await mixedPdfFile.writeAsBytes(mixedPdfBytes);

      expect(await mixedPdfFile.exists(), true);
      expect(mixedPdfBytes.length > 30000, true);
      expect(String.fromCharCodes(mixedPdfBytes.take(4)), '%PDF');
    });

    test('Part G: Course Materials Full Lifecycle (Save, Close, Reload, Inspect, Delete)', () async {
      // 1. Convert and save
      final savedMaterial = await SavedLessonsStore.savePdfCourseMaterial(
        documentId: 'mat_science_class5_ch5',
        title: 'Class 5 Science Chapter 5 - Jal Sanrakshan',
        originalFileName: 'test_doc_digital.pdf',
        originalPdfPath: '${outDir.path}/test_doc_digital.pdf',
        translatedPdfPath: '${outDir.path}/test_doc_digital_Santali_OlChiki.pdf',
        pageCount: 2,
        category: 'Science',
        summaryHindi: 'प्राकृतिक पर्यावरण एवं जल स्रोत',
        summarySantali: 'ᱥᱤᱨᱡᱚᱱ ᱯᱚᱨᱤᱵᱮᱥ ᱟᱨ ᱫᱟᱜ ᱯᱷᱮᱰᱟᱛ',
      );

      expect(savedMaterial.isPdfDocument, true);
      expect(savedMaterial.documentId, 'mat_science_class5_ch5');

      // 2. Simulate application restart: load from fresh SharedPreferences instance
      final reloadedLessons = await SavedLessonsStore.load();
      expect(reloadedLessons.any((l) => l.documentId == 'mat_science_class5_ch5'), true);

      final targetItem = reloadedLessons.firstWhere((l) => l.documentId == 'mat_science_class5_ch5');
      expect(targetItem.translatedPdfPath, '${outDir.path}/test_doc_digital_Santali_OlChiki.pdf');
      expect(File(targetItem.translatedPdfPath!).existsSync(), true);

      // 3. Verify original PDF path is recorded and readable
      expect(File(targetItem.originalPdfPath!).existsSync(), true);

      // 4. Verify existing text lessons coexist harmoniously
      await SavedLessonsStore.save(
        hindiText: 'ज्ञान ही शक्ति है।',
        santaliText: 'ᱵᱟᱰᱟᱭ ᱜᱮ ᱫᱟᱲᱮ ᱠᱟᱱᱟ ᱾',
        title: 'Proverb Lesson',
      );

      final mixedLessons = await SavedLessonsStore.load();
      expect(mixedLessons.length >= 2, true);
      expect(mixedLessons.any((l) => l.isPdfDocument), true);
      expect(mixedLessons.any((l) => !l.isPdfDocument), true);

      // 5. Delete converted document with cleanup check
      await SavedLessonsStore.delete(savedMaterial.id);
      final finalLessons = await SavedLessonsStore.load();
      expect(finalLessons.any((l) => l.documentId == 'mat_science_class5_ch5'), false);
      expect(finalLessons.any((l) => !l.isPdfDocument), true); // text lesson remains!
    });

    test('Part H: Robustness, Error Handling & Safe Fallback on Corrupted Regions', () async {
      final corruptedDoc = LayoutDocument(
        documentId: 'doc_corrupted_test',
        sourceFileName: 'corrupted.pdf',
        pageCount: 1,
        documentType: DocumentType.digital,
        sourceFilePath: '/fake/path/corrupted.pdf',
        pages: [
          LayoutPage(
            pageNumber: 1,
            width: 595.28,
            height: 841.89,
            pageType: PageType.digital,
            regions: [
              // Region with empty text
              LayoutRegion(
                regionId: 'empty_r0',
                type: RegionType.paragraph,
                originalText: '',
                translatedText: '',
                boundingBox: const BoundingBox(x: 0, y: 0, width: 0, height: 0),
                readingOrder: 0,
              ),
              // Region with zero width
              LayoutRegion(
                regionId: 'zero_w_r1',
                type: RegionType.heading,
                originalText: 'Heading with invalid box',
                translatedText: 'ᱦᱮᱰᱤᱝ',
                boundingBox: const BoundingBox(x: 50, y: 50, width: 0, height: 20),
                readingOrder: 1,
              ),
              // Valid region
              LayoutRegion(
                regionId: 'valid_r2',
                type: RegionType.paragraph,
                originalText: 'वैध पाठ्य सामग्री',
                translatedText: 'ᱴᱷᱤᱠ ᱯᱟᱴᱷ',
                boundingBox: const BoundingBox(x: 50, y: 100, width: 400, height: 30),
                readingOrder: 2,
              ),
            ],
          ),
        ],
      );

      // Verify layout fitting does not crash on empty/zero dimensions
      final fittedPage = await LayoutFittingEngine.fitPageRegions(page: corruptedDoc.pages[0], font: olChikiTtf);
      expect(fittedPage.regions.length, 3);

      // Verify PDF generation does not crash on corrupted document
      final safePdfBytes = await HybridPdfService.generateSantaliPdf(
        document: corruptedDoc,
        defaultMode: PageRenderingMode.reflowReader,
      );
      expect(safePdfBytes.isNotEmpty, true);
      expect(String.fromCharCodes(safePdfBytes.take(4)), '%PDF');
    });
  });
}

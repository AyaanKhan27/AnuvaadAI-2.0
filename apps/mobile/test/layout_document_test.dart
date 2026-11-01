import 'package:flutter_test/flutter_test.dart';
import 'package:anuvaadai/data/layout_document.dart';

void main() {
  group('BoundingBox', () {
    test('geometric properties and operations', () {
      const box1 = BoundingBox(x: 10, y: 20, width: 100, height: 50);
      expect(box1.right, 110.0);
      expect(box1.bottom, 70.0);
      expect(box1.centerX, 60.0);
      expect(box1.centerY, 45.0);
      expect(box1.area, 5000.0);
      expect(box1.isEmpty, false);

      const box2 = BoundingBox(x: 50, y: 40, width: 80, height: 60);
      expect(box1.intersects(box2), true);

      final unionBox = box1.union(box2);
      expect(unionBox.x, 10.0);
      expect(unionBox.y, 20.0);
      expect(unionBox.right, 130.0);
      expect(unionBox.bottom, 100.0);

      const insideBox = BoundingBox(x: 20, y: 30, width: 40, height: 20);
      expect(box1.contains(insideBox), true);
      expect(insideBox.contains(box1), false);
    });

    test('coordinate conversions (normalized and pixel)', () {
      const box = BoundingBox(x: 72, y: 144, width: 288, height: 144);
      // Normalized on 576 x 576 page
      final norm = box.toNormalized(pageWidth: 576, pageHeight: 576);
      expect(norm.x, closeTo(0.125, 0.001));
      expect(norm.y, closeTo(0.25, 0.001));
      expect(norm.width, closeTo(0.5, 0.001));
      expect(norm.height, closeTo(0.25, 0.001));

      final denorm = BoundingBox.fromNormalized(
        normalized: norm,
        pageWidth: 576,
        pageHeight: 576,
      );
      expect(denorm.x, closeTo(72.0, 0.001));
      expect(denorm.y, closeTo(144.0, 0.001));

      // Pixel conversion: 72 pt at 144 DPI = 144 pixels
      final pixelBox = box.toPixel(targetDpi: 144.0, baseDpi: 72.0);
      expect(pixelBox.x, 144.0);
      expect(pixelBox.width, 576.0);

      final backToPt = BoundingBox.fromPixel(pixelBox: pixelBox, sourceDpi: 144.0, baseDpi: 72.0);
      expect(backToPt.x, 72.0);
      expect(backToPt.width, 288.0);
    });
  });

  group('LayoutDocument serialization & roundtrip', () {
    test('full document JSON roundtrip preserves all fields', () {
      final doc = LayoutDocument(
        documentId: 'doc_12345',
        sourceFileName: 'Paryavaran_Class5.pdf',
        sourceLanguage: 'hin_Deva',
        targetLanguage: 'sat_Olck',
        pageCount: 2,
        documentType: DocumentType.mixed,
        conversionStatus: ConversionStatus.translating,
        sourceFilePath: '/sdcard/Download/Paryavaran_Class5.pdf',
        outputFilePath: '/sdcard/Download/Paryavaran_Class5_Santali.pdf',
        pages: [
          LayoutPage(
            pageNumber: 1,
            width: 595.28,
            height: 841.89,
            rotation: 0,
            pageType: PageType.digital,
            regions: [
              LayoutRegion(
                regionId: 'p1_r0',
                type: RegionType.heading,
                originalText: 'पर्यावरण एवं स्वच्छता',
                translatedText: 'ᱯᱚᱨᱤᱵᱮᱥ ᱟᱨ ᱥᱟᱯᱷᱟ',
                boundingBox: const BoundingBox(x: 40, y: 50, width: 515, height: 30),
                fontSpec: const FontSpec(fontSize: 18.0, isBold: true),
                alignment: TextAlignment.center,
                readingOrder: 0,
                translationStatus: RegionTranslationStatus.translated,
                renderingStatus: RenderingStatus.facsimileMasked,
              ),
              LayoutRegion(
                regionId: 'p1_r1',
                type: RegionType.paragraph,
                originalText: 'जल ही जीवन का आधार है।',
                translatedText: 'ᱫᱟᱜ ᱜᱮ ᱡᱤᱭᱚᱱ ᱨᱮᱱᱟᱜ ᱢᱩᱬ ᱠᱟᱱᱟ ᱾',
                boundingBox: const BoundingBox(x: 40, y: 90, width: 515, height: 45),
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
            backgroundImagePath: '/sdcard/Android/data/.../cache/p2.png',
            regions: [
              LayoutRegion(
                regionId: 'p2_r0',
                type: RegionType.table,
                originalText: 'सारणी १',
                translatedText: 'ᱛᱟᱹᱞᱠᱟᱹ ᱑',
                boundingBox: const BoundingBox(x: 50, y: 100, width: 495, height: 200),
                readingOrder: 0,
                ocrConfidence: 0.94,
                children: [
                  LayoutRegion(
                    regionId: 'p2_r0_c0',
                    type: RegionType.tableCell,
                    originalText: 'स्रोत',
                    translatedText: 'ᱯᱷᱮᱰᱟᱛ',
                    boundingBox: const BoundingBox(x: 50, y: 100, width: 247, height: 30),
                    readingOrder: 0,
                    ocrConfidence: 0.98,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final jsonMap = doc.toJson();
      expect(jsonMap.isNotEmpty, true);
      final jsonStr = doc.toJsonString();
      final reconstructed = LayoutDocument.fromJsonString(jsonStr);

      expect(reconstructed.documentId, 'doc_12345');
      expect(reconstructed.sourceFileName, 'Paryavaran_Class5.pdf');
      expect(reconstructed.documentType, DocumentType.mixed);
      expect(reconstructed.pageCount, 2);
      expect(reconstructed.digitalPageCount, 1);
      expect(reconstructed.scannedPageCount, 1);
      expect(reconstructed.totalRegions, 3);
      expect(reconstructed.translatedRegions, 2);
      expect(reconstructed.translationProgress, closeTo(0.666, 0.01));

      final p1 = reconstructed.pages[0];
      expect(p1.pageNumber, 1);
      expect(p1.isDigital, true);
      expect(p1.regions[0].fontSpec.isBold, true);
      expect(p1.regions[0].fontSpec.fontSize, 18.0);
      expect(p1.regions[0].alignment, TextAlignment.center);

      final p2 = reconstructed.pages[1];
      expect(p2.pageNumber, 2);
      expect(p2.isScanned, true);
      expect(p2.regions[0].children.length, 1);
      expect(p2.regions[0].children[0].ocrConfidence, 0.98);
      expect(p2.regions[0].children[0].type, RegionType.tableCell);
    });
  });
}

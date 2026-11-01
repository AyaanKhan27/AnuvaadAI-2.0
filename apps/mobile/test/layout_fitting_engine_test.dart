import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:anuvaadai/data/layout_document.dart';
import 'package:anuvaadai/services/layout_fitting_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PdfTtfFont ttfFont;

  setUpAll(() async {
    final fontFile = File('assets/fonts/NotoSansOlChiki-Regular.ttf');
    final fontBytes = await fontFile.readAsBytes();
    final pdfDoc = PdfDocument();
    ttfFont = PdfTtfFont(pdfDoc, ByteData.view(fontBytes.buffer));
  });

  group('LayoutFittingEngine', () {
    test('text width measurement with Ol Chiki TrueType font', () {
      const text = 'ᱥᱟᱱᱛᱟᱲᱤ ᱥᱮᱪᱮᱫ';
      final width10 = LayoutFittingEngine.measureStringWidth(text, 10.0, font: ttfFont);
      final width20 = LayoutFittingEngine.measureStringWidth(text, 20.0, font: ttfFont);

      expect(width10 > 0, true);
      expect(width20, closeTo(width10 * 2.0, 0.05));
    });

    test('line wrapping respects maxWidth and word boundaries', () {
      const text = 'ᱦᱮᱞᱳ ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱾ ᱟᱞᱮ ᱟᱹᱰᱤ ᱨᱟᱹᱥᱠᱟᱹ ᱛᱮ ᱥᱮᱪᱮᱫᱚᱜ ᱠᱟᱱᱟ ᱾';
      final lines = LayoutFittingEngine.wrapTextToLines(
        text: text,
        maxWidth: 160.0,
        fontSize: 12.0,
        font: ttfFont,
      );

      expect(lines.length >= 2, true);
      for (final line in lines) {
        final lineWidth = LayoutFittingEngine.measureStringWidth(line, 12.0, font: ttfFont);
        expect(lineWidth <= 170.0, true);
      }
    });

    test('single line fitting when text fits within bounding box', () async {
      final region = LayoutRegion(
        regionId: 'r1',
        type: RegionType.heading,
        originalText: 'पर्यावरण',
        translatedText: 'ᱯᱚᱨᱤᱵᱮᱥ',
        boundingBox: const BoundingBox(x: 40, y: 50, width: 200, height: 25),
        fontSpec: const FontSpec(fontSize: 14.0),
        readingOrder: 0,
      );

      final result = await LayoutFittingEngine.fitRegionText(
        region: region,
        font: ttfFont,
      );

      expect(result.fitsInOriginalBox, true);
      expect(result.wasRegionExpanded, false);
      expect(result.wasReflowed, false);
      expect(result.lines.length, 1);
      expect(result.fontSize, 14.0);
    });

    test('font scaling when text is slightly wider than bounding box', () async {
      final region = LayoutRegion(
        regionId: 'r2',
        type: RegionType.paragraph,
        originalText: 'जल ही जीवन है',
        translatedText: 'ᱫᱟᱜ ᱜᱮ ᱡᱤᱭᱚᱱ ᱠᱟᱱᱟ ᱾',
        boundingBox: const BoundingBox(x: 40, y: 100, width: 85, height: 18),
        fontSpec: const FontSpec(fontSize: 12.0),
        readingOrder: 1,
      );

      final result = await LayoutFittingEngine.fitRegionText(
        region: region,
        font: ttfFont,
      );

      expect(result.fitsInOriginalBox, true);
      expect(result.scaleFactor < 1.0, true);
      expect(result.scaleFactor >= 0.70, true);
      expect(result.fontSize < 12.0, true);
    });

    test('multi-line wrapping and vertical whitespace expansion', () async {
      final region = LayoutRegion(
        regionId: 'r3',
        type: RegionType.paragraph,
        originalText: 'हम सब मिलकर अपने गाँव को सुंदर और स्वच्छ बनाएंगे।',
        translatedText: 'ᱟᱵᱚ ᱡᱚᱛᱚ ᱦᱚᱲ ᱢᱤᱫ ᱠᱟᱛᱮ ᱟᱵᱚᱣᱟᱜ ᱟᱹᱛᱩ ᱪᱮᱦᱨᱟ ᱟᱨ ᱥᱟᱯᱷᱟ ᱵᱚᱱ ᱵᱮᱱᱟᱣᱟ ᱾',
        boundingBox: const BoundingBox(x: 40, y: 150, width: 140, height: 15),
        fontSpec: const FontSpec(fontSize: 11.0),
        readingOrder: 2,
      );

      final result = await LayoutFittingEngine.fitRegionText(
        region: region,
        maxAvailableBottomY: 300.0,
        font: ttfFont,
      );

      expect(result.lines.length >= 2, true);
      expect(result.wasRegionExpanded, true);
      expect(result.fittedBounds.height > 15.0, true);
    });

    test('collision detection flags overlapping bounding boxes', () {
      final regions = [
        LayoutRegion(
          regionId: 'a',
          type: RegionType.paragraph,
          originalText: 'A',
          boundingBox: const BoundingBox(x: 10, y: 10, width: 100, height: 50),
          readingOrder: 0,
        ),
        LayoutRegion(
          regionId: 'b',
          type: RegionType.paragraph,
          originalText: 'B',
          boundingBox: const BoundingBox(x: 50, y: 30, width: 100, height: 50),
          readingOrder: 1,
        ),
        LayoutRegion(
          regionId: 'c',
          type: RegionType.paragraph,
          originalText: 'C',
          boundingBox: const BoundingBox(x: 200, y: 200, width: 50, height: 50),
          readingOrder: 2,
        ),
      ];

      final collisions = LayoutFittingEngine.detectCollisions(regions);
      expect(collisions.length, 1);
      expect(collisions[0].contains('Collision between a'), true);
      expect(collisions[0].contains('and b'), true);
    });
  });
}

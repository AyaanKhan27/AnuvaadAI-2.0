import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anuvaadai/pages/pdf_translation_studio_page.dart';
import 'package:anuvaadai/services/pdf_studio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PDF Translation Studio Service Tests', () {
    test('1. Structured document parsing correctly identifies headings, tables, lists and paragraphs', () async {
      final doc = await PdfStudioService.extractDocument(sampleType: 'science_environment');

      expect(doc.fileName, equals('Paryavaran_Class5_Chapter3.pdf'));
      expect(doc.pages.length, equals(2));

      // Page 1 blocks inspection
      final p1 = doc.pages[0];
      final types = p1.blocks.map((b) => b.type).toList();

      expect(types, contains(BlockType.heading1));
      expect(types, contains(BlockType.paragraph));
      expect(types, contains(BlockType.heading2));
      expect(types, contains(BlockType.bulletList));
      expect(types, contains(BlockType.table));

      // Inspect table structure
      final tableBlock = p1.blocks.firstWhere((b) => b.type == BlockType.table);
      expect(tableBlock.tableRows.length, equals(4)); // Header + 3 data rows
      expect(tableBlock.tableRows[0].length, equals(3)); // 3 columns
      expect(tableBlock.tableRows[0][0], equals('जल स्रोत'));
    });

    test('2. Batch offline translation translates all blocks preserving matrix geometry', () async {
      // Mock the translation channel to simulate offline IndicTrans2 response
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('anuvaad/translation'),
              (MethodCall call) async {
        if (call.method == 'translate') {
          final args = call.arguments as Map<dynamic, dynamic>? ?? {};
          final text = args['text'] as String? ?? '';
          return {
            'text': 'ᱥᱟᱱᱛᱟᱲᱤ: $text',
            'tokenIds': [8, 29925, 100, 2],
          };
        }
        return null;
      });

      final doc = await PdfStudioService.extractDocument(sampleType: 'science_environment');
      final translatedDoc = await PdfStudioService.translateDocumentToSantali(
        document: doc,
        srcLang: 'hin_Deva',
      );

      expect(translatedDoc.pages.length, equals(2));

      // Verify page 1 paragraph translated
      final pBlock = translatedDoc.pages[0].blocks.firstWhere((b) => b.type == BlockType.paragraph);
      expect(pBlock.translatedText, startsWith('ᱥᱟᱱᱛᱟᱲᱤ:'));

      // Verify table translation preserves 4 rows x 3 columns
      final tBlock = translatedDoc.pages[0].blocks.firstWhere((b) => b.type == BlockType.table);
      expect(tBlock.translatedTableRows.length, equals(4));
      expect(tBlock.translatedTableRows[0].length, equals(3));
      expect(tBlock.translatedTableRows[0][0], startsWith('ᱥᱟᱱᱛᱟᱲᱤ:'));

      // Verify bullet list translated
      final lBlock = translatedDoc.pages[0].blocks.firstWhere((b) => b.type == BlockType.bulletList);
      expect(lBlock.translatedListItems.length, equals(3));
      expect(lBlock.translatedListItems[0], startsWith('ᱥᱟᱱᱛᱟᱲᱤ:'));
    });

    test('3. Generates high-fidelity PDF embedding Noto Sans Ol Chiki TrueType font', () async {
      final doc = await PdfStudioService.extractDocument(sampleType: 'science_environment');

      // Pre-fill some Santali text
      doc.pages[0].blocks[0].translatedText = 'ᱯᱟᱴᱷ ᱓: ᱟᱵᱚᱣᱟᱜ ᱯᱚᱨᱤᱵᱮᱥ';
      doc.pages[0].blocks[1].translatedText = 'ᱫᱟᱜ ᱜᱮ ᱡᱤᱣᱤ ᱨᱮᱱᱟᱜ ᱢᱩᱬᱩᱛ ᱠᱟᱱᱟ ᱾';

      final Uint8List pdfBytes = await PdfStudioService.generateSantaliPdf(
        document: doc,
        schoolTitle: 'ᱟᱱᱩᱵᱟᱫᱽ ᱮ.ᱟᱭᱤ. ᱥᱴᱩᱰᱤᱭᱳ',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
      // Standard PDF header signature check '%PDF-'
      final signature = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(signature, equals('%PDF-'));
    });

    test('4. savePdfToDevice safely exports to destination and generates correct filename', () async {
      final dummyPdf = Uint8List.fromList('%PDF-1.4 sample pdf content'.codeUnits);
      final result = await PdfStudioService.savePdfToDevice(
        pdfBytes: dummyPdf,
        originalFileName: 'Chapter_5_Science.pdf',
        pageCount: 3,
      );

      expect(result.success, isTrue);
      expect(result.filePath, contains('Chapter_5_Science_Santali_OlChiki.pdf'));
      expect(result.fileSizeBytes, equals(dummyPdf.length));
      expect(result.pageCount, equals(3));

      // Clean up test file if created
      try {
        final f = File(result.filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    });
  });

  group('PDF Translation Studio Widget Tests', () {
    testWidgets('5. Renders studio UI, displays sample document blocks and page switcher', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PdfTranslationStudioPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title and badges
      expect(find.text('Offline PDF-to-Santali Studio'), findsOneWidget);
      expect(find.text('Ol Chiki Offline'), findsOneWidget);
      expect(find.text('Classroom Document Input'), findsOneWidget);

      // Verify sample document loaded
      expect(find.text('Paryavaran_Class5_Chapter3.pdf'), findsAtLeastNWidgets(1));
      expect(find.text('Page 1 (5 blocks)'), findsOneWidget);
      expect(find.text('Page 2 (3 blocks)'), findsOneWidget);

      // Verify block types rendered
      expect(find.text('Heading 1 (Title)'), findsOneWidget);
      expect(find.text('Paragraph'), findsOneWidget);
      expect(find.text('Table Matrix'), findsOneWidget);
      expect(find.text('Bullet List'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Translate All to Santali Ol Chiki'), findsOneWidget);
      expect(find.textContaining('Export to /sdcard/Download/'), findsOneWidget);

      // Switch to Page 2
      await tester.ensureVisible(find.text('Page 2 (3 blocks)'));
      await tester.tap(find.text('Page 2 (3 blocks)'));
      await tester.pumpAndSettle();

      expect(find.text('Heading 2 (Section)'), findsOneWidget);
    });

    testWidgets('6. Language selector updates source language', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PdfTranslationStudioPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Find dropdown
      expect(find.text('Hindi (Devanagari)'), findsAtLeast(1));

      // Tap quick load English sample
      await tester.tap(find.text('Community (English • Grade 4)'));
      await tester.pumpAndSettle();

      expect(find.text('Community_Helpers_Grade4.pdf'), findsAtLeastNWidgets(1));
      expect(find.text('English (Latin)'), findsAtLeast(1));
    });
  });
}

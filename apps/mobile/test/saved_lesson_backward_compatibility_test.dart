import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anuvaadai/data/saved_lesson.dart';

/// Representation of the original Release-era SavedLesson (pre-Phase 2)
/// that only possessed the foundational 7 fields.
class LegacyReleaseSavedLesson {
  const LegacyReleaseSavedLesson({
    required this.id,
    required this.hindiText,
    required this.santaliText,
    required this.savedAt,
    this.title = '',
    this.sourceLang = 'hin_Deva',
    this.targetLang = 'sat_Olck',
  });

  final String id;
  final String hindiText;
  final String santaliText;
  final DateTime savedAt;
  final String title;
  final String sourceLang;
  final String targetLang;

  factory LegacyReleaseSavedLesson.fromJson(Map<String, dynamic> json) =>
      LegacyReleaseSavedLesson(
        id: json['id'] as String? ?? '',
        hindiText: json['hindiText'] as String? ?? json['sourceText'] as String? ?? '',
        santaliText: json['santaliText'] as String? ?? json['translatedText'] as String? ?? '',
        savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
        title: json['title'] as String? ?? '',
        sourceLang: json['sourceLang'] as String? ?? 'hin_Deva',
        targetLang: json['targetLang'] as String? ?? 'sat_Olck',
      );

  Map<String, Object> toJson() => {
        'id': id,
        'hindiText': hindiText,
        'santaliText': santaliText,
        'savedAt': savedAt.toIso8601String(),
        'title': title,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
      };
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 2.3.5: Saved Lessons Persistence Backward Compatibility', () {
    test('Scenario 1: Release-era data loaded by Phase 2.3 implementation', () async {
      // 1A: Standard release-era text lesson JSON (7 fields)
      final legacyJson = {
        'id': 'legacy_101',
        'hindiText': 'जल ही जीवन है। हमें पानी की बचत करनी चाहिए।',
        'santaliText': 'ᱫᱟᱜ ᱜᱮ ᱡᱤᱣᱤ ᱠᱟᱱᱟ᱾ ᱟᱵᱚ ᱫᱟᱜ ᱵᱟᱧᱪᱟᱣ ᱞᱟᱹᱠᱛᱤᱭᱟᱱᱟ᱾',
        'savedAt': '2026-10-30T10:15:30.000Z',
        'title': 'Water Conservation Lesson',
        'sourceLang': 'hin_Deva',
        'targetLang': 'sat_Olck',
      };

      final lesson = SavedLesson.fromJson(legacyJson);

      expect(lesson.id, 'legacy_101');
      expect(lesson.hindiText, 'जल ही जीवन है। हमें पानी की बचत करनी चाहिए।');
      expect(lesson.santaliText, 'ᱫᱟᱜ ᱜᱮ ᱡᱤᱣᱤ ᱠᱟᱱᱟ᱾ ᱟᱵᱚ ᱫᱟᱜ ᱵᱟᱧᱪᱟᱣ ᱞᱟᱹᱠᱛᱤᱭᱟᱱᱟ᱾');
      expect(lesson.savedAt, DateTime.parse('2026-10-30T10:15:30.000Z'));
      expect(lesson.title, 'Water Conservation Lesson');
      expect(lesson.sourceLang, 'hin_Deva');
      expect(lesson.targetLang, 'sat_Olck');
      // Verify safe default values for new Phase 2.3 fields
      expect(lesson.isPdfDocument, false);
      expect(lesson.category, 'General Lesson');
      expect(lesson.originalPdfPath, isNull);
      expect(lesson.translatedPdfPath, isNull);
      expect(lesson.originalFileName, isNull);
      expect(lesson.pageCount, isNull);
      expect(lesson.documentId, isNull);

      // 1B: Alternate legacy keys (sourceText & translatedText)
      final alternateLegacyJson = {
        'id': 'legacy_alt_102',
        'sourceText': 'पेड़ हमारे मित्र हैं।',
        'translatedText': 'ᱫᱟᱨᱮ ᱠᱚ ᱟᱵᱚᱨᱤᱱ ᱜᱟᱛᱮ ᱠᱟᱱᱟ ᱠᱚ᱾',
        'savedAt': '2026-10-30T11:00:00.000Z',
        'title': 'Trees Lesson',
        'sourceLang': 'hin_Deva',
        'targetLang': 'sat_Olck',
      };

      final altLesson = SavedLesson.fromJson(alternateLegacyJson);
      expect(altLesson.id, 'legacy_alt_102');
      expect(altLesson.hindiText, 'पेड़ हमारे मित्र हैं।');
      expect(altLesson.santaliText, 'ᱫᱟᱨᱮ ᱠᱚ ᱟᱵᱚᱨᱤᱱ ᱜᱟᱛᱮ ᱠᱟᱱᱟ ᱠᱚ᱾');
      expect(altLesson.isPdfDocument, false);
    });

    test('Scenario 2: Phase 2.3 data loaded by Legacy Release implementation', () {
      // Phase 2.3 PDF Course Material JSON
      final phase23PdfJson = {
        'id': 'doc_science_ch5',
        'hindiText': 'PDF Document: Science_Class5_Ch5.pdf',
        'santaliText': 'ᱥᱟᱱᱛᱟᱲᱤ ᱯᱤ.ᱰᱤ.ᱮᱯᱷ. ᱫᱚᱞᱤᱞ: Science_Class5_Ch5.pdf',
        'savedAt': '2026-11-01T04:30:00.000Z',
        'title': 'NCERT Science Class 5 Chapter 5',
        'sourceLang': 'hin_Deva',
        'targetLang': 'sat_Olck',
        'originalPdfPath': '/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/course_materials/doc_science_ch5_orig.pdf',
        'translatedPdfPath': '/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/course_materials/doc_science_ch5_translated.pdf',
        'originalFileName': 'Science_Class5_Ch5.pdf',
        'pageCount': 4,
        'category': 'Course Material',
        'isPdfDocument': true,
        'documentId': 'doc_science_ch5',
      };

      // When decoded by the Release implementation:
      final legacyLesson = LegacyReleaseSavedLesson.fromJson(phase23PdfJson);

      // Verify no crash, core text properties preserved
      expect(legacyLesson.id, 'doc_science_ch5');
      expect(legacyLesson.title, 'NCERT Science Class 5 Chapter 5');
      expect(legacyLesson.hindiText, 'PDF Document: Science_Class5_Ch5.pdf');
      expect(legacyLesson.santaliText, 'ᱥᱟᱱᱛᱟᱲᱤ ᱯᱤ.ᱰᱤ.ᱮᱯᱷ. ᱫᱚᱞᱤᱞ: Science_Class5_Ch5.pdf');
      expect(legacyLesson.sourceLang, 'hin_Deva');
      expect(legacyLesson.targetLang, 'sat_Olck');
      expect(legacyLesson.savedAt, DateTime.parse('2026-11-01T04:30:00.000Z'));
    });

    test('Scenario 3: Unknown and unexpected fields handled safely without throwing', () {
      final jsonWithUnexpectedFields = {
        'id': 'test_future_999',
        'hindiText': 'भविष्य का पाठ।',
        'santaliText': 'ᱫᱟᱨᱟᱭ ᱯᱟᱲᱦᱟᱣ᱾',
        'savedAt': '2026-11-01T08:00:00.000Z',
        'title': 'Future Lesson',
        'sourceLang': 'hin_Deva',
        'targetLang': 'sat_Olck',
        'future_schema_version': 99,
        'experimental_vector_embeddings': [0.12, 0.45, -0.89],
        'sync_flags': {'cloud_synced': false, 'revision': 42},
        'unsupported_null_field': null,
      };

      // Both modern and legacy should parse without throwing
      final modern = SavedLesson.fromJson(jsonWithUnexpectedFields);
      expect(modern.id, 'test_future_999');
      expect(modern.title, 'Future Lesson');

      final legacy = LegacyReleaseSavedLesson.fromJson(jsonWithUnexpectedFields);
      expect(legacy.id, 'test_future_999');
      expect(legacy.title, 'Future Lesson');
    });

    test('Scenario 4: SharedPreferences mixed collection round-trip', () async {
      // Simulate existing SharedPreferences containing both release text lesson and new PDF course material
      final mixedData = [
        {
          'id': 'legacy_lesson_1',
          'hindiText': 'नमस्ते शिक्षक जी।',
          'santaliText': 'ᱡᱚᱦᱟᱨ ᱢᱟᱪᱮᱛ ᱜᱚᱢᱠᱮ᱾',
          'savedAt': '2026-10-31T12:00:00.000Z',
          'title': 'Classroom Greeting',
          'sourceLang': 'hin_Deva',
          'targetLang': 'sat_Olck',
        },
        {
          'id': 'doc_worksheet_ch2',
          'hindiText': 'PDF Document: Environmental_Worksheet.pdf',
          'santaliText': 'ᱥᱟᱱᱛᱟᱲᱤ ᱯᱤ.ᱰᱤ.ᱮᱯᱷ. ᱫᱚᱞᱤᱞ: Environmental_Worksheet.pdf',
          'savedAt': '2026-11-01T05:00:00.000Z',
          'title': 'Environmental Studies Worksheet',
          'sourceLang': 'hin_Deva',
          'targetLang': 'sat_Olck',
          'originalPdfPath': '/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/course_materials/doc_worksheet_ch2_orig.pdf',
          'translatedPdfPath': '/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/course_materials/doc_worksheet_ch2_translated.pdf',
          'originalFileName': 'Environmental_Worksheet.pdf',
          'pageCount': 2,
          'category': 'Course Material',
          'isPdfDocument': true,
          'documentId': 'doc_worksheet_ch2',
        }
      ];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_lessons_v1', jsonEncode(mixedData));

      // Load via SavedLessonsStore
      final loaded = await SavedLessonsStore.load();
      expect(loaded.length, 2);

      // Verify sorting by savedAt descending: doc_worksheet_ch2 is newer (Nov 1 vs Oct 31)
      final pdfItem = loaded[0];
      final textItem = loaded[1];

      expect(pdfItem.id, 'doc_worksheet_ch2');
      expect(pdfItem.isPdfDocument, true);
      expect(pdfItem.pageCount, 2);
      expect(pdfItem.originalFileName, 'Environmental_Worksheet.pdf');
      expect(pdfItem.originalPdfPath, '/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/course_materials/doc_worksheet_ch2_orig.pdf');

      expect(textItem.id, 'legacy_lesson_1');
      expect(textItem.isPdfDocument, false);
      expect(textItem.hindiText, 'नमस्ते शिक्षक जी।');
      expect(textItem.santaliText, 'ᱡᱚᱦᱟᱨ ᱢᱟᱪᱮᱛ ᱜᱚᱢᱠᱮ᱾');

      // Update text item to verify store update does not corrupt PDF item
      final updatedText = textItem.copyWith(santaliText: 'ᱡᱚᱦᱟᱨ ᱢᱟᱪᱮᱛ ᱜᱚᱢᱠᱮ ᱛᱤᱠᱤᱱ');
      await SavedLessonsStore.update(updatedText);

      final reloaded = await SavedLessonsStore.load();
      expect(reloaded.length, 2);
      expect(reloaded[1].santaliText, 'ᱡᱚᱦᱟᱨ ᱢᱟᱪᱮᱛ ᱜᱚᱢᱠᱮ ᱛᱤᱠᱤᱱ');
      // Ensure PDF item remains fully intact with all metadata
      expect(reloaded[0].id, 'doc_worksheet_ch2');
      expect(reloaded[0].isPdfDocument, true);
      expect(reloaded[0].originalFileName, 'Environmental_Worksheet.pdf');
    });

    test('Scenario 5: Repeated serialization-deserialization cycles do not lose content', () {
      final original = SavedLesson(
        id: 'stable_cycle_doc',
        hindiText: 'पुनरावृत्ति परीक्षण पाठ।',
        santaliText: 'ᱫᱚᱦᱲᱟ ᱵᱤᱰᱟᱹᱣ ᱯᱟᱲᱦᱟᱣ᱾',
        savedAt: DateTime.parse('2026-11-01T06:00:00.000Z'),
        title: 'Cycle Stability Test',
        sourceLang: 'hin_Deva',
        targetLang: 'sat_Olck',
        originalPdfPath: '/storage/emulated/0/doc_orig.pdf',
        translatedPdfPath: '/storage/emulated/0/doc_trans.pdf',
        originalFileName: 'cycle_test.pdf',
        pageCount: 5,
        category: 'Course Material',
        isPdfDocument: true,
        documentId: 'stable_cycle_doc',
      );

      var current = original;
      for (var i = 0; i < 10; i++) {
        final jsonMap = current.toJson();
        final jsonString = jsonEncode(jsonMap);
        final decodedMap = jsonDecode(jsonString) as Map<String, dynamic>;
        current = SavedLesson.fromJson(decodedMap);
      }

      expect(current.id, original.id);
      expect(current.hindiText, original.hindiText);
      expect(current.santaliText, original.santaliText);
      expect(current.savedAt, original.savedAt);
      expect(current.title, original.title);
      expect(current.sourceLang, original.sourceLang);
      expect(current.targetLang, original.targetLang);
      expect(current.originalPdfPath, original.originalPdfPath);
      expect(current.translatedPdfPath, original.translatedPdfPath);
      expect(current.originalFileName, original.originalFileName);
      expect(current.pageCount, original.pageCount);
      expect(current.category, original.category);
      expect(current.isPdfDocument, original.isPdfDocument);
      expect(current.documentId, original.documentId);
    });

    test('Scenario 6: Legacy Release write-back consequence (Rollback caveat proof)', () {
      // If a Phase 2.3 PDF Course Material exists in SharedPreferences...
      final phase23PdfJson = {
        'id': 'doc_test_writeback',
        'hindiText': 'PDF Document: Test.pdf',
        'santaliText': 'ᱥᱟᱱᱛᱟᱲᱤ ᱯᱤ.ᱰᱤ.ᱮᱯᱷ. ᱫᱚᱞᱤᱞ: Test.pdf',
        'savedAt': '2026-11-01T07:00:00.000Z',
        'title': 'Test Material',
        'sourceLang': 'hin_Deva',
        'targetLang': 'sat_Olck',
        'originalPdfPath': '/path/to/orig.pdf',
        'translatedPdfPath': '/path/to/trans.pdf',
        'originalFileName': 'Test.pdf',
        'pageCount': 3,
        'category': 'Course Material',
        'isPdfDocument': true,
        'documentId': 'doc_test_writeback',
      };

      // The release app parses it safely without crash
      final legacyParsed = LegacyReleaseSavedLesson.fromJson(phase23PdfJson);
      expect(legacyParsed.id, 'doc_test_writeback');

      // BUT if the release app re-serializes and writes it back (e.g. user edits title in release app):
      final legacyWrittenBack = legacyParsed.toJson();

      // The 7 core fields are preserved:
      expect(legacyWrittenBack['id'], 'doc_test_writeback');
      expect(legacyWrittenBack['title'], 'Test Material');
      expect(legacyWrittenBack['hindiText'], 'PDF Document: Test.pdf');

      // BUT the PDF-specific metadata fields are NOT written back by the legacy serializer:
      expect(legacyWrittenBack.containsKey('originalPdfPath'), isFalse);
      expect(legacyWrittenBack.containsKey('translatedPdfPath'), isFalse);
      expect(legacyWrittenBack.containsKey('originalFileName'), isFalse);
      expect(legacyWrittenBack.containsKey('pageCount'), isFalse);
      expect(legacyWrittenBack.containsKey('isPdfDocument'), isFalse);

      // This formally demonstrates the rollback caveat:
      // An old release build will preserve the entry as text, but would strip PDF metadata IF modified in the old build.
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anuvaadai/data/saved_lesson.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SavedLessonsStore saves, retrieves, and updates lesson', () async {
    final initial = await SavedLessonsStore.load();
    expect(initial.isEmpty, isTrue);

    final saved = await SavedLessonsStore.save(
      hindiText: 'नमस्ते बच्चों।',
      santaliText: 'ᱦᱮᱞᱳ ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱾',
      title: 'Greetings Lesson',
    );

    expect(saved.hindiText, 'नमस्ते बच्चों।');
    expect(saved.santaliText, 'ᱦᱮᱞᱳ ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱾');
    expect(saved.title, 'Greetings Lesson');
    expect(saved.isPdfDocument, false);

    final loaded = await SavedLessonsStore.load();
    expect(loaded.length, 1);
    expect(loaded.first.id, saved.id);

    // Update
    final updatedLesson = saved.copyWith(santaliText: 'ᱦᱮᱞᱳ ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ');
    await SavedLessonsStore.update(updatedLesson);

    final reloaded = await SavedLessonsStore.load();
    expect(reloaded.first.santaliText, 'ᱦᱮᱞᱳ ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ');

    // Delete
    await SavedLessonsStore.delete(saved.id);
    final emptyAgain = await SavedLessonsStore.load();
    expect(emptyAgain.isEmpty, isTrue);
  });

  test('SavedLessonsStore saves and retrieves converted PDF Course Materials', () async {
    final material = await SavedLessonsStore.savePdfCourseMaterial(
      documentId: 'doc_math_ch1',
      title: 'Class 5 Mathematics Chapter 1',
      originalFileName: 'Math_Class5_Ch1.pdf',
      originalPdfPath: '/sdcard/Download/Math_Class5_Ch1.pdf',
      translatedPdfPath: '/sdcard/Documents/Math_Class5_Ch1_Santali_OlChiki.pdf',
      pageCount: 6,
      category: 'Mathematics',
    );

    expect(material.isPdfDocument, true);
    expect(material.pageCount, 6);
    expect(material.category, 'Mathematics');
    expect(material.translatedPdfPath, '/sdcard/Documents/Math_Class5_Ch1_Santali_OlChiki.pdf');

    final loaded = await SavedLessonsStore.load();
    expect(loaded.length, 1);
    final item = loaded.first;
    expect(item.isPdfDocument, true);
    expect(item.documentId, 'doc_math_ch1');
    expect(item.pageCount, 6);
    expect(item.originalFileName, 'Math_Class5_Ch1.pdf');
  });
}

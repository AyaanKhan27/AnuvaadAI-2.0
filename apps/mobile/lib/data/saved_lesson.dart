import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class SavedLesson {
  const SavedLesson({
    required this.id,
    required this.hindiText,
    required this.santaliText,
    required this.savedAt,
    this.title = '',
    this.sourceLang = 'hin_Deva',
    this.targetLang = 'sat_Olck',
    this.originalPdfPath,
    this.translatedPdfPath,
    this.originalFileName,
    this.pageCount,
    this.category = 'General Lesson',
    this.isPdfDocument = false,
    this.documentId,
  });

  final String id;
  final String hindiText;
  final String santaliText;
  final DateTime savedAt;
  final String title;
  final String sourceLang;
  final String targetLang;
  final String? originalPdfPath;
  final String? translatedPdfPath;
  final String? originalFileName;
  final int? pageCount;
  final String category;
  final bool isPdfDocument;
  final String? documentId;

  String get sourceText => hindiText;
  String get translatedText => santaliText;

  factory SavedLesson.fromJson(Map<String, dynamic> json) => SavedLesson(
    id: json['id'] as String? ?? '',
    hindiText: json['hindiText'] as String? ?? json['sourceText'] as String? ?? '',
    santaliText: json['santaliText'] as String? ?? json['translatedText'] as String? ?? '',
    savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
    title: json['title'] as String? ?? '',
    sourceLang: json['sourceLang'] as String? ?? 'hin_Deva',
    targetLang: json['targetLang'] as String? ?? 'sat_Olck',
    originalPdfPath: json['originalPdfPath'] as String?,
    translatedPdfPath: json['translatedPdfPath'] as String?,
    originalFileName: json['originalFileName'] as String?,
    pageCount: json['pageCount'] as int?,
    category: json['category'] as String? ?? 'General Lesson',
    isPdfDocument: json['isPdfDocument'] as bool? ?? (json['translatedPdfPath'] != null),
    documentId: json['documentId'] as String?,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'hindiText': hindiText,
    'santaliText': santaliText,
    'savedAt': savedAt.toIso8601String(),
    'title': title,
    'sourceLang': sourceLang,
    'targetLang': targetLang,
    'originalPdfPath': ?originalPdfPath,
    'translatedPdfPath': ?translatedPdfPath,
    'originalFileName': ?originalFileName,
    'pageCount': ?pageCount,
    'category': category,
    'isPdfDocument': isPdfDocument,
    'documentId': ?documentId,
  };

  SavedLesson copyWith({
    String? santaliText,
    String? hindiText,
    String? title,
    String? originalPdfPath,
    String? translatedPdfPath,
    String? originalFileName,
    int? pageCount,
    String? category,
    bool? isPdfDocument,
    String? documentId,
  }) => SavedLesson(
    id: id,
    hindiText: hindiText ?? this.hindiText,
    santaliText: santaliText ?? this.santaliText,
    savedAt: savedAt,
    title: title ?? this.title,
    sourceLang: sourceLang,
    targetLang: targetLang,
    originalPdfPath: originalPdfPath ?? this.originalPdfPath,
    translatedPdfPath: translatedPdfPath ?? this.translatedPdfPath,
    originalFileName: originalFileName ?? this.originalFileName,
    pageCount: pageCount ?? this.pageCount,
    category: category ?? this.category,
    isPdfDocument: isPdfDocument ?? this.isPdfDocument,
    documentId: documentId ?? this.documentId,
  );
}

class SavedLessonsStore {
  SavedLessonsStore._();

  static const _storageKey = 'saved_lessons_v1';

  static Future<List<SavedLesson>> load() async {
    final preferences = await SharedPreferences.getInstance();
    return _read(preferences);
  }

  static Future<SavedLesson> save({
    required String hindiText,
    required String santaliText,
    String title = '',
    String sourceLang = 'hin_Deva',
    String targetLang = 'sat_Olck',
    String category = 'General Lesson',
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lesson = SavedLesson(
      id: now.microsecondsSinceEpoch.toString(),
      hindiText: hindiText,
      santaliText: santaliText,
      savedAt: now,
      title: title.isEmpty ? 'Lesson ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}' : title,
      sourceLang: sourceLang,
      targetLang: targetLang,
      category: category,
      isPdfDocument: false,
    );
    final lessons = _read(preferences)..insert(0, lesson);
    await _write(preferences, lessons);
    return lesson;
  }

  /// Stores a converted PDF textbook / worksheet in Course Materials.
  /// If [persistentStorageDir] is provided, physically copies the source and translated
  /// PDF files into a dedicated persistent `course_materials/` directory.
  static Future<SavedLesson> savePdfCourseMaterial({
    required String documentId,
    required String title,
    required String originalFileName,
    required String originalPdfPath,
    required String translatedPdfPath,
    required int pageCount,
    String category = 'Course Material',
    String sourceLang = 'hin_Deva',
    String targetLang = 'sat_Olck',
    String summaryHindi = '',
    String summarySantali = '',
    Directory? persistentStorageDir,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final safeDocId = documentId.isNotEmpty ? documentId : 'doc_${now.millisecondsSinceEpoch}';

    String savedOrigPath = originalPdfPath;
    String savedTgtPath = translatedPdfPath;

    // Real persistent file management: copy to dedicated course_materials directory if storage dir is supplied or on Android
    final effectiveDir = persistentStorageDir ??
        (Platform.isAndroid && Directory('/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files').existsSync()
            ? Directory('/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files')
            : null);

    if (effectiveDir != null) {
      final courseDir = Directory('${effectiveDir.path}/course_materials');
      if (!courseDir.existsSync()) {
        courseDir.createSync(recursive: true);
      }

      final origFile = File(originalPdfPath);
      if (origFile.existsSync()) {
        final destOrig = '${courseDir.path}/${safeDocId}_orig.pdf';
        if (origFile.path != destOrig) {
          origFile.copySync(destOrig);
          savedOrigPath = destOrig;
        }
      }

      final tgtFile = File(translatedPdfPath);
      if (tgtFile.existsSync()) {
        final destTgt = '${courseDir.path}/${safeDocId}_translated.pdf';
        if (tgtFile.path != destTgt) {
          tgtFile.copySync(destTgt);
          savedTgtPath = destTgt;
        }
      }
    }

    final lesson = SavedLesson(
      id: safeDocId,
      documentId: safeDocId,
      hindiText: summaryHindi.isNotEmpty ? summaryHindi : 'PDF Document: $originalFileName',
      santaliText: summarySantali.isNotEmpty ? summarySantali : 'ᱥᱟᱱᱛᱟᱲᱤ ᱯᱤ.ᱰᱤ.ᱮᱯᱷ. ᱫᱚᱞᱤᱞ: $originalFileName',
      savedAt: now,
      title: title.isNotEmpty ? title : originalFileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
      sourceLang: sourceLang,
      targetLang: targetLang,
      originalPdfPath: savedOrigPath,
      translatedPdfPath: savedTgtPath,
      originalFileName: originalFileName,
      pageCount: pageCount,
      category: category,
      isPdfDocument: true,
    );
    final lessons = _read(preferences)..insert(0, lesson);
    await _write(preferences, lessons);
    return lesson;
  }

  static Future<void> update(SavedLesson lesson) async {
    final preferences = await SharedPreferences.getInstance();
    final lessons = _read(preferences);
    final index = lessons.indexWhere((saved) => saved.id == lesson.id);
    if (index < 0) return;
    lessons[index] = lesson;
    await _write(preferences, lessons);
  }

  /// Deletes a lesson by [id]. If [deleteFiles] is true and the lesson is a PDF,
  /// safely removes the associated course material files from disk.
  static Future<void> delete(String id, {bool deleteFiles = false}) async {
    final preferences = await SharedPreferences.getInstance();
    final lessons = _read(preferences);

    if (deleteFiles) {
      final target = lessons.where((l) => l.id == id).firstOrNull;
      if (target != null && target.isPdfDocument) {
        if (target.originalPdfPath != null) {
          final f = File(target.originalPdfPath!);
          if (f.existsSync() && f.path.contains('course_materials')) {
            try {
              f.deleteSync();
            } catch (_) {}
          }
        }
        if (target.translatedPdfPath != null) {
          final f = File(target.translatedPdfPath!);
          if (f.existsSync() && f.path.contains('course_materials')) {
            try {
              f.deleteSync();
            } catch (_) {}
          }
        }
      }
    }

    lessons.removeWhere((lesson) => lesson.id == id);
    await _write(preferences, lessons);
  }

  static List<SavedLesson> _read(SharedPreferences preferences) {
    final encoded = preferences.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return [];
    try {
      final records = jsonDecode(encoded) as List<dynamic>;
      return records
          .map((record) => SavedLesson.fromJson(record as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    } catch (_) {
      return [];
    }
  }

  static Future<void> _write(
    SharedPreferences preferences,
    List<SavedLesson> lessons,
  ) async {
    await preferences.setString(
      _storageKey,
      jsonEncode(lessons.map((lesson) => lesson.toJson()).toList()),
    );
  }
}

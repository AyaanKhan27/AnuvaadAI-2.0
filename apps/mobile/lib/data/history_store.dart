import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.sourceText,
    required this.translatedText,
    required this.sourceLang,
    required this.targetLang,
    required this.createdAt,
  });

  final String id;
  final String sourceText;
  final String translatedText;
  final String sourceLang;
  final String targetLang;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceText': sourceText,
    'translatedText': translatedText,
    'sourceLang': sourceLang,
    'targetLang': targetLang,
    'createdAt': createdAt.toIso8601String(),
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    id: json['id'] as String? ?? '',
    sourceText: json['sourceText'] as String? ?? '',
    translatedText: json['translatedText'] as String? ?? '',
    sourceLang: json['sourceLang'] as String? ?? 'hin_Deva',
    targetLang: json['targetLang'] as String? ?? 'sat_Olck',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class HistoryStore {
  static const _key = 'anuvaad_translation_history';

  static Future<List<HistoryItem>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((item) {
      try {
        return HistoryItem.fromJson(jsonDecode(item) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<HistoryItem>().toList();
  }

  static Future<void> add({
    required String sourceText,
    required String translatedText,
    required String sourceLang,
    required String targetLang,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    final item = HistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sourceText: sourceText,
      translatedText: translatedText,
      sourceLang: sourceLang,
      targetLang: targetLang,
      createdAt: DateTime.now(),
    );
    // Keep up to 100 recent entries
    list.insert(0, item);
    if (list.length > 100) {
      list.removeRange(100, list.length);
    }
    final rawList = list.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_key, rawList);
  }

  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    list.removeWhere((item) => item.id == id);
    final rawList = list.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_key, rawList);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

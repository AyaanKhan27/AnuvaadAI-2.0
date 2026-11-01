import 'package:flutter/services.dart';

import 'translation_directions.dart';

class TranslationResult {
  const TranslationResult({required this.text, required this.tokenIds});

  final String text;
  final List<int> tokenIds;
}

class TranslationService {
  static const MethodChannel _channel = MethodChannel('anuvaad/translation');

  static Future<TranslationResult> translate(
    String text, {
    String srcLang = 'hin_Deva',
    String tgtLang = 'sat_Olck',
  }) async {
    TranslationDirections.requireSupported(srcLang, tgtLang);
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'translate',
      {'text': text, 'srcLang': srcLang, 'tgtLang': tgtLang},
    );
    final map = result ?? <dynamic, dynamic>{};
    final tokenIds = (map['tokenIds'] as List<dynamic>? ?? <dynamic>[])
        .map((value) => value as int)
        .toList();
    return TranslationResult(
      text: (map['text'] as String?) ?? '',
      tokenIds: tokenIds,
    );
  }

  static Future<void> cancel() async {
    try {
      await _channel.invokeMethod('cancel');
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> getModelStatus() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getModelStatus');
      return res?.cast<String, dynamic>() ?? {};
    } catch (_) {
      return {};
    }
  }
}

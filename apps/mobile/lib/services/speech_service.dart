import 'dart:async';
import 'package:flutter/services.dart';

class SpeechService {
  static const MethodChannel _channel = MethodChannel('anuvaad/speech');
  static const EventChannel _eventChannel = EventChannel('anuvaad/speech_events');

  static Stream<Map<String, dynamic>>? _eventStream;

  /// Stream of native speech events (ASR partial/final results, RMS, errors, download progress).
  static Stream<Map<String, dynamic>> get speechEvents {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((dynamic event) => (event as Map<dynamic, dynamic>).cast<String, dynamic>());
    return _eventStream!;
  }

  // --- Speech Synthesis (TTS) ---

  static Future<bool> speak(String text, {String lang = 'sat_Olck'}) async {
    try {
      final res = await _channel.invokeMethod<bool>('speak', {
        'text': text,
        'lang': lang,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }

  static Future<bool> isSpeaking() async {
    try {
      final res = await _channel.invokeMethod<bool>('isSpeaking');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getStatus');
      return res?.cast<String, dynamic>() ?? {};
    } catch (_) {
      return {};
    }
  }

  // --- Speech Recognition (ASR) ---

  /// Retrieves comprehensive Android speech diagnostic details.
  static Future<Map<String, dynamic>> getSpeechDiagnostics({String locale = 'hi-IN'}) async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getSpeechDiagnostics',
        {'locale': locale},
      );
      return res?.cast<String, dynamic>() ?? {};
    } catch (e) {
      return {'error': e.toString(), 'is_recognition_available': false};
    }
  }

  /// Queries Android 13+ RecognitionSupport API for installed vs downloadable models.
  static Future<Map<String, dynamic>> checkRecognitionSupport({String locale = 'hi-IN'}) async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'checkRecognitionSupport',
        {'locale': locale},
      );
      return res?.cast<String, dynamic>() ?? {
        'success': false,
        'is_installed': false,
        'is_supported': false,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'success': false,
        'is_installed': false,
        'is_supported': false,
      };
    }
  }

  /// Triggers automated background download of offline language model on Android 13+.
  static Future<bool> triggerModelDownload({String locale = 'hi-IN'}) async {
    try {
      final res = await _channel.invokeMethod<bool>(
        'triggerModelDownload',
        {'locale': locale},
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android system voice typing / speech recognition settings to manage offline models.
  static Future<bool> openSpeechSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openSpeechSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Begins listening with on-device speech recognition.
  static Future<bool> startListening({
    String locale = 'hi-IN',
    bool preferOffline = true,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('startListening', {
        'locale': locale,
        'preferOffline': preferOffline,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Stops recording and delivers final recognition result.
  static Future<bool> stopListening() async {
    try {
      final res = await _channel.invokeMethod<bool>('stopListening');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Cancels active speech recognition session.
  static Future<bool> cancelListening() async {
    try {
      final res = await _channel.invokeMethod<bool>('cancelListening');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}

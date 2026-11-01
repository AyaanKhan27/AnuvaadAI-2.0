import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anuvaadai/services/speech_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('anuvaad/speech');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'speak':
          return true;
        case 'stop':
          return null;
        case 'isSpeaking':
          return false;
        case 'getStatus':
          return <String, dynamic>{
            'santali_vits_ready': true,
            'hindi_tts_ready': true,
            'english_tts_ready': true,
            'asr_diagnostics': <String, dynamic>{
              'api_level': 33,
              'is_recognition_available': true,
              'is_on_device_available': true,
              'preferred_service': 'com.google.android.tts/GoogleTTSRecognitionService',
            },
          };
        case 'getSpeechDiagnostics':
          return <String, dynamic>{
            'api_level': 33,
            'is_recognition_available': true,
            'is_on_device_available': true,
            'preferred_service': 'com.google.android.tts/GoogleTTSRecognitionService',
            'installed_services_count': 2,
            'target_locale': methodCall.arguments['locale'],
          };
        case 'checkRecognitionSupport':
          return <String, dynamic>{
            'success': true,
            'api_supported': true,
            'locale': methodCall.arguments['locale'],
            'is_installed': methodCall.arguments['locale'] == 'hi-IN',
            'is_supported': true,
            'installed_languages': <String>['hi-IN', 'en-IN'],
            'supported_languages': <String>['hi-IN', 'en-IN', 'en-US'],
          };
        case 'triggerModelDownload':
          return true;
        case 'openSpeechSettings':
          return true;
        case 'startListening':
          return true;
        case 'stopListening':
          return true;
        case 'cancelListening':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('SpeechService invokes speak and stop correctly', () async {
    final ok = await SpeechService.speak('ᱚᱞ ᱪᱤᱠᱤ', lang: 'sat_Olck');
    expect(ok, isTrue);
    expect(log.any((call) => call.method == 'speak' && call.arguments['text'] == 'ᱚᱞ ᱪᱤᱠᱤ'), isTrue);

    await SpeechService.stop();
    expect(log.any((call) => call.method == 'stop'), isTrue);
  });

  test('SpeechService queries speech diagnostics with locale', () async {
    final diag = await SpeechService.getSpeechDiagnostics(locale: 'hi-IN');
    expect(diag['api_level'], equals(33));
    expect(diag['is_recognition_available'], isTrue);
    expect(diag['preferred_service'], contains('com.google.android.tts'));
    expect(log.any((call) => call.method == 'getSpeechDiagnostics' && call.arguments['locale'] == 'hi-IN'), isTrue);
  });

  test('SpeechService checks recognition support on Android 13+', () async {
    final support = await SpeechService.checkRecognitionSupport(locale: 'hi-IN');
    expect(support['success'], isTrue);
    expect(support['is_installed'], isTrue);
    expect(support['installed_languages'], contains('hi-IN'));
  });

  test('SpeechService triggers model download and opens settings', () async {
    final downloadOk = await SpeechService.triggerModelDownload(locale: 'hi-IN');
    expect(downloadOk, isTrue);
    expect(log.any((call) => call.method == 'triggerModelDownload'), isTrue);

    final settingsOk = await SpeechService.openSpeechSettings();
    expect(settingsOk, isTrue);
    expect(log.any((call) => call.method == 'openSpeechSettings'), isTrue);
  });

  test('SpeechService startListening passes preferOffline flag and locale', () async {
    final started = await SpeechService.startListening(locale: 'hi-IN', preferOffline: true);
    expect(started, isTrue);
    expect(log.any((call) => call.method == 'startListening' && call.arguments['preferOffline'] == true), isTrue);

    await SpeechService.stopListening();
    expect(log.any((call) => call.method == 'stopListening'), isTrue);
  });
}

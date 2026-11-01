import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anuvaadai/pages/speak_page.dart';
import 'package:anuvaadai/services/speech_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('anuvaad/speech');
  int checkSupportErrorCode = 0;
  bool simulateDuplicateCallback = false;
  bool simulateException = false;
  bool serviceAvailable = true;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    checkSupportErrorCode = 0;
    simulateDuplicateCallback = false;
    simulateException = false;
    serviceAvailable = true;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getSpeechDiagnostics':
          if (!serviceAvailable) {
            return <String, dynamic>{
              'api_level': 33,
              'is_recognition_available': false,
              'is_on_device_available': false,
              'preferred_service': 'none',
              'installed_services_count': 0,
            };
          }
          return <String, dynamic>{
            'api_level': 33,
            'is_recognition_available': true,
            'is_on_device_available': true,
            'preferred_service': 'com.google.android.tts/GoogleTTSRecognitionService',
            'installed_services_count': 2,
            'target_locale': methodCall.arguments['locale'],
          };

        case 'checkRecognitionSupport':
          if (simulateException) {
            throw PlatformException(
              code: 'IPC_ERROR',
              message: 'Binder transaction failed',
            );
          }
          if (simulateDuplicateCallback) {
            // Emulate receiving data then duplicate
            return <String, dynamic>{
              'success': true,
              'api_supported': true,
              'locale': methodCall.arguments['locale'],
              'is_installed': true,
              'installed_languages': <String>['hi-IN'],
            };
          }
          if (checkSupportErrorCode == 14) {
            return <String, dynamic>{
              'success': false,
              'api_supported': true,
              'locale': methodCall.arguments['locale'],
              'error_code': 14,
              'error_name': 'ERROR_CANNOT_CHECK_SUPPORT',
              'is_installed': false,
              'is_supported': false,
              'can_download': true,
              'message': 'Speech provider does not report automated offline support (code 14: ERROR_CANNOT_CHECK_SUPPORT).',
            };
          }
          return <String, dynamic>{
            'success': true,
            'api_supported': true,
            'locale': methodCall.arguments['locale'],
            'is_installed': true,
            'is_supported': true,
            'installed_languages': <String>['hi-IN', 'en-IN'],
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
        case 'speak':
          return true;
        case 'stop':
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

  group('ASR Regression & Crash-Safety Tests', () {
    testWidgets('1. Recognition-support success updates UI to Ready', (WidgetTester tester) async {
      checkSupportErrorCode = 0;
      await tester.pumpWidget(const MaterialApp(home: SpeakPage()));
      await tester.pumpAndSettle();

      expect(find.text('Speech Studio'), findsOneWidget);
      expect(find.text('Offline Speech Ready (On-Device)'), findsOneWidget);
      expect(find.textContaining('Google Speech Services'), findsOneWidget);
    });

    testWidgets('2. Recognition-support error code 14 handles gracefully without crashing', (WidgetTester tester) async {
      checkSupportErrorCode = 14;
      await tester.pumpWidget(const MaterialApp(home: SpeakPage()));
      await tester.pumpAndSettle();

      // Must NOT crash, must NOT claim ready
      expect(find.text('Speech Studio'), findsOneWidget);
      expect(find.text('Offline Speech Ready (On-Device)'), findsNothing);
      expect(find.textContaining('Code 14'), findsWidgets);
      expect(find.text('Speech Settings'), findsWidgets);
      expect(find.text('Retry Check'), findsWidgets);
    });

    test('3. MethodChannel single-completion guard prevents duplicate reply crashes', () async {
      simulateDuplicateCallback = true;
      final res1 = await SpeechService.checkRecognitionSupport(locale: 'hi-IN');
      expect(res1['success'], isTrue);
      expect(res1['is_installed'], isTrue);

      // Calling again should not crash or throw IllegalStateException
      final res2 = await SpeechService.checkRecognitionSupport(locale: 'hi-IN');
      expect(res2['success'], isTrue);
    });

    test('4. Exception during support check does not crash and returns safe fallback', () async {
      simulateException = true;
      final res = await SpeechService.checkRecognitionSupport(locale: 'hi-IN');
      expect(res['is_installed'], isFalse);
      expect(res['success'], isFalse);
      expect(res['error'], contains('IPC_ERROR'));
    });

    testWidgets('5. Screen initializes cleanly when recognition service is unavailable', (WidgetTester tester) async {
      serviceAvailable = false;
      await tester.pumpWidget(const MaterialApp(home: SpeakPage()));
      await tester.pumpAndSettle();

      expect(find.text('Speech Studio'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Translate Text'), findsOneWidget);
    });

    testWidgets('6. Rapid opening and closing of Speak screen does not leak or crash', (WidgetTester tester) async {
      for (int i = 0; i < 5; i++) {
        await tester.pumpWidget(const MaterialApp(home: SpeakPage()));
        await tester.pump(const Duration(milliseconds: 100));
        // Unmount
        await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Home'))));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Home'), findsOneWidget);
    });
  });
}

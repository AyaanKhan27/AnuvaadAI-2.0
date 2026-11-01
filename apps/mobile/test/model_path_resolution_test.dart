import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anuvaadai/services/translation_directions.dart';
import 'package:anuvaadai/services/translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Model Path Resolution & Error Classification Tests', () {
    test('1. Validates all 6 supported translation directions', () {
      expect(TranslationDirections.isSupported('hin_Deva', 'sat_Olck'), isTrue);
      expect(TranslationDirections.isSupported('sat_Olck', 'hin_Deva'), isTrue);
      expect(TranslationDirections.isSupported('eng_Latn', 'sat_Olck'), isTrue);
      expect(TranslationDirections.isSupported('eng_Latn', 'hin_Deva'), isTrue);
      expect(TranslationDirections.isSupported('sat_Olck', 'eng_Latn'), isTrue);
      expect(TranslationDirections.isSupported('hin_Deva', 'eng_Latn'), isTrue);

      expect(TranslationDirections.isSupported('fra_Latn', 'sat_Olck'), isFalse);
      expect(TranslationDirections.isSupported('spa_Latn', 'hin_Deva'), isFalse);
    });

    test('2. requireSupported passes for all 6 directions and throws for unsupported directions', () {
      expect(
        () => TranslationDirections.requireSupported('sat_Olck', 'eng_Latn'),
        returnsNormally,
      );
      expect(
        () => TranslationDirections.requireSupported('hin_Deva', 'eng_Latn'),
        returnsNormally,
      );
      expect(
        () => TranslationDirections.requireSupported('fra_Latn', 'sat_Olck'),
        throwsA(isA<PlatformException>()),
      );
      expect(
        () => TranslationDirections.requireSupported('spa_Latn', 'hin_Deva'),
        throwsA(isA<PlatformException>()),
      );
    });

    test('3. Handles MODEL_MISSING PlatformException cleanly', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('anuvaad/translation'),
              (MethodCall methodCall) async {
        if (methodCall.method == 'translate') {
          throw PlatformException(
            code: 'IllegalStateException',
            message:
                "model_missing: Required file 'encoder.onnx' not found in /storage/emulated/0/Android/data/org.anuvaad.ai.anuvaadai/files/models.",
          );
        }
        return null;
      });

      try {
        await TranslationService.translate('नमस्ते',
            srcLang: 'hin_Deva', tgtLang: 'sat_Olck');
        fail('Should have thrown PlatformException');
      } on PlatformException catch (e) {
        expect(e.message, contains('model_missing'));
        expect(e.message, contains('encoder.onnx'));
      }
    });

    test('4. Handles MODEL_NOT_READABLE PlatformException cleanly', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('anuvaad/translation'),
              (MethodCall methodCall) async {
        if (methodCall.method == 'translate') {
          throw PlatformException(
            code: 'IllegalStateException',
            message:
                "model_not_readable: IndicTrans2 Indic-to-Indic directory is not readable/traversable (canRead=false, canExecute=false): /sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/models",
          );
        }
        return null;
      });

      try {
        await TranslationService.translate('नमस्ते',
            srcLang: 'hin_Deva', tgtLang: 'sat_Olck');
        fail('Should have thrown PlatformException');
      } on PlatformException catch (e) {
        expect(e.message, contains('model_not_readable'));
        expect(e.message, contains('not readable/traversable'));
      }
    });

    test('5. Handles MODEL_INVALID PlatformException cleanly', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('anuvaad/translation'),
              (MethodCall methodCall) async {
        if (methodCall.method == 'translate') {
          throw PlatformException(
            code: 'IllegalStateException',
            message:
                "model_invalid: File 'encoder.onnx' in /sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/models is 0 bytes (corrupt or incomplete transfer).",
          );
        }
        return null;
      });

      try {
        await TranslationService.translate('नमस्ते',
            srcLang: 'hin_Deva', tgtLang: 'sat_Olck');
        fail('Should have thrown PlatformException');
      } on PlatformException catch (e) {
        expect(e.message, contains('model_invalid'));
        expect(e.message, contains('0 bytes'));
      }
    });

    test('6. Handles ONNX_INITIALIZATION_FAILED PlatformException cleanly', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('anuvaad/translation'),
              (MethodCall methodCall) async {
        if (methodCall.method == 'translate') {
          throw PlatformException(
            code: 'IllegalStateException',
            message:
                "onnx_initialization_failed: Failed to load Indic ONNX session: Missing external data file",
          );
        }
        return null;
      });

      try {
        await TranslationService.translate('नमस्ते',
            srcLang: 'hin_Deva', tgtLang: 'sat_Olck');
        fail('Should have thrown PlatformException');
      } on PlatformException catch (e) {
        expect(e.message, contains('onnx_initialization_failed'));
        expect(e.message, contains('Failed to load Indic ONNX session'));
      }
    });
  });
}

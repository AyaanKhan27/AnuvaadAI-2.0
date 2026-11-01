import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anuvaadai/data/speech_config_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SpeechConfigStore Tests', () {
    test('Default selected language is hi-IN', () async {
      final lang = await SpeechConfigStore.getSelectedLanguage();
      expect(lang, 'hi-IN');
    });

    test('Persist and retrieve selected language', () async {
      await SpeechConfigStore.setSelectedLanguage('en-IN');
      final lang = await SpeechConfigStore.getSelectedLanguage();
      expect(lang, 'en-IN');
    });

    test('4-State Readiness Architecture: Acknowledged setup does NOT falsely report verified offline ready', () async {
      // 1. Initial unverified state on Code 14
      expect(await SpeechConfigStore.isAcknowledgedUnverified('hi-IN'), isFalse);
      var state = await SpeechConfigStore.getReadinessState(
        locale: 'hi-IN',
        nativeReportedInstalled: false,
        supportErrorCode: 14,
      );
      expect(state, SpeechReadinessState.capabilityUnverified);
      expect(await SpeechConfigStore.isOfflineReady(locale: 'hi-IN', nativeReportedInstalled: false), isFalse);

      // 2. User acknowledges setup in settings
      await SpeechConfigStore.setAcknowledgedUnverified('hi-IN', true);
      expect(await SpeechConfigStore.isAcknowledgedUnverified('hi-IN'), isTrue);

      state = await SpeechConfigStore.getReadinessState(
        locale: 'hi-IN',
        nativeReportedInstalled: false,
        supportErrorCode: 14,
      );
      expect(state, SpeechReadinessState.setupAcknowledged);
      // Genuine check: must NOT falsely report verified offline ready without test!
      expect(await SpeechConfigStore.isOfflineReady(locale: 'hi-IN', nativeReportedInstalled: false), isFalse);

      // 3. Live speech test passes -> transitions to offlineTested
      await SpeechConfigStore.recordTestPassed('hi-IN');
      state = await SpeechConfigStore.getReadinessState(
        locale: 'hi-IN',
        nativeReportedInstalled: false,
        supportErrorCode: 14,
      );
      expect(state, SpeechReadinessState.offlineTested);
      expect(await SpeechConfigStore.isOfflineReady(locale: 'hi-IN', nativeReportedInstalled: false), isTrue);

      // 4. Unavailable state when not installed and no Code 14
      state = await SpeechConfigStore.getReadinessState(
        locale: 'en-US',
        nativeReportedInstalled: false,
        supportErrorCode: 0,
      );
      expect(state, SpeechReadinessState.unavailable);
    });

    test('Recording passed test persists timestamp and confirms setup', () async {
      expect(await SpeechConfigStore.isTestPassed('hi-IN'), isFalse);
      expect(await SpeechConfigStore.getLastTestTimestamp('hi-IN'), isNull);

      await SpeechConfigStore.recordTestPassed('hi-IN');

      expect(await SpeechConfigStore.isTestPassed('hi-IN'), isTrue);
      expect(await SpeechConfigStore.isAcknowledgedUnverified('hi-IN'), isTrue);
      final timestamp = await SpeechConfigStore.getLastTestTimestamp('hi-IN');
      expect(timestamp, isNotNull);
      expect(timestamp! > 0, isTrue);

      expect(
        await SpeechConfigStore.isOfflineReady(locale: 'hi-IN', nativeReportedInstalled: false),
        isTrue,
      );
    });

    test('Resetting locale clears flags and timestamps', () async {
      await SpeechConfigStore.recordTestPassed('hi-IN');
      expect(await SpeechConfigStore.isTestPassed('hi-IN'), isTrue);

      await SpeechConfigStore.resetLocale('hi-IN');
      expect(await SpeechConfigStore.isTestPassed('hi-IN'), isFalse);
      expect(await SpeechConfigStore.isAcknowledgedUnverified('hi-IN'), isFalse);
      expect(await SpeechConfigStore.getLastTestTimestamp('hi-IN'), isNull);
    });
  });
}

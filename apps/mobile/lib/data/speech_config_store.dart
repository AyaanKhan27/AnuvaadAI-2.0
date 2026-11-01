import 'package:shared_preferences/shared_preferences.dart';

/// Distinct operational states for speech recognition readiness.
enum SpeechReadinessState {
  /// Offline speech recognition has genuinely been verified on-device (via native API or airplane-mode test).
  offlineTested,

  /// User completed manual setup in Speech Settings, but airplane-mode offline test is pending.
  setupAcknowledged,

  /// Provider returned Code 14 (ERROR_CANNOT_CHECK_SUPPORT) and setup is not yet acknowledged.
  capabilityUnverified,

  /// Offline speech recognition is unavailable or language pack missing.
  unavailable,
}

/// Persistent configuration store for Speech Recognition (ASR) & Text-to-Speech (TTS).
///
/// Ensures truthful readiness reporting:
/// - Setup acknowledged is strictly separate from offline tested.
/// - Online speech recognition does NOT falsely register as offline-ready.
/// - Only genuine on-device verification (native check or airplane-mode test) marks offlineTested.
/// - Download prompts are never repeatedly shown once setup is acknowledged.
class SpeechConfigStore {
  static const String _keySelectedLang = 'anuvaad_speech_selected_lang';
  static const String _keySetupCompleted = 'anuvaad_speech_setup_completed';
  static const String _prefixAckUnverified = 'anuvaad_speech_ack_unverified_';
  static const String _prefixOfflineVerified = 'anuvaad_speech_offline_verified_';
  static const String _prefixLastTestTime = 'anuvaad_speech_test_time_';

  /// Returns the saved selected language, defaulting to Hindi ('hi-IN').
  static Future<String> getSelectedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedLang) ?? 'hi-IN';
  }

  /// Persists the user's active speech language.
  static Future<void> setSelectedLanguage(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedLang, locale);
  }

  /// Whether the initial speech setup guide has been completed.
  static Future<bool> isSetupCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySetupCompleted) ?? false;
  }

  /// Marks setup guide as completed.
  static Future<void> setSetupCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySetupCompleted, completed);
  }

  /// Whether the user has acknowledged that this locale is manually configured in settings.
  static Future<bool> isAcknowledgedUnverified(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefixAckUnverified$locale') ?? false;
  }

  /// Saves the user's acknowledgement for a given locale.
  static Future<void> setAcknowledgedUnverified(String locale, bool acknowledged) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefixAckUnverified$locale', acknowledged);
  }

  /// Whether genuine offline recognition has been verified for this locale (e.g. tested in Airplane mode).
  static Future<bool> isOfflineVerified(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefixOfflineVerified$locale') ?? false;
  }

  /// Sets genuine offline verification status (e.g. after successful airplane-mode test).
  static Future<void> setOfflineVerified(String locale, bool verified) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefixOfflineVerified$locale', verified);
    if (verified) {
      await prefs.setBool('$_prefixAckUnverified$locale', true);
      await prefs.setInt('$_prefixLastTestTime$locale', DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Records a successful live offline recognition test (e.g. verified in airplane mode).
  static Future<void> recordOfflineTestPassed(String locale) async {
    await setOfflineVerified(locale, true);
  }

  /// Compatibility alias for testing.
  static Future<bool> isTestPassed(String locale) async {
    return await isOfflineVerified(locale);
  }

  /// Compatibility alias for recording offline test.
  static Future<void> recordTestPassed(String locale) async {
    await setOfflineVerified(locale, true);
  }

  /// Returns the timestamp (milliseconds since epoch) of the verified test.
  static Future<int?> getLastTestTimestamp(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefixLastTestTime$locale');
  }

  /// Computes the exact distinct readiness state for the given locale.
  static Future<SpeechReadinessState> getReadinessState({
    required String locale,
    required bool nativeReportedInstalled,
    required int? supportErrorCode,
  }) async {
    if (nativeReportedInstalled) {
      return SpeechReadinessState.offlineTested;
    }
    final verifiedOffline = await isOfflineVerified(locale);
    if (verifiedOffline) {
      return SpeechReadinessState.offlineTested;
    }
    final ack = await isAcknowledgedUnverified(locale);
    if (ack) {
      return SpeechReadinessState.setupAcknowledged;
    }
    if (supportErrorCode == 14) {
      return SpeechReadinessState.capabilityUnverified;
    }
    return SpeechReadinessState.unavailable;
  }

  /// Returns true ONLY if offline recognition is genuinely verified:
  /// either natively reported as installed or genuine offline/airplane-mode test has passed.
  static Future<bool> isOfflineReady({
    required String locale,
    required bool nativeReportedInstalled,
  }) async {
    if (nativeReportedInstalled) return true;
    return await isOfflineVerified(locale);
  }

  /// Clears persisted status for a given locale.
  static Future<void> resetLocale(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefixAckUnverified$locale');
    await prefs.remove('$_prefixOfflineVerified$locale');
    await prefs.remove('$_prefixLastTestTime$locale');
  }

  /// Resets all speech configuration data.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('anuvaad_speech_'));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}

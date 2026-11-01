# AnuvaadAI 2.0 - Development Progress

## Milestone 1: Initial Discovery & Environment Audit
- **Status:** COMPLETED
- Flutter SDK 3.41.4, OpenJDK 17 LTS, Android SDK 36 verified.
- Existing assets in `C:\AnuvaadAI2` audited and validated (`anuvaad-models`, `en-indic-models`, test scripts).

## Milestone 2: Master Project Structure & Clean Migration
- **Status:** COMPLETED
- Established clean architecture directly inside `C:\AnuvaadAI Anti\`.
- Structured workspaces: `apps/mobile`, `engines/`, `packages/`, `model_manifest/`, `docs/`, `scripts/`, `tests/`, `release/`.
- Zero Git contamination, zero modification to original reference directories.

## Milestone 3: Model Manifest & Provenance Verification
- **Status:** COMPLETED
- `model_manifest/models.json` populated with exact SHA256 checksums, byte sizes, and provenance for Indic-Indic and English-to-Indic IndicTrans2 ONNX models.
- Identified and provisioned native Santali VITS ONNX model (`santali_piper_vits.onnx`, 63.5 MB) from AI4Bharat Rasa corpus checkpoint.

## Milestone 4: Native Android Translation & Speech Engine Implementation
- **Status:** COMPLETED
- Upgraded `TranslationEngine.kt`:
  - Added native support for `eng_Latn -> hin_Deva` alongside `eng_Latn -> sat_Olck`, `hin_Deva -> sat_Olck`, and `sat_Olck -> hin_Deva`.
  - Fixed encoder output layer mapping (`last_hidden_state` for En-Indic).
  - Implemented dynamic session loading and memory management for low-RAM devices.
- Created `SantaliPhonemizer.kt`:
  - Pure Kotlin Ol Chiki unicode to atomic IPA phoneme converter without third-party dependencies.
- Created `SantaliTtsEngine.kt`:
  - Neural VITS acoustic synthesizer executing on mobile CPU in ~100 ms and streaming 22,050 Hz 16-bit PCM audio via `AudioTrack`.
- Created `SpeechManager.kt`:
  - Unified platform manager orchestrating Santali VITS, Hindi TextToSpeech, and English TextToSpeech.
- Updated `MainActivity.kt` with dual platform channels: `anuvaad/translation` and `anuvaad/speech`.

## Milestone 5: Flutter 10-Screen Educational Application Architecture
- **Status:** COMPLETED
- Complete suite of 10 educational screens implemented:
  1. `HomePage`: Central responsive hub for all studios.
  2. `TranslatePage`: Full 4-direction neural translation studio with swap, history recording, copy, and offline TTS.
  3. `SpeakPage`: Offline speech recognition studio for Hindi and English, plus native Santali audio playback.
  4. `OcrPage`: Offline camera & gallery text recognition for Devanagari and Latin scripts.
  5. `DocumentsPage`: Offline document extraction studio supporting PDF, Word (DOCX), and TXT.
  6. `SavedLessonsPage`: Interactive lesson library with local SQLite/SharedPreferences persistence.
  7. `SavedLessonDetailPage`: Lesson inspection, editing, and bi-directional audio playback.
  8. `HistoryPage`: Offline audit log of recent translations with quick replay and copy.
  9. `SettingsPage`: Detailed architecture verification and system preferences.
  10. `ModelStatusPage`: Live diagnostic studio checking availability of on-device neural weights.

## Milestone 6: Automated Testing & Verification
- **Status:** COMPLETED
- Flutter unit and widget tests: 11 / 11 passed (100% pass rate).
- Translation ONNX benchmarks: Validated English -> Santali (1.09s), English -> Hindi (0.82s).
- Native Santali VITS TTS benchmarks: Validated 103 ms acoustic synthesis latency.
- Audio test artifact generated at `tests/fixtures/santali_speech_test.wav`.

## Milestone 7: Final Release APK Generation & Delivery
- **Status:** COMPLETED
- Release APK built successfully: `C:\AnuvaadAI Anti\release\AnuvaadAI-2.0.apk` (185.5 MB).
- SHA256 checksum: `3fce5a6515e6f2a35136f5ec018ed40f28b0d022bcac253c381cc309c32566f3`.
- Release report generated: `C:\AnuvaadAI Anti\release\BUILD_REPORT.md`.


## Milestone 8: Physical Device ASR Investigation, Native Engine & Release Fix
- **Status:** COMPLETED
- Investigated physical-device ASR failure on Realme Narzo N55 (Android 13).
- Identified root cause: `speech_to_text: ^7.4.0` unconditionally invoked `createOnDeviceSpeechRecognizer` on API 31+, causing immediate `ERROR_LANGUAGE_UNAVAILABLE` (13) before microphone initialization when offline language packs were not pre-installed in Google Speech Services. Missing Android 11+ `<queries>` in manifest also blocked service visibility.
- Implemented native `AsrManager.kt` in Kotlin:
  - Specific component binding targeting `com.google.android.tts/GoogleTTSRecognitionService`.
  - Implemented Android 13+ `SpeechRecognizer.checkRecognitionSupport()` to inspect installed vs downloadable languages.
  - Implemented Android 13/14+ `SpeechRecognizer.triggerModelDownload()` for in-app offline model downloads.
  - Implemented system settings deep-linking (`openSpeechSettings()`).
  - Added real-time audio volume visualizer (`rms`) and streaming partial transcription.
- Added package visibility declarations in `AndroidManifest.xml`.
- Replaced `speech_to_text` dependency in Flutter with unified `SpeechService.dart`.
- Enhanced `SpeakPage.dart` with offline capability badges, download buttons, audio ripples, and diagnostic modal.
- Added ASR status tiles in `ModelStatusPage.dart`.
- Automated tests: 16 / 16 passed (100% success rate). Static analysis: 0 issues.
- Updated release APK generated: `release/AnuvaadAI-2.0.apk` (185.6 MB, SHA256: `8087C9B443244EDF3A23D7FDE076E83A1E5B61716598B0DF6E6399440E33BFD6`).
- Full report generated: `release/ASR_INVESTIGATION_AND_FIX_REPORT.md`.


## Milestone 9: Speak Screen Crash Repair (MethodChannel Single-Completion Guard & Error Code 14)
- **Status:** COMPLETED
- Addressed physical device crash log from Realme Narzo N55: `java.lang.IllegalStateException: Reply already submitted` triggered when asynchronous recognition support check fired error code 14 (`ERROR_CANNOT_CHECK_SUPPORT`).
- Implemented `SafeResult` wrapper with thread-safe `AtomicBoolean` guard in `MainActivity.kt`, mathematically guaranteeing single-use completion across all platform channels.
- Hardened `AsrManager.kt`:
  - Added single-completion guard (`AtomicBoolean`) and 3500ms timeout watchdog in `checkRecognitionSupport()`.
  - Converted `ERROR_CANNOT_CHECK_SUPPORT` (code 14) into a structured, non-fatal diagnostic response.
  - Deferred `SpeechRecognizer.destroy()` using delayed handler dispatch to prevent binder connection races.
- Hardened `SpeakPage.dart`:
  - Added monotonic sequence token (`_refreshSeq`) preventing stale async channel updates upon language switching or unmounting.
  - Handled Code 14 non-fatally with clear UI notice and action buttons ("Speech Settings" and "Retry Check").
  - Guaranteed `is_installed: false` when support cannot be queried, preventing false claims of offline readiness.
- Regression testing: Created `apps/mobile/test/asr_regression_test.dart` (6/6 tests passed). Total Flutter tests: 22 / 22 passed. Static analysis: 0 issues.
- Updated release APK generated: `release/AnuvaadAI-2.0.apk` (185.7 MB, SHA-256: `A71CCDB28E24B5638945D1A183871A614C3E8217997BAEB4F9B5EF1AE5946E19`).

## Milestone 10: Final Master Directive — Real-Time Teacher Mode, Speech Persistence & Model Provisioning
- **Status:** COMPLETED
- **Priority 1 (Translation Model Missing Fix):**
  - Upgraded `TranslationEngine.kt`: Dynamic candidate directory resolution across primary external storage, persistent `/sdcard/anuvaad-models/`, and internal storage.
  - Replaced synchronous 2GB SHA-256 calculation with fast file presence and non-zero size verification. Caches verification state (`modelsVerified = true`).
  - Upgraded `SantaliTtsEngine.kt`: Added dynamic candidate path discovery for `santali-tts` directory.
- **Priority 2 (Speech Model Persistence):**
  - Implemented `SpeechConfigStore` using `SharedPreferences`: Persists selected language, setup completed flag, manual acknowledgement, and test passed timestamp.
  - Upgraded `SpeakPage.dart`: Loads persisted configuration on startup; suppresses Error 14 download nagging when verified or tested; added "Mark as Verified" button.
  - Added unit test suite `apps/mobile/test/speech_config_store_test.dart` (5/5 tests passing).
- **Priority 3 (Complete Model Provisioning System):**
  - Created `scripts/setup/provision_models.ps1`: Automated, idempotent ADB file push utility with storage space pre-checks and skipped redundant uploads.
  - Created `scripts/setup/verify_device_installation.ps1`: Connected physical device validator verifying package, permissions, and on-device models.
  - Created `scripts/setup/verify_model_integrity.ps1`: PC-side validator checking local files, byte sizes, and checksums.
  - Created `scripts/setup/clean_install.ps1`: Fresh deployment script with safety confirmations.
  - Created `scripts/setup/configure_speech.md`: Operator guide for offline Hindi/English speech configuration.
  - Created `MODEL_PROVISIONING_REPORT.md`: Comprehensive model catalog and provisioning report.
- **Priority 4 (Real-Time Teacher Communication Mode):**
  - Created `apps/mobile/lib/pages/teacher_communication_page.dart`: Autonomous loop capturing continuous Hindi teacher speech -> IndicTrans2 translation (`hin_Deva` -> `sat_Olck`) -> Santali Piper VITS neural synthesis -> automated acoustic feedback prevention -> lesson save.
  - Added `_TeacherBridgeHero` prominent card on `home_page.dart`.
  - Added unit/widget test `apps/mobile/test/teacher_communication_test.dart` (passing).
- **Priority 5 (Preservation of Existing Features):**
  - Verified all 4 core translation directions, native Santali VITS TTS, OCR scanner, documents parser, saved lessons, and history store.
- **Priority 6 (Automated Regression Testing):**
  - All 28 tests passing in Flutter test suite (100% pass rate). Static analysis: 0 issues.
- **Priority 7 (Final Production Deliverable):**
  - Production Release APK compiled to `release/AnuvaadAI-2.0.apk` (185.87 MB, 194,898,411 bytes, SHA-256: `2ae84ecdbaf3ffedcd973ae4b102d348e304ea4adb28f2384312040113f0721a`).
  - Created `CLEAN_INSTALL_GUIDE.md`, `SPEECH_PERSISTENCE_REPORT.md`, `TEACHER_COMMUNICATION_IMPLEMENTATION.md`, `KNOWN_LIMITATIONS.md`, and `FINAL_BUILD_REPORT.md`.

## Milestone 11: Final Pre-Installation Audit & Device Verification Hardening
- **Status:** COMPLETED
- **On-Device Cryptographic SHA-256 Verification:**
  - Upgraded `scripts/setup/provision_models.ps1` to calculate destination SHA-256 directly on Android using toybox `sha256sum`.
  - Compares against local reference manifest with individual `[PASS]` / `[FAIL]` reporting for all 19 model files.
  - Added temporary PC pull fallback if device lacks `sha256sum`, with automatic temp cleanup.
  - Aborts immediately on any checksum mismatch.
- **Genuine Offline Speech Verification Architecture:**
  - Decoupled `setupAcknowledged` from `offlineTested` in `SpeechConfigStore.dart`.
  - Implemented 4-state readiness model: `offlineTested`, `setupAcknowledged`, `capabilityUnverified`, `unavailable`.
  - Added explicit Airplane Mode verification workflow in `speak_page.dart` with dedicated *"Confirm Verified in Airplane Mode"* action.
  - Prevents online speech recognition tests from falsely advertising offline capability.
- **Scoped Clean Installation:**
  - Refined `scripts/setup/clean_install.ps1` to remove strictly `/sdcard/anuvaad-models` and `/sdcard/Android/data/org.anuvaad.ai.anuvaadai`.
  - Fully isolates clean installation from unrelated device directories.
- **Target SDK Documentation Alignment:**
  - Confirmed and documented API 36 as Android 16 (Android Baklava).
## Milestone 12: Application-Side Model Discovery & Granular Error Architecture
- **Status:** COMPLETED
- **Physical Device Root Cause Discovery:**
  - On OPPO CPH2793IN (Android 16), ADB shell created `/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/models` with ownership `shell:ext_data_rw` and permissions `drwxrws---` (770).
  - Unprivileged application process (`u0_a421`) lacked read/execute permissions on `models/`, causing Linux `stat()` to return `EACCES` (Permission Denied).
  - Kotlin `java.io.File.exists()` returned `false` on `EACCES`, which the legacy resolver misattributed as "file missing" (`model_missing: Required file 'encoder.onnx' not found...`) even though the file existed on disk with 479,185,079 bytes and valid SHA-256 (`c7bb33c8...`).
- **Authoritative Model Path Resolver:**
  - Implemented `ModelPathResolver.kt`: Single authoritative dynamic resolver using Android Context APIs (`getExternalFilesDir(null)`, `filesDir`).
  - Added granular error classification: `MODEL_MISSING`, `MODEL_NOT_READABLE`, `MODEL_INVALID`, `ONNX_INITIALIZATION_FAILED`.
  - Added self-healing permission checks (`setReadable`, `setExecutable`) and deep diagnostic logging.
  - Unified model root between `TranslationEngine` and `IndicTokenizer`.
  - Updated `SantaliTtsEngine` and `getModelStatus` to use `ModelPathResolver`.
- **Provisioning Permission Hardening:**
  - Updated `scripts/setup/provision_models.ps1` to enforce `chmod -R 777` on target directories and files upon creation and post-transfer.
- **Testing & Verification:**
  - Created Kotlin unit test suite `ModelPathResolverTest.kt`.
  - Created Flutter unit regression tests `model_path_resolution_test.dart`. Total Flutter tests: 34 / 34 passed (100%).
  - `flutter analyze`: 0 issues found.
  - Release APK rebuilt and v2 signed: `release/AnuvaadAI-2.0.apk` (185.87 MB, SHA-256: `79918e047f36d94a7b90da945d48c00ae4ceda9205e3a42b85fd5643f3786993`).

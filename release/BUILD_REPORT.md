# AnuvaadAI 2.0 - Release Build Report

## Build Metadata
- **Build Date & Time:** 2026-10-31 14:04:30 IST
- **Target Deliverable:** `C:\AnuvaadAI Anti\release\AnuvaadAI-2.0.apk`
- **Application Package ID:** `org.anuvaad.ai.anuvaadai`
- **Application Version:** `2.0.0` (Build 1)
- **APK Binary Size:** 194,503,771 bytes (185.5 MB)
- **APK SHA-256 Checksum:** `3fce5a6515e6f2a35136f5ec018ed40f28b0d022bcac253c381cc309c32566f3`

## Build Configuration
- **Flutter Framework:** Flutter 3.41.4 (Channel stable)
- **Dart SDK:** Dart 3.11.1
- **Java Runtime:** OpenJDK 17.0.18 LTS (Microsoft Hotspot 64-Bit)
- **Android Gradle Plugin (AGP):** 8.11.1
- **Kotlin Compiler:** 2.2.20
- **Compile SDK:** Android 36 (Baklava / Android 16 preview API)
- **Target SDK:** Android 34 / 36
- **Minimum Supported SDK:** Android 9.0 (API Level 28)
- **Native Runtime Engines:**
  - `com.microsoft.onnxruntime:onnxruntime-android:1.31.0`
  - `com.google.protobuf:protobuf-java:4.32.1`
  - `io.github.eix128:sentencepiece4j:1.0.2`
  - `com.google.mlkit:text-recognition-devanagari:16.0.1`

## Supported Hardware & Devices
- **Primary Physical Target:** Realme Narzo N55 (6 GB RAM, MediaTek Helio G88, Android 13/14)
- **Low-Resource Compatibility Target:** Devices with ~2 GB RAM, Android 9.0+
- **Desktop Runtime Compatibility:** Windows 11 64-bit AMD64

## Implemented & Verified Functionality

### 1. Translation Engine (`anuvaad/translation`)
- **Active Offline Directions:**
  1. `hin_Deva -> sat_Olck` (Hindi Devanagari to Santali Ol Chiki) - **OPERATIONAL**
  2. `sat_Olck -> hin_Deva` (Santali Ol Chiki to Hindi Devanagari) - **OPERATIONAL**
  3. `eng_Latn -> sat_Olck` (English Latin to Santali Ol Chiki) - **OPERATIONAL**
  4. `eng_Latn -> hin_Deva` (English Latin to Hindi Devanagari) - **OPERATIONAL**
- **Autoregressive Past-KV Caching:** Implemented in Kotlin with lazy session loading and memory reclamation to maintain heap footprint below 1.5 GB.
- **Pure Kotlin Tokenizer:** SentencePiece protobuf model parser with dynamic Viterbi segmenter and dual vocabulary mapping without C++ native dependencies.

### 2. Speech Synthesis Engine (`anuvaad/speech`)
- **Native Santali TTS:** Full neural VITS ONNX model (`santali_piper_vits.onnx`, 63.5 MB) paired with custom `SantaliPhonemizer.kt` (converts Ol Chiki text directly to IPA phoneme tokens). Audio synthesized at 22,050 Hz 16-bit PCM and streamed directly through Android `AudioTrack`.
- **Hindi & English Offline TTS:** Native integration via Android `TextToSpeech` using device-installed offline voice packs (`Locale("hi", "IN")` and `Locale.US`).

### 3. Speech Recognition Engine (ASR)
- **Hindi & English Offline Speech Recognition:** On-device listening using Android `SpeechRecognizer` (`localeId: hi_IN` and `en_US` with `onDevice: true`).
- **Santali Voice Input:** Displays research status advisory and provides seamless Ol Chiki text entry with full voice playback and translation routing.

### 4. Vision & OCR Studio
- **Offline ML Kit OCR:** Fully bundled on-device vision engine supporting:
  - Devanagari script for Hindi text extraction from camera and gallery images.
  - Latin script for English worksheets and textbooks.
- **Editable Transcription:** High-contrast editor with quick-translate and read-aloud buttons.

### 5. Document Extraction Engine
- **Supported Offline Formats:**
  - PDF: Offline text operator stream decoder.
  - DOCX: Automated unzipping and XML extraction from `word/document.xml`.
  - TXT: Plain text file parser.
- **Quick-Load Classroom Fixtures:** Built-in Hindi, English, and Santali sample curricula.

### 6. Local Storage & Lesson Management
- **Saved Lessons:** Complete CRUD store persisted on-device (`SavedLessonsStore`).
- **Translation History:** 100-entry audit log of recent translations (`HistoryStore`).
- **Lesson Detail Studio:** Audio playback of source/target, editing, and copying.

## Automated Test Results

| Test Category | Total Tests | Passed | Failed | Status |
|---|---|---|---|---|
| Translation Direction Unit Tests | 5 | 5 | 0 | **PASSED** |
| Document Extraction Unit Tests | 2 | 2 | 0 | **PASSED** |
| Translation History Store Unit Tests | 2 | 2 | 0 | **PASSED** |
| Saved Lessons Store Unit Tests | 1 | 1 | 0 | **PASSED** |
| UI Widget Smoke Tests | 1 | 1 | 0 | **PASSED** |
| **Total Flutter Automated Suite** | **11** | **11** | **0** | **100% PASS** |
| Santali Neural VITS TTS Acoustic Suite | 3 | 3 | 0 | **100% PASS** |
| IndicTrans2 En-Indic ONNX Benchmark Suite | 2 | 2 | 0 | **100% PASS** |

### Benchmark Highlights
- **Santali VITS Synthesis Latency:** 103.1 ms for standard sentence (`ᱦᱮᱞᱳ ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱾`)
- **English -> Santali Translation Latency:** 1.09 s (7 decode steps)
- **English -> Hindi Translation Latency:** 0.82 s (4 decode steps)
- **Hindi <-> Santali Translation Latency:** 0.59 s - 1.63 s

## Offline Validation Results
- Verified with zero active network connections.
- All neural model inference executed on local CPU.
- APK size (185.5 MB) includes complete runtime libraries and vision models.

## Known Limitations & Model Requirements
1. **Reverse Indic-to-English Directions (`hin_Deva -> eng_Latn` and `sat_Olck -> eng_Latn`):**
   - Requires provisioning the companion `hari31416/indictrans2-indic-en-dist-200M-ONNX` checkpoint to the device's external storage folder (`/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/indic-en-models/`). The engine architecture and method channels are built to load it immediately upon deployment.
2. **Model Storage Location:**
   - Indic-Indic translation weights (~2.0 GB) and English-to-Indic weights (~1.4 GB) are provisioned into the app's external files directory on the device via `scripts/setup/provision_models.ps1` to prevent exceeding mobile app package installer size limits.

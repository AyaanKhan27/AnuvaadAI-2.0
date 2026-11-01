# AnuvaadAI 2.0

AnuvaadAI 2.0 is an offline-first multilingual education and translation platform engineered for Android (Android 9.0+ / API 28+, tested through Android 16 / API 36) and Windows environments, tailored for bilingual and multilingual classrooms supporting **Hindi (Devanagari)**, **English (Latin)**, and **Santali (Ol Chiki)**.

---

## Key Features

- **Offline Neural Translation:** On-device IndicTrans2 Transformer Seq2Seq models with past-KV caching supporting:
  - Hindi ↔ Santali (`hin_Deva ↔ sat_Olck`)
  - English ↔ Santali (`eng_Latn ↔ sat_Olck`)
  - Hindi ↔ English (`hin_Deva ↔ eng_Latn`)
- **PDF-to-Santali Document Studio (New in Phase 2):**
  - **Hybrid Layout Preservation:** Mode A (Facsimile Overlay) preserves original visual diagrams, figures, and table coordinates; Mode B (Reflow Reader) optimizes text flow for reading.
  - **Dual Extraction Pipeline:** High-performance digital extraction via PDFBox-Android combined with on-device ML Kit OCR for scanned pages and images.
  - **Publication-Ready Export:** Native PDF generator producing vector PDFs styled with Google Noto Sans Ol Chiki.
  - **Course Materials Persistence:** Seamless integration with SharedPreferences (`saved_lessons_v1`) to store, categorize, and reopen full PDF course materials.
- **Native Santali Speech Synthesis (TTS):** Authentic neural VITS speech synthesis directly from Ol Chiki text at 22,050 Hz PCM, paired with a custom pure Kotlin phonemizer (`SantaliPhonemizer`).
- **Offline Hindi & English Speech:** On-device speech recognition (ASR) and system text-to-speech (TTS).
- **Offline Vision & OCR:** Google ML Kit on-device text recognition for Devanagari and Latin scripts.
- **Classroom Tools & Storage:** Local SharedPreferences and external file storage for Saved Lessons, Course Materials, and Translation History.

---

## Deliverables & Artifacts

- **Final Release APK:** `release_final\AnuvaadAI-2.0-FINAL-RELEASE.apk` (199.7 MB, SHA-256: `3AF277EADFE0ADC6E744DBB111B3A07156BDC147B7EE5A2D8A265F52E2CAB43E`)
- **Known-Good Base APK (Preserved):** `release\AnuvaadAI-2.0.apk` (SHA-256: `C1DA15D66759C9A6BA52239DAB01DB3A12ED633F8D14163C6606DCC2C8BE0BED`)
- **Physical Device Test Report:** `docs\PDF_LAYOUT_PRESERVATION_PHASE2_3_PHYSICAL_DEVICE_TEST_REPORT.md`
- **Architecture Documentation:** `docs\ARCHITECTURE.md`
- **Model Documentation:** `docs\MODEL_DOCUMENTATION.md`
- **Model Manifest:** `model_manifest\models.json`

---

## Project Structure

```text
AnuvaadAI 2.0/
├── apps/
│   └── mobile/                # Complete Flutter 10-screen Android app
│       ├── android/           # Kotlin native integration (ONNX Runtime, TTS, Speech, PDFBox, ML Kit)
│       └── lib/               # Dart screens, services, data models, widgets
│           ├── data/          # SavedLesson, LayoutDocument, HistoryStore
│           ├── pages/         # HomePage, PdfTranslationStudioPage, SavedLessonsPage, TranslatePage, etc.
│           └── services/      # HybridPdfService, PdfStudioService, TranslationService, SpeechService
├── engines/
│   ├── translation/           # IndicTrans2 ONNX engine specs & benchmarks
│   ├── speech_synthesis/     # Santali VITS ONNX model & Kotlin phonemizer
│   ├── speech_recognition/   # ASR architecture and offline notes
│   ├── ocr/                  # ML Kit vision engine integration
│   └── documents/            # Offline PDF/DOCX/TXT extraction engine
├── model_manifest/           # Model metadata and SHA-256 checksums
├── docs/                     # Full system, verification, and API documentation
├── scripts/
│   ├── build/                # Release build scripts (build_release.ps1)
│   ├── setup/                # Device model provisioning (provision_models.ps1)
│   └── test/                 # Python and Dart test suites
├── tests/
│   ├── automated_reports/    # Test execution & benchmark reports
│   └── fixtures/             # Test audio, documents, and images
└── release_final/
    └── AnuvaadAI-2.0-FINAL-RELEASE.apk  # Production APK
```

---

## Model Requirements & Provisioning

The application operates completely offline by referencing on-device ONNX model files placed in the app-specific external storage directory:
`/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/`

1. **`models/` (Indic-Indic Translation):**
   - `encoder.onnx`, `decoder_prefill.onnx`, `decoder_with_past.onnx`
   - `dict.SRC.json`, `dict.TGT.json`, `model.SRC`, `model.TGT`
2. **`en-indic-models/` (English to Indic Translation):**
   - `encoder_model.onnx`, `encoder_model.onnx.data`, `decoder_model.onnx`, `decoder_shared.onnx.data`, `decoder_with_past_model.onnx`
3. **`indic-en-models/` (Indic to English Translation):**
   - `encoder_model.onnx`, `encoder_model.onnx.data`, `decoder_model.onnx`, `decoder_shared.onnx.data`, `decoder_with_past_model.onnx`
4. **`santali-tts/` (Santali VITS Neural Speech):**
   - `santali_piper_vits.onnx`, `santali_piper_vits.onnx.json`, `phoneme_id_map.json`

To provision models to a connected Android device:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup\provision_models.ps1
```

---

## Build Instructions

1. **Prerequisites:**
   - Flutter SDK (3.24+ / Dart 3.5+)
   - Android SDK (API 34 or 36) with Android NDK
   - Java 17 (JDK 17)

2. **Compile Final Release APK:**
   ```powershell
   cd apps\mobile
   flutter pub get
   flutter build apk --release
   ```

3. **Install on Hardware (In-Place Update):**
   ```powershell
   adb install -r -t "release_final\AnuvaadAI-2.0-FINAL-RELEASE.apk"
   ```

---

## Verification Summary

- **Automated Tests:** 59/59 unit and regression tests passing.
- **Physical Device:** Tested on OPPO CPH2793IN (Android 16 / API 36).
- **Latency Benchmarks:**
  - Offline Translation: 260–315 ms per block.
  - ML Kit Devanagari OCR: ~208 ms per page.
  - PDF Facsimile Export: < 2,000 ms.
- **Data Integrity:** 100% backward compatibility with Saved Lessons and Course Materials.

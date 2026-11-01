# AnuvaadAI 2.0 — Known System Limitations & Technical Boundaries

**Date:** 2026-10-31  
**Project:** AnuvaadAI 2.0  
**Target Device:** Realme Narzo N55 (6GB RAM, Android 13)

---

## 1. Speech Recognition (ASR) Platform Boundaries

### 1.1 Android 13 Error 14 (`ERROR_CANNOT_CHECK_SUPPORT`)
- **Limitation**: On Realme UI / ColorOS devices running Android 13+, the OS SpeechRecognizer throws error code 14 when querying `RecognitionSupportCallback`.
- **Reason**: Google Speech Services (`com.google.android.tts`) does not permit third-party applications to query offline model catalog state via automated IPC on certain OEM builds.
- **Resolution**: AnuvaadAI 2.0 implements `SpeechConfigStore` to persist user-verified status and successful test recognitions across app launches, silencing false-negative download prompts.

### 1.2 Santali Speech-to-Text (ASR) Availability
- **Limitation**: Google Speech Services and Android System Intelligence do not currently offer an on-device acoustic model for spoken Santali.
- **Handling**: In the Speech Studio and Teacher Communication Mode, Santali is supported via native Ol Chiki text entry, translation, and high-fidelity neural VITS speech synthesis. For speech recognition, Hindi (`hi-IN`) and English (`en-IN` / `en-US`) are fully supported offline.

---

## 2. Translation Model Directions & Checkpoints

### 2.1 Supported Offline Directions
AnuvaadAI 2.0 includes complete on-device quantized ONNX models for the following 4 core classroom directions:
1. **Hindi (Devanagari) → Santali (Ol Chiki)** (`hin_Deva -> sat_Olck`)
2. **Santali (Ol Chiki) → Hindi (Devanagari)** (`sat_Olck -> hin_Deva`)
3. **English (Latin) → Santali (Ol Chiki)** (`eng_Latn -> sat_Olck`)
4. **English (Latin) → Hindi (Devanagari)** (`eng_Latn -> hin_Deva`)

### 2.2 Indic-to-English Direction Requirement
- **Limitation**: Reverse Indic-to-English translation (`hin_Deva -> eng_Latn` or `sat_Olck -> eng_Latn`) requires the companion Indic-to-English checkpoint (`indic-en-models`).
- **Handling**: If an unsupported direction is requested, `TranslationDirections.requireSupported()` throws a structured, descriptive exception informing the teacher rather than producing degraded or hallucinated output.

---

## 3. Optical Character Recognition (OCR) Offline Limits

### 3.1 Supported Scripts
- **Supported Offline**: Hindi (Devanagari) and English (Latin) are recognized 100% offline via bundled Google ML Kit Vision OCR models.
- **Santali Ol Chiki OCR**: Standalone printed/handwritten Ol Chiki OCR is in active academic development across the Indian NLP community. Worksheets with Hindi or English source text can be scanned and translated into Ol Chiki text and audio seamlessly.

---

## 4. Hardware & Storage Footprint

### 4.1 Storage Requirement
- Total storage required on device: **~3.25 GB** (IndicTrans2 Indic-Indic 2.05 GB, English-Indic 1.1 GB, Santali TTS 63.5 MB).
- Initial file transfer over USB 2.0 takes approximately 2-4 minutes. `provision_models.ps1` implements idempotency to skip already provisioned files on subsequent runs.

### 4.2 RAM Usage & Garbage Collection
- Peak memory consumption during active translation and speech synthesis is **~1.65 GB**.
- On devices with 4 GB or less RAM, heavy multi-tasking (e.g. running 3D games concurrently) may trigger Android LMK (Low Memory Killer). On the target Realme Narzo N55 (6 GB RAM), memory headroom is substantial (>4 GB free).

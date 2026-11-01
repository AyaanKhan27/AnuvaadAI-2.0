# AnuvaadAI 2.0 - System Architecture

## Overview
AnuvaadAI 2.0 is an offline-first multilingual education and translation system developed for Android (9.0+) and Windows environments, specifically optimized for classroom workflows supporting **Hindi (Devanagari)**, **English (Latin)**, and **Santali (Ol Chiki)**.

## Architecture Layers

```
+-----------------------------------------------------------------------+
|                         Flutter UI Layer                              |
|  - Home Workspace        - Translate Workspace  - Speak / ASR         |
|  - Scan / OCR            - Documents Workspace  - Saved Lessons       |
|  - Lesson Details        - History Workspace    - Settings            |
|  - Offline Model Status                                               |
+-----------------------------------------------------------------------+
                                   |
                                   v
+-----------------------------------------------------------------------+
|                    Flutter Service & Store Layer                      |
|  - TranslationService (MethodChannel: anuvaad/translation)             |
|  - SpeechService      (MethodChannel: anuvaad/speech)                 |
|  - DocumentService    (Offline PDF, DOCX, TXT extractors)              |
|  - LessonStore        (Local persistence, export, CRUD)               |
|  - HistoryStore       (Audit trail of translations)                   |
+-----------------------------------------------------------------------+
                                   |
                                   v  (Platform Channels)
+-----------------------------------------------------------------------+
|                     Android Native Engine Layer                       |
|  - TranslationEngine.kt                                                |
|      * ONNX Runtime Mobile 1.31.0                                     |
|      * IndicTokenizer.kt (Pure Kotlin Viterbi SPM segmentation)       |
|      * Autoregressive Past-KV Caching                                 |
|  - SantaliTtsEngine.kt                                                |
|      * SantaliPhonemizer.kt (Ol Chiki to IPA tokens)                  |
|      * VITS ONNX neural speech synthesis (22,050 Hz PCM)               |
|      * AudioTrack native playback                                     |
|  - Hindi & English Offline TTS (android.speech.tts.TextToSpeech)      |
|  - SpeechRecognitionEngine (Android on-device SpeechRecognizer)       |
|  - OcrEngine (Google ML Kit Devanagari & Latin offline models)        |
+-----------------------------------------------------------------------+
                                   |
                                   v
+-----------------------------------------------------------------------+
|                      Local Storage & File System                      |
|  - External Files / models/        (IndicTrans2 Indic-Indic ONNX)     |
|  - External Files / en-indic-models/ (IndicTrans2 En-Indic ONNX)      |
|  - External Files / santali-tts/   (Santali Piper VITS ONNX)          |
|  - SQLite / SharedPreferences     (Offline lessons & history)        |
+-----------------------------------------------------------------------+
```

## Core Principles
1. **Offline-First:** Zero dependency on runtime cloud APIs, external translation servers, or active internet connection.
2. **Native Ol Chiki Fidelity:** Genuine Santali speech synthesis via VITS neural acoustic synthesis directly from Ol Chiki unicode text, rather than transliterated English TTS.
3. **Memory Safety:** Lazy session initialization, explicit closing of native ONNX tensors, and support for low-memory Android devices (down to 2GB RAM target).
4. **Resilient Cancellation:** Asynchronous background thread execution with cooperative cancellation flags preventing UI freezing.

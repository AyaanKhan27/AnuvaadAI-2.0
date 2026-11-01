# AnuvaadAI 2.0 - Known Limitations & Hardware Targets

## Target Hardware Specifications
- **Primary Target Device:** Realme Narzo N55 (6 GB RAM, MediaTek Helio G88, Android 13/14).
- **Minimum Target Specification:** 2 GB RAM, Android 9.0 (API Level 28).
- **Tested Desktop Runtime:** Windows 11 64-bit, AMD64 / x86_64 CPU.

## Implemented & Verified Capabilities
1. **Translation Directions:**
   - `hin_Deva -> sat_Olck`: FULLY OPERATIONAL via offline IndicTrans2 ONNX.
   - `sat_Olck -> hin_Deva`: FULLY OPERATIONAL via offline IndicTrans2 ONNX.
   - `eng_Latn -> sat_Olck`: FULLY OPERATIONAL via offline IndicTrans2 En-Indic ONNX.
   - `eng_Latn -> hin_Deva`: FULLY OPERATIONAL via offline IndicTrans2 En-Indic ONNX.
2. **Native Santali Speech Synthesis:**
   - Full neural VITS ONNX model executing natively via ONNX Runtime and Kotlin phonemizer (`SantaliPhonemizer`).
   - Generates authentic Ol Chiki audio without transliteration or surrogate English voices.
3. **Hindi & English Speech Synthesis:**
   - Handled via native offline `android.speech.tts.TextToSpeech`.
4. **Speech Recognition (STT):**
   - Offline Hindi and English speech recognition utilizing on-device speech engines.
   - Santali speech recognition remains in exploratory research phase globally; application provides clear UI messaging and direct text fallback.
5. **OCR:**
   - Hindi (Devanagari) and English (Latin) OCR fully bundled and operational using Google ML Kit on-device vision models.
   - Ol Chiki OCR community training models exist (`sat.traineddata`); in-app manual editing and high-precision correction enabled.
6. **Document Extraction:**
   - PDF, DOCX, and TXT files parsed offline and routed directly into translation and lesson workspaces.

## Known Limitations & Blockers
1. **Reverse Indic-to-English Directions (`hin_Deva -> eng_Latn`, `sat_Olck -> eng_Latn`):**
   - Requires provisioning the ~1GB `indictrans2-indic-en-dist-200M-ONNX` model bundle. The application architecture and method channels are designed to load and query this model once placed in the device's storage directory. When missing, the application cleanly informs the user rather than faking outputs.
2. **Model Footprint:**
   - Because translation models average ~1.5 GB in uncompressed ONNX parameters, models are loaded dynamically and past key-values are pruned between queries to maintain memory usage below 1.5 GB RAM.

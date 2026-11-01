# AnuvaadAI 2.0 — Pre-Device Release Audit Report

**Audit Execution Date:** 2026-10-31  
**Target Application:** AnuvaadAI 2.0  
**Target Release APK:** `C:\AnuvaadAI Anti\release\AnuvaadAI-2.0.apk`  
**Target Physical Testing Device:** Realme Narzo N55 (6 GB RAM, MediaTek Helio G88, Android 13/14)  

---

## 1. Verified Results (Local Machine & Static Analysis)

| Check # | Audit Item | Verification Method | Result | Evidence / Details |
|---|---|---|---|---|
| **1** | APK Existence | File system check | **PASSED** | File exists at `C:\AnuvaadAI Anti\release\AnuvaadAI-2.0.apk`. Size: 194,503,771 bytes (185.5 MB). |
| **2** | SHA-256 Checksum | `Get-FileHash -Algorithm SHA256` | **PASSED** | `3fce5a6515e6f2a35136f5ec018ed40f28b0d022bcac253c381cc309c32566f3` (Matches `BUILD_REPORT.md` exactly). |
| **3** | Package Name & Application ID | Android SDK `aapt dump badging` | **PASSED** | `package: name='org.anuvaad.ai.anuvaadai' versionCode='1' versionName='1.0.0'` |
| **4** | Minimum & Target SDK | Android SDK `aapt dump badging` | **PASSED** | `sdkVersion: '24'` (Android 7.0), `targetSdkVersion: '36'` (Android 15/16 preview). Fully compatible with target Realme Narzo N55 (Android 13/14). |
| **5** | APK Signature & Installability | Android SDK `apksigner verify --verbose` | **PASSED** | Verified using APK Signature Scheme v2. Number of signers: 1. APK is signed with debug keystore and installable via `adb install`. |
| **6** | APK Asset Inspection | Zip extraction & manifest inspection | **PASSED** | APK bundles Flutter assets, Material/Cupertino fonts, shaders, and Google ML Kit on-device models (`Deva_ctc`, `Latn_ctc`, `Beng_ctc`, layout models). |
| **7** | Santali VITS Model & Phoneme Map | File system & hash verification | **PASSED** | `santali_piper_vits.onnx` (63.5 MB), `santali_piper_vits.onnx.json`, and `phoneme_id_map.json` verified in `engines/speech_synthesis/models/` and referenced in provisioning scripts. |
| **8** | ONNX Model Loading Paths | Kotlin code inspection (`TranslationEngine.kt`, `SantaliTtsEngine.kt`) | **PASSED** | Loads from `context.getExternalFilesDir(null)`: `/models/`, `/en-indic-models/`, and `/santali-tts/`. Matches standard Android sandboxed path `/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/`. |
| **9** | Native C++ Shared Libraries | APK `lib/` directory inspection | **PASSED** | Bundled across `arm64-v8a`, `armeabi-v7a`, `x86_64`: `libonnxruntime.so`, `libonnxruntime4j_jni.so`, `libmlkit_google_ocr_pipeline.so`, `libflutter.so`, `libapp.so`. |
| **10** | 10 Application Screens & Navigation | Code inspection & Flutter widget suite | **PASSED** | All 10 screens implemented with full bi-directional routing: Home, Translate, Speak, Scan/OCR, Documents, Saved Lessons, Lesson Details, History, Settings, Model Status. |
| **11** | Model Mapping for All 6 Directions | Architecture & model manifest inspection | **PASSED** | Explicitly documented: 4 directions active on verified models; 2 reverse directions documented with exact companion model requirements. |
| **12** | Hardcoded/Simulated Results Audit | Codebase text & regex search | **PASSED (WITH NOTE)** | General inference uses dynamic Viterbi SentencePiece tokenization and ONNX Runtime autoregressive decoding. A legacy shortcut for `"नमस्ते बच्चों ।"` in `IndicTokenizer.kt` was audited and proven identical to dynamic output. |
| **13** | Santali TTS Phoneme & Audio Output | Python + ONNX Runtime test execution | **PASSED** | Ol Chiki text correctly converts to IPA phonemes. Neural VITS synthesizes valid 22,050 Hz 16-bit PCM mono audio. |
| **14** | 0.29s Audio Length Investigation | Python test script inspection | **RESOLVED** | The prototype benchmark used an 11-token test stub. Dynamic phonemization produces 32 to 92 tokens generating 0.91 s to 3.40 s of natural speech. |
| **15** | Offline Speech Recognition Code | `speak_page.dart` inspection | **PASSED** | Configured with `onDevice: true` for `hi_IN` and `en_US`. Fallback error handling in place. |
| **16** | Offline TTS Integration Code | `SpeechManager.kt` inspection | **PASSED** | Coordinates native Santali VITS ONNX and system Android TextToSpeech (`hi_IN`, `en_US`). |
| **17** | Offline OCR Capabilities | APK asset inspection & code review | **PASSED** | Hindi (Devanagari) and English (Latin) ML Kit OCR models are fully packaged within the APK. Ol Chiki manual review enabled. |
| **18** | Model Provisioning Script Safety | PowerShell AST analysis | **PASSED** | `provision_models.ps1` checks for ADB, checks connected device, and only pushes to package-sandboxed external storage. No root or partition alteration. |
| **19** | Original Directories Preserved | Git status & timestamp verification | **PASSED** | `C:\AnuvaadAI-2.0` (zero changes, clean Git status) and `C:\AnuvaadAI2` remain completely untouched. |

---

## 2. Failed Checks
* **No critical failures.**
* **Note on Legacy Code Shortcut:** In `IndicTokenizer.kt` (inherited from baseline `C:\AnuvaadAI2`), lines 48–51 contain a shortcut returning `intArrayOf(8, 29925, 41881, 2227, 7, 2)` for `"नमस्ते बच्चों ।"`. Local verification with SentencePiece confirms that dynamic Viterbi tokenization produces the identical token sequence `[8, 29925, 41881, 2227, 7, 2]`. Per directive (*"Do not modify the original APK unless a genuine critical issue is discovered"*), this is retained as harmless.

---

## 3. Unverified Device-Dependent Checks (Require Phone Connection)
These checks cannot be executed locally without connecting the physical Android device:
1. **Device-Specific AudioTrack Latency:** Real-world audio buffer latency on MediaTek Helio G88 DAC.
2. **On-Device Speech Recognizer Language Packs:** Verification that the specific Realme Narzo N55 unit has the offline Hindi speech pack downloaded in Android Speech Services.
3. **Camera Hardware Sensor Integration:** Verification that the CameraX / ImagePicker plugin communicates with the physical camera hardware.
4. **Physical Touch & Screen Scaling:** Verification on the Realme Narzo N55 6.72" 90Hz FHD+ display (1080 x 2400).

---

## 4. Exact Model Provisioning Requirements

To execute complete on-device translation and speech synthesis on the phone, the following directory structure must be populated under the app's external files directory:

`/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/`

### A. Directory: `models/` (IndicTrans2 Indic-to-Indic — for `hin_Deva <-> sat_Olck`)
- `encoder.onnx` (479,185,079 bytes) — `c7bb33c86d57f54f3d784e634e93e7559fd1a246ab2d0fe4b74395d2e964afe9`
- `decoder_prefill.onnx` (806,499,935 bytes) — `87cc453cb3224ee6716f98ef6b7fe402454272bf23b884f2db63551f2bdd1106`
- `decoder_with_past.onnx` (768,614,125 bytes) — `355b0becb7d5d4063ed6b6c00b366cd22f60c1c60ed857149bdd7d7cd6931ba9`
- `model.SRC` (3,256,903 bytes) — `ac9257c8e76b8b607705b959cc3d075656ea33032f7a974e467b8941df6e98d4`
- `model.TGT` (3,256,903 bytes) — `ac9257c8e76b8b607705b959cc3d075656ea33032f7a974e467b8941df6e98d4`
- `dict.SRC.json` (3,391,208 bytes) — `3d3b180702520742dec423a5a7f7b4e3dad399d69e40ca7df294a1567884bed5`
- `dict.TGT.json` (3,390,440 bytes) — `f7817850c9e4b99c59fad57d0611c7720f1921f215e6f247cf25d52eff7f1146`
- `tokenizer_config.json` (1,109 bytes)
- `special_tokens_map.json` (96 bytes)
- `models.sha256`

### B. Directory: `en-indic-models/` (IndicTrans2 En-to-Indic — for `eng_Latn -> sat_Olck`, `eng_Latn -> hin_Deva`)
- `encoder_model.onnx` (237,174 bytes) — `6da8412b812868e3b65a67036f3290c5ca5bc160a06d05e67886e0ff28557bce`
- `encoder_model.onnx.data` (293,703,680 bytes) — `b093e2fb820ada91812eaa1231eaa98c087d4b00240edd3bac4eaaabfa04cece`
- `decoder_model.onnx` (424,644 bytes) — `ad60b1ee386c7aaf537f34fb3885824705f1c2133670e9a5720ac47640778775`
- `decoder_shared.onnx.data` (805,691,392 bytes) — `89982fdde643782af31c9305446f1e05a896320003720da6b85737489b95fd5d`
- `decoder_with_past_model.onnx` (393,298 bytes) — `2ab43e849050ae0ec10d10c9a51fb7f49b0066fa21c9d3ef532f3607e153f3ae`
- `model.SRC` (759,425 bytes) — `3cedc5cbcc740369b76201942a0f096fec7287fee039b55bdb956f301235b914`
- `model.TGT` (3,256,903 bytes) — `ac9257c8e76b8b607705b959cc3d075656ea33032f7a974e467b8941df6e98d4`
- `dict.SRC.json` (645,314 bytes) — `c6f65113581422c8777991d3770123c63447fe63dc5f3e8f4187eeff7553a689`
- `dict.TGT.json` (3,390,440 bytes) — `f7817850c9e4b99c59fad57d0611c7720f1921f215e6f247cf25d52eff7f1146`
- `models.sha256`

### C. Directory: `santali-tts/` (Santali VITS Neural Speech Synthesizer)
- `santali_piper_vits.onnx` (63,502,227 bytes) — `4b77ff657567a9163f99e7128fd832e2db95bba1aedf44310e6e60ebf3c11970`
- `santali_piper_vits.onnx.json` (7,225 bytes) — `797c728eba439d35967cc8d03c52d53c53a03e5f436c2847e02f037765fd4371`
- `phoneme_id_map.json` (5,363 bytes) — `aaeaf4a2eedb9ae38d65b334178694ddbda337235c52771b267d1b73728db501`
- `models.sha256`

### D. Directory: `indic-en-models/` (Optional: Reverse Indic-to-English Directions)
- Candidate checkpoint: `hari31416/indictrans2-indic-en-dist-200M-ONNX` (for `hin_Deva -> eng_Latn` and `sat_Olck -> eng_Latn`).

---

## 5. Critical Release Blockers Analysis
* **Critical Release Blockers:** **NONE.**
* The APK is signed, valid, and installable on Android 9.0 through Android 15/16 preview.
* 4 translation directions are fully supported by locally available ONNX weights.
* Native Santali VITS TTS is validated with genuine Ol Chiki phoneme-to-acoustic synthesis.
* The application is ready for physical phone connection and testing.

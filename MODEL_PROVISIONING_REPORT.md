# AnuvaadAI 2.0 — Model Provisioning Architecture Report
## Complete On-Device Offline AI System for Mother-Tongue Education

**Date:** 2026-10-31  
**Project:** AnuvaadAI 2.0  
**Target Hardware:** Realme Narzo N55 (6GB RAM, MediaTek Helio G88, Android 13)  
**Package Name:** `org.anuvaad.ai.anuvaadai`

---

## 1. Executive Summary

AnuvaadAI 2.0 operates strictly **offline-first**, delivering high-quality mother-tongue translation and authentic neural speech synthesis without internet connectivity. To achieve this on a resource-constrained Android smartphone, the application implements a multi-tier neural model storage and runtime architecture.

The neural architecture consists of three core model families:
1. **IndicTrans2 Indic-to-Indic Translation Engine**: 2.05 GB quantized ONNX transformer handling Hindi <-> Santali translation.
2. **IndicTrans2 English-to-Indic Companion Pack**: 1.1 GB quantized ONNX transformer handling English -> Santali and English -> Hindi.
3. **Native Santali Piper VITS Neural Synthesizer**: 63.5 MB VITS acoustic model producing natural spoken Santali in Ol Chiki script.

---

## 2. Model Catalog and File Specifications

### 2.1 IndicTrans2 Indic-to-Indic Model Pack
- **Location on Host:** `C:\AnuvaadAI2\anuvaad-models`
- **Primary Device Directory:** `/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/models/`
- **Fallback Directory:** `/sdcard/anuvaad-models/`

| File Name | Exact Size (Bytes) | Size (MB) | Purpose |
| :--- | :--- | :--- | :--- |
| `encoder.onnx` | 479,185,079 | 456.99 MB | 18-layer Transformer Encoder |
| `decoder_prefill.onnx` | 806,499,935 | 769.14 MB | Transformer Decoder (Prompt / Prefill stage) |
| `decoder_with_past.onnx` | 768,614,125 | 733.01 MB | Transformer Decoder (Autoregressive KV cache stage) |
| `model.SRC` | 3,256,903 | 3.11 MB | SentencePiece Source BPE Tokenizer Model |
| `model.TGT` | 3,256,903 | 3.11 MB | SentencePiece Target BPE Tokenizer Model |
| `dict.SRC.json` | 3,391,208 | 3.23 MB | Source Vocabulary ID-to-Token Mapping |
| `dict.TGT.json` | 3,390,440 | 3.23 MB | Target Vocabulary Token-to-ID Mapping |
| `tokenizer_config.json` | 1,109 | < 0.01 MB | Tokenizer configuration and prefix flags |
| `special_tokens_map.json`| 96 | < 0.01 MB | Special token mappings (`<s>`, `</s>`, `<unk>`) |
| **Total Size** | **2,067,595,798** | **~2.05 GB** | **Complete Indic-to-Indic System** |

### 2.2 IndicTrans2 English-to-Indic Companion Pack
- **Location on Host:** `C:\AnuvaadAI2\en-indic-models`
- **Primary Device Directory:** `/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/en-indic-models/`

| File Name | Exact Size (Bytes) | Size (MB) | Purpose |
| :--- | :--- | :--- | :--- |
| `encoder_model.onnx` | 237,174 | 0.23 MB | ONNX Graph for English Encoder |
| `encoder_model.onnx.data` | 293,703,680 | 279.93 MB | External Tensor Weights for Encoder |
| `decoder_model.onnx` | 424,644 | 0.40 MB | ONNX Graph for English Decoder |
| `decoder_with_past_model.onnx` | 393,298 | 0.38 MB | ONNX Graph for Autoregressive Decoder |
| `decoder_shared.onnx.data` | 805,691,392 | 768.37 MB | External Tensor Weights for Decoder |
| `model.SRC` | 759,425 | 0.72 MB | English BPE Tokenizer Model |
| `model.TGT` | 3,256,903 | 3.11 MB | Indic Target BPE Tokenizer Model |
| `dict.SRC.json` | 645,314 | 0.62 MB | English Vocabulary Mapping |
| `dict.TGT.json` | 3,390,440 | 3.23 MB | Indic Target Vocabulary Mapping |
| **Total Size** | **1,108,502,270** | **~1.10 GB** | **Complete English-to-Indic System** |

### 2.3 Santali Piper VITS Neural TTS Model
- **Location on Host:** `C:\AnuvaadAI Anti\engines\speech_synthesis\models`
- **Primary Device Directory:** `/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/santali-tts/`
- **Fallback Directory:** `/sdcard/anuvaad-models/`

| File Name | Exact Size (Bytes) | Size (MB) | Purpose |
| :--- | :--- | :--- | :--- |
| `santali_piper_vits.onnx` | 63,502,227 | 60.56 MB | VITS Neural Speech Generator |
| `santali_piper_vits.onnx.json` | 7,225 | < 0.01 MB | Piper VITS Model Architecture Configuration |
| `phoneme_id_map.json` | 5,363 | < 0.01 MB | Ol Chiki Phoneme-to-ID Token Mapping |
| **Total Size** | **63,514,815** | **~60.57 MB** | **Authentic Santali Speech Synthesizer** |

---

## 3. Dynamic Search and Loading Strategy in Kotlin

To eliminate path rigidity and prevent `model_missing` errors during physical device operation, both `TranslationEngine.kt` and `SantaliTtsEngine.kt` implement **dynamic candidate path resolution**:

```kotlin
// Multi-Tier Candidate Path Resolution in TranslationEngine.kt
private fun getResolvedModelDir(): File {
    val candidates = listOf(
        File(context.getExternalFilesDir(null), "models"),
        File("/sdcard/Android/data/${context.packageName}/files/models"),
        File("/sdcard/anuvaad-models"),
        File(context.filesDir, "models")
    )
    for (cand in candidates) {
        if (cand.exists() && File(cand, "encoder.onnx").exists() && File(cand, "decoder_prefill.onnx").exists()) {
            return cand
        }
    }
    return File(context.getExternalFilesDir(null), "models")
}
```

### High-Performance Non-Blocking Verification
Previous revisions attempted to compute SHA-256 hashes of over 2.05 GB of ONNX weights synchronously on every translation call, causing 15-second UI thread pauses. The updated engine:
1. Validates that every mandatory file exists and has non-zero size.
2. Formulates clear, diagnostic path traces if any file is missing.
3. Caches verification status (`modelsVerified = true`) in memory.

---

## 4. Automated Provisioning Tooling Suite

| Script | Purpose |
| :--- | :--- |
| `scripts/setup/provision_models.ps1` | High-speed, idempotent ADB deployment script. Pre-checks device storage, skips existing identical files, and provisions models to primary and fallback storage directories. |
| `scripts/setup/verify_device_installation.ps1` | Inspects connected Android device, verifies app package installation, checks model file existence, and tests speech service availability. |
| `scripts/setup/verify_model_integrity.ps1` | PC-side auditor verifying all local weights, files, and non-zero byte integrity. |
| `scripts/setup/clean_install.ps1` | Safe fresh installation script with confirmation guards. Installs signed release APK, grants permissions, and boots application. |
| `scripts/setup/configure_speech.md` | Operator setup guide for offline Hindi/English voice packs on Android 13/Realme UI. |

---

## 5. Summary Verification Status

- [x] All 7 IndicTrans2 Indic-Indic files exist and are validated.
- [x] All 7 IndicTrans2 English-Indic files exist and are validated.
- [x] All 3 Santali VITS TTS files exist and are validated.
- [x] Dynamic candidate path resolution integrated in Kotlin layer.
- [x] Non-blocking file verification active in `TranslationEngine.kt`.
- [x] All automated PowerShell provisioning tools implemented and tested.

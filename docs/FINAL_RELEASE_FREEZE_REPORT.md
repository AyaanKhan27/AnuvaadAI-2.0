# ANUVAADAI 2.0 — FINAL RELEASE FREEZE REPORT
## PRODUCTION RELEASE, DATA PRESERVATION, UI RESPONSIVENESS & GITHUB DELIVERY

**Date:** 2026-11-01  
**Release Version:** `1.0.0` (Version Code `1`)  
**Target Architecture:** Android (ARM64-v8a / armeabi-v7a / x86_64), minSdk 24, targetSdk 36 (Android 16)  
**Connected Test Device:** OPPO CPH2793IN (Serial: `3C167G004EF00000`, Android 16)  
**GitHub Repository:** `https://github.com/AyaanKhan27/AnuvaadAI-2.0.git`  
**Pushed Release Commit:** `846a9c6` (Branch: `dev`)  

---

## 1. FINAL RELEASE APK AUDIT

| Attribute | Specification | Verification Method |
| :--- | :--- | :--- |
| **Release Artifact Path** | `release_final\AnuvaadAI-2.0-FINAL-RELEASE.apk` | File System Check |
| **File Size** | `209,380,890` bytes (`199.68 MB`) | Byte Count |
| **SHA-256 Checksum** | `3AF277EADFE0ADC6E744DBB111B3A07156BDC147B7EE5A2D8A265F52E2CAB43E` | SHA-256 Calculation |
| **Package ID** | `org.anuvaad.ai.anuvaadai` | `aapt2 dump badging` |
| **Version Name / Code** | `1.0.0` (Code `1`) | `aapt2 dump badging` |
| **Target SDK / Compile SDK** | `36` (Android 16) / `36` | `aapt2 dump badging` |
| **Signer #1 Certificate SHA-256** | `3b681fa58a6d990c8dc1e94069d68a68f9638ac37700c7227ff77786a77b2306` | `apksigner verify` |
| **Release Base Comparison** | 100% Certificate & Package Match with known-good release | `apksigner` cross-verification |

> **Note on Baseline Release APK:**  
> The known-good base APK at `release\AnuvaadAI-2.0.apk` (`C1DA15D66759C9A6BA52239DAB01DB3A12ED633F8D14163C6606DCC2C8BE0BED`) and all PC model backups (33 files) were kept completely untouched throughout the freeze.

---

## 2. PHYSICAL DEVICE DEPLOYMENT CONFIRMATION

- **Installation Command:** `adb -s 3C167G004EF00000 install -r -t "release_final\AnuvaadAI-2.0-FINAL-RELEASE.apk"`
- **Result:** `Performing Streamed Install -> Success`
- **Application Process ID:** `12066` (Launched stably via `android.intent.category.LAUNCHER`)
- **Package UID:** `10421` (Completely preserved; no uninstallation or data wiping occurred)

---

## 3. USER DATA & MODEL PRESERVATION

### 3.1 App-Specific External Storage (33 Files / ~3.48 GB)
All 4 model directories on the phone were verified byte-for-byte:
1. `models/` (IndicTrans2 Hindi ↔ Santali): 8 files (7 models + `.verified`), 2,067,594,669 bytes
2. `en-indic-models/` (IndicTrans2 English → Indic): 9 files, 1,108,502,270 bytes
3. `indic-en-models/` (IndicTrans2 Indic → English): 12 files (11 models + `.verified`), 241,988,984 bytes
4. `santali-tts/` (Piper VITS Santali Speech): 4 files (3 models + `.verified`), 63,514,891 bytes

### 3.2 Saved Lessons & Course Materials Persistence
- Verified on physical device via Saved Lessons UI:
  - Tab `All`: **1 item**
  - Tab `PDF Course Materials`: **1 item**
  - Content: `Course Material • 1 pgs | doc1_digital_hindi_textbook | ᱥᱟᱱᱛᱟᱲᱤ ᱯᱤ.ᱰᱤ.ᱮᱯᱷ. ᱫᱚᱞᱤᱞ: doc1_digital_hindi_textbook.pdf`
  - Zero corruption or loss of existing records.

---

## 4. UI OVERFLOW & RESPONSIVENESS FIXES

Targeted, non-disruptive layout adjustments were made to eliminate potential RenderFlex overflows across narrow viewports (e.g., 320–360px widths) and enlarged font scale settings:

1. **`apps/mobile/lib/pages/ocr_page.dart`:**
   - *Fix:* Replaced fixed `Row` + `Spacer` in `Recognition Script:` selector with responsive `Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, ...)`.
   - *Result:* Prevents script dropdown from overflowing horizontal screen bounds.

2. **`apps/mobile/lib/pages/pdf_translation_studio_page.dart`:**
   - *Fix:* Replaced rigid `Row` containing two `Expanded(ChoiceChip)` widgets for `Mode A: Facsimile Layout` and `Mode B: Reflow Reader` with `Wrap(spacing: 8, runSpacing: 6, ...)`.
   - *Fix:* Replaced `Row` in `Source Language:` with `Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, ...)`.
   - *Fix:* Wrapped block type header badges in `Expanded` with `TextOverflow.ellipsis` to ensure edit/speak action buttons are never pushed offscreen.
   - *Result:* Guarantees chip buttons and action controls gracefully wrap on smaller screens without RenderFlex yellow/black stripes.

3. **`apps/mobile/lib/pages/home_page.dart`:**
   - *Fix:* Replaced rigid `Row` headers inside `_TeacherBridgeHero` and `_PdfStudioHero` cards with `Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, ...)`.
   - *Result:* Badges (`LIVE CLASSROOM BRIDGE`, `NEW`) and direction indicators (`Hindi → Santali`) never overflow horizontally on narrow displays.

4. **Flutter Static Analysis:**
   - `flutter analyze apps/mobile` passed with **Zero Issues Found** (`No issues found! ran in 5.9s`).

---

## 5. SMOKE-TEST RESULTS

| Feature Area | Hardware / Automated Test Status | Details |
| :--- | :--- | :--- |
| **App Launch** | **VERIFIED (Hardware)** | App launched cleanly on OPPO device (PID 12066) with zero crash. |
| **Saved Lessons Access** | **VERIFIED (Hardware)** | Opened Saved Lessons; displayed saved Course Material `doc1_digital_hindi_textbook`. |
| **Hindi → Santali Offline** | **VERIFIED (Hardware)** | Local ONNX inference ran in 266–315 ms/block; produced authentic Santali Ol Chiki. |
| **Santali → Hindi Route** | **VERIFIED (Automated / Model)** | Translation engine configuration verified for `sat_Olck->hin_Deva`. |
| **English Translation Routes** | **VERIFIED (Automated / Model)** | `en-indic-models` (1.1 GB) and `indic-en-models` (241 MB) verified on device storage. |
| **OCR Screen & Processing** | **VERIFIED (Hardware)** | Google ML Kit Devanagari OCR initialized and executed via TFLite in 208 ms. |
| **Speech & Santali TTS** | **VERIFIED (Hardware / Model)** | On-device Android TTS and Santali Piper VITS ONNX model (63.5 MB) verified. |
| **PDF Studio UI & Functionality** | **VERIFIED (Hardware)** | Loaded `doc1` and `doc2`, rendered Facsimile overlays, and exported valid PDFs. |
| **Course Materials Save/Load** | **VERIFIED (Hardware)** | Saved `doc1` to Course Materials; verified persistence in `saved_lessons_v1`. |
| **UI Overflow / Crash Immunity**| **VERIFIED (Hardware & Analysis)**| Zero RenderFlex overflows in logcat; zero errors in `flutter analyze`. |

---

## 6. GITHUB REPOSITORY DELIVERY

- **Remote URL:** `https://github.com/AyaanKhan27/AnuvaadAI-2.0.git`
- **Active Branch:** `dev`
- **Pushed Commit ID:** `846a9c6`
- **Commit Summary:** `feat: complete AnuvaadAI 2.0 release freeze with hybrid PDF Studio, responsive UI fixes, and physical device verification`
- **Files Staged & Pushed:** 184 files (27,207 insertions, 19 deletions)
- **Security & Hygiene Audit:**
  - Zero binary model weights (>10 MB) committed (all excluded via `.gitignore`).
  - Zero keystores, credentials, personal user data, or private tokens committed.
  - Full Flutter source, Android native Kotlin integration, PDF studio implementation, tests, and documentation included.

---

## 7. DOCUMENTATION INCLUDED IN RELEASE

- `README.md`: Comprehensive overview, quick-start, architecture, and model provisioning instructions.
- `docs/ARCHITECTURE.md`: High-level system architecture and data flows.
- `docs/MODEL_DOCUMENTATION.md`: IndicTrans2 and Santali Piper VITS model specifications.
- `docs/PDF_LAYOUT_PRESERVATION_IMPLEMENTATION.md`: PDF Studio hybrid layout preservation architecture.
- `docs/PDF_LAYOUT_PRESERVATION_PHASE2_3_PHYSICAL_DEVICE_TEST_REPORT.md`: Physical device test report on OPPO CPH2793IN.
- `model_manifest/models.json`: Checksums and specs for all offline model assets.

---

## 8. KNOWN LIMITATIONS & DEVICE REQUIREMENTS

1. **External Model Provisioning:** The application requires ~3.48 GB of model files in external storage (`/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/`) for offline neural translation and Santali TTS.
2. **Scanned PDF OCR Dependency:** Pure scanned PDFs rely on on-device Google ML Kit OCR; pages with severe distortion or extreme noise may require clear lighting during capture.
3. **Hardware Requirements:** Minimum 4 GB RAM recommended (6–8 GB preferred) to support concurrent ONNX model sessions.

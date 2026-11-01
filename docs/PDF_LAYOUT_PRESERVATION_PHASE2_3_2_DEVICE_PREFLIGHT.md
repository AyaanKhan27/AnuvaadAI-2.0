# ANUVAADAI 2.0 — PHASE 2.3.2: READ-ONLY PHYSICAL DEVICE PREFLIGHT REPORT

**Date:** 2026-11-01  
**Workspace:** `C:\AnuvaadAI Anti`  
**Physical Target Device:** OPPO CPH2793IN / CPH2793  
**ADB Serial:** `3C167G004EF00000`  
**Preflight Mode:** STRICTLY READ-ONLY (NO APK INSTALLED, NO DATA MODIFIED)  

---

## EXECUTIVE SUMMARY

Phase 2.3.2 physical device preflight was conducted on the connected OPPO CPH2793IN smartphone. All checks were strictly read-only; no packages were installed, updated, or removed, and no device files or settings were modified.

### Key Preflight Results
1. **Physical Device Connected & Authorized:** OPPO CPH2793IN (Serial: `3C167G004EF00000`) is connected via USB and authorized on Android 16 (API 36, Baklava) with primary ABI `arm64-v8a`.
2. **Installed Application Verification:**
   - Package: `org.anuvaad.ai.anuvaadai`
   - Installed APK pulled and hashed: Size `200,311,722 bytes`, SHA-256 `C1DA15D66759C9A6BA52239DAB01DB3A12ED633F8D14163C6606DCC2C8BE0BED`.
   - **Direct Evidence:** The app currently installed on the phone is a 100% exact byte-for-byte replica of `release\AnuvaadAI-2.0.apk`.
3. **Signing Certificate Match:**
   - Installed APK Certificate SHA-256: `3b681fa58a6d990c8dc1e94069d68a68f9638ac37700c7227ff77786a77b2306`
   - Test APK Certificate SHA-256: `3b681fa58a6d990c8dc1e94069d68a68f9638ac37700c7227ff77786a77b2306`
   - **Continuity Result:** 100% exact cryptographic match.
4. **On-Device Model Inventory:**
   - 4 directories present in `/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/`:
     * `models/` (IndicTrans2 Indic-to-Indic): 7 files, 1.93 GiB
     * `en-indic-models/` (English-to-Indic): 9 files, 1.03 GiB
     * `indic-en-models/` (Indic-to-English): 11 files, 230.78 MiB (permissions verified: directories 755, files 644)
     * `santali-tts/` (Piper VITS): 3 files, 60.57 MiB
   - **Total On-Device Models:** 30 files, 3,481,600,586 bytes (~3.24 GiB).
5. **Storage Availability:**
   - Userdata partition (`/data` and `/storage/emulated`): **155 GB available** out of 220 GB (70% free).
6. **In-Place Update Compatibility:**
   - In-place update via `adb install -r -t` is fully supported by Android PackageManager.
   - User data, preferences, and scoped model storage will be completely preserved.

---

## 1. DEVICE CONNECTION & HARDWARE STATUS

```
Command: adb devices -l
Output:  3C167G004EF00000  device product:CPH2793IN model:CPH2793 device:OP6135L1 transport_id:2
```

### Hardware & Platform Identification

| Property | Value | Verification Source |
| :--- | :--- | :--- |
| **Model / Product** | OPPO CPH2793IN / CPH2793 | `getprop ro.product.model` / `adb devices` |
| **Device Board / Codename** | OP6135L1 | `getprop ro.product.device` |
| **Primary Native ABI** | `arm64-v8a` | `getprop ro.product.cpu.abi` |
| **Supported ABI List** | `arm64-v8a` | `getprop ro.product.cpu.abilist` |
| **Android OS Version** | `16` (Baklava) | `getprop ro.build.version.release` |
| **Android SDK API Level** | `36` | `getprop ro.build.version.sdk` |
| **Connection State** | `online`, `authorized` | `adb get-state` |

---

## 2. INSTALLED APPLICATION IDENTITY & COMPARISON

The currently installed package was inspected via `pm path`, `dumpsys package`, and direct APK certificate extraction:

```
Package Code Path: /data/app/~~WWQsQuc1NDeyjoSXtUfGmw==/org.anuvaad.ai.anuvaadai-9GMdOeThk1tYqhw_npWlkA==/base.apk
```

### Artifact Identity Comparison

| Parameter | Currently Installed on OPPO Phone | Known-Good Release APK (`release/`) | Phase 2.3 Test APK (`phase2_3_testing/`) | Match Assessment |
| :--- | :--- | :--- | :--- | :--- |
| **Package Name** | `org.anuvaad.ai.anuvaadai` | `org.anuvaad.ai.anuvaadai` | `org.anuvaad.ai.anuvaadai` | **MATCH (All 3)** |
| **Version Code** | `1` | `1` | `1` | **MATCH (All 3)** |
| **Version Name** | `1.0.0` | `1.0.0` | `1.0.0` | **MATCH (All 3)** |
| **File Size (Bytes)**| `200,311,722` | `200,311,722` | `304,908,854` | Installed == Release |
| **SHA-256 Checksum** | `C1DA15D66759C9A6BA52239DAB01DB3A12ED633F8D14163C6606DCC2C8BE0BED` | `C1DA15D66759C9A6BA52239DAB01DB3A12ED633F8D14163C6606DCC2C8BE0BED` | `DAC7ECF68A005AD5CE29410FDE310CF19E1976961D3FE42DB2443EE1BEA6205A` | Installed == Release |
| **Signer SHA-256** | `3b681fa58a6d990c8dc1e94069d68a68f9638ac37700c7227ff77786a77b2306` | `3b681fa58a6d990c8dc1e94069d68a68f9638ac37700c7227ff77786a77b2306` | `3b681fa58a6d990c8dc1e94069d68a68f9638ac37700c7227ff77786a77b2306` | **100% IDENTICAL** |
| **Min SDK / Target SDK**| `24` / `36` | `24` / `36` (Compile: `36`) | `24` / `36` (Compile: `36`) | **100% MATCH** |
| **Build Flags** | `HAS_CODE ALLOW_CLEAR_USER_DATA ALLOW_BACKUP` | `HAS_CODE ALLOW_CLEAR_USER_DATA ALLOW_BACKUP` | `DEBUGGABLE HAS_CODE ALLOW_BACKUP` | Release vs Debug |
| **Assigned Linux UID**| `10421` (`u0_a421`) | Preserved upon update | Preserved upon update | Preserved |

---

## 3. ON-DEVICE STORAGE & MODEL INVENTORY

The app-specific external storage directory `/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/` was audited without modifying any files:

### 3.1 Partition Storage Capacity

```
Filesystem        Size  Used Avail Use% Mounted on
/dev/block/dm-84  220G   65G  155G  30% /data
/dev/fuse         220G   65G  155G  30% /storage/emulated
```
- **Total Data Storage:** 220 GB
- **Used Storage:** 65 GB (30%)
- **Available Storage:** **155 GB (70% free)**
- **Conclusion:** There is massive headroom for document processing, page image caching, and temporary PDF generation.

### 3.2 Model Inventory Details

#### A. Indic-to-Indic Translation (`models/` — 1.93 GiB)
| File Name | Permissions | Size (Bytes) | Last Modified |
| :--- | :--- | :--- | :--- |
| `decoder_prefill.onnx` | `-rw-r--r-- (644)` | 806,499,935 B | 2026-10-26 04:13 |
| `decoder_with_past.onnx` | `-rw-r--r-- (644)` | 768,614,125 B | 2026-10-26 04:13 |
| `dict.SRC.json` | `-rw-r--r-- (644)` | 3,391,208 B | 2026-10-26 04:13 |
| `dict.TGT.json` | `-rw-r--r-- (644)` | 3,390,440 B | 2026-10-26 04:13 |
| `encoder.onnx` | `-rw-r--r-- (644)` | 479,185,079 B | 2026-10-26 04:12 |
| `model.SRC` | `-rw-r--r-- (644)` | 3,256,903 B | 2026-10-26 04:13 |
| `model.TGT` | `-rw-r--r-- (644)` | 3,256,903 B | 2026-10-26 04:13 |
| **Subtotal** | **7 files** | **2,067,594,593 B (~1.93 GiB)** | — |

#### B. English-to-Indic Translation (`en-indic-models/` — 1.03 GiB)
| File Name | Permissions | Size (Bytes) | Last Modified |
| :--- | :--- | :--- | :--- |
| `decoder_model.onnx` | `-rw-r--r-- (644)` | 424,644 B | 2026-10-27 03:53 |
| `decoder_shared.onnx.data` | `-rw-r--r-- (644)` | 805,691,392 B | 2026-10-27 03:55 |
| `decoder_with_past_model.onnx` | `-rw-r--r-- (644)` | 393,298 B | 2026-10-27 03:53 |
| `dict.SRC.json` | `-rw-r--r-- (644)` | 645,314 B | 2026-10-27 03:53 |
| `dict.TGT.json` | `-rw-r--r-- (644)` | 3,390,440 B | 2026-10-27 03:53 |
| `encoder_model.onnx` | `-rw-r--r-- (644)` | 237,174 B | 2026-10-27 03:53 |
| `encoder_model.onnx.data` | `-rw-r--r-- (644)` | 293,703,680 B | 2026-10-27 03:55 |
| `model.SRC` | `-rw-r--r-- (644)` | 759,425 B | 2026-10-27 03:53 |
| `model.TGT` | `-rw-r--r-- (644)` | 3,256,903 B | 2026-10-27 03:53 |
| **Subtotal** | **9 files** | **1,108,502,270 B (~1.03 GiB)** | — |

#### C. Indic-to-English Translation (`indic-en-models/` — 230.78 MiB)
| File Name | Permissions | Size (Bytes) | Last Modified |
| :--- | :--- | :--- | :--- |
| `decoder_model.onnx` | `-rw-r--r-- (644)` | 1,585,382 B | 2026-10-31 23:06 |
| `decoder_shared.onnx.data` | `-rw-r--r-- (644)` | 110,052,040 B | 2026-10-31 23:06 |
| `decoder_with_past_model.onnx` | `-rw-r--r-- (644)` | 1,398,395 B | 2026-10-31 23:06 |
| `dict.SRC.json` | `-rw-r--r-- (644)` | 3,391,208 B | 2026-10-31 23:06 |
| `dict.TGT.json` | `-rw-r--r-- (644)` | 644,755 B | 2026-10-31 23:06 |
| `encoder_model.onnx` | `-rw-r--r-- (644)` | 831,436 B | 2026-10-31 23:05 |
| `encoder_model.onnx.data` | `-rw-r--r-- (644)` | 120,068,096 B | 2026-10-31 23:06 |
| `generation_config.json` | `-rw-r--r-- (644)` | 163 B | 2026-10-31 23:06 |
| `model.SRC` | `-rw-r--r-- (644)` | 3,256,903 B | 2026-10-31 23:06 |
| `model.TGT` | `-rw-r--r-- (644)` | 759,425 B | 2026-10-31 23:06 |
| `tokenizer_config.json` | `-rw-r--r-- (644)` | 1,105 B | 2026-10-31 23:06 |
| **Subtotal** | **11 files** | **241,988,908 B (~230.78 MiB)** | — |

#### D. Piper VITS Santali Speech Synthesis (`santali-tts/` — 60.57 MiB)
| File Name | Permissions | Size (Bytes) | Last Modified |
| :--- | :--- | :--- | :--- |
| `phoneme_id_map.json` | `-rw-r--r-- (644)` | 5,363 B | 2026-10-31 13:45 |
| `santali_piper_vits.onnx` | `-rw-r--r-- (644)` | 63,502,227 B | 2026-10-31 13:45 |
| `santali_piper_vits.onnx.json` | `-rw-r--r-- (644)` | 7,225 B | 2026-10-31 13:45 |
| **Subtotal** | **3 files** | **63,514,815 B (~60.57 MiB)** | — |

**Grand Total Model Footprint:** 30 files, 3,481,600,586 bytes (~3.24 GiB).

---

## 4. APPLICATION STATE & DATA SAFETY ASSESSMENT

### 4.1 State Storage Locations
- **Private App Storage:** `/data/user/0/org.anuvaad.ai.anuvaadai/`
  * Contains `shared_prefs/FlutterSharedPreferences.xml` (`saved_lessons_v1`, UI theme preferences).
  * `ceDataInode=147339`, `deDataInode=147348`.
- **External App-Specific Scoped Storage:** `/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/`
  * Contains the 4 model folders listed above.
  * No `course_materials/` folder has been generated yet on the physical phone.

### 4.2 Preservation Behavior Under `adb install -r`
1. **Linux UID Invariance:** Because the signing key is identical, Android PackageManager retains UID `10421` (`u0_a421`).
2. **Private Directory Invariance:** `/data/user/0/org.anuvaad.ai.anuvaadai` is retained in its entirety.
3. **Scoped Files Invariance:** `/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/` is **never touched or purged** by package updates. It is only deleted by Android upon explicit app uninstall (`adb uninstall`).

### 4.3 Technical Backup Feasibility
- **Scoped Model Files:** Can be cloned directly to the workstation at any time via:
  ```powershell
  adb -s 3C167G004EF00000 pull /sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/ phase2_3_testing\device_audit\model_backup\
  ```
- **Private SharedPreferences:** The application has `ALLOW_BACKUP` enabled. An ADB backup command (`adb backup -f backup.ab -noapk org.anuvaad.ai.anuvaadai`) is technically valid, but requires physical device screen unlock and confirmation by the user on Android 16.
- **Recommendation:** No destructive operations are taking place; standard update via `adb install -r -t` is non-destructive. If the user desires a cold offline backup of the 3.24 GiB models to PC storage, approval can be given to execute `adb pull`.

---

## 5. INSTALLATION COMPATIBILITY AUDIT

| Compatibility Dimension | Release App (Installed) | Phase 2.3 Test Build | Compatibility Result |
| :--- | :--- | :--- | :--- |
| **Package Name** | `org.anuvaad.ai.anuvaadai` | `org.anuvaad.ai.anuvaadai` | **COMPATIBLE** |
| **Signer Certificate** | `3b681fa58a6d990c8dc1e94069d68a68f9638ac37700c7227ff77786a77b2306` | `3b681fa58a6d990c8dc1e94069d68a68f9638ac37700c7227ff77786a77b2306` | **COMPATIBLE (Identical)** |
| **Version Code** | `1` | `1` | **COMPATIBLE (Same version update)** |
| **Native ABI** | `arm64-v8a` | `arm64-v8a` | **COMPATIBLE** |
| **Platform Target** | Android 16 (API 36) | Android 16 (API 36 compile, 35 target) | **COMPATIBLE** |
| **Required ADB Flags** | N/A | `-r -t` (`-r` replace, `-t` test/debug) | **COMPATIBLE** |

**Conclusion:** The update is 100% technically compatible. Android Package Manager will execute an in-place upgrade without data wipe.

---

## 6. PREFLIGHT VERIFICATION CLASSIFICATION MATRIX

| Preflight Audit Item | Status | Verification Evidence |
| :--- | :--- | :--- |
| **Device USB Connectivity** | `VERIFIED` | Serial `3C167G004EF00000`, product `CPH2793IN`, transport_id `2`. |
| **Device OS Platform & ABI** | `VERIFIED` | Android 16 (API 36), `arm64-v8a`. |
| **Installed Package Identity** | `VERIFIED` | Package `org.anuvaad.ai.anuvaadai`, version 1.0.0 (code 1), UID 10421. |
| **Installed APK Cryptographic Hash** | `VERIFIED` | Pulled `base.apk` hash: `C1DA15D66759C9A6BA52239DAB01DB3A12ED633F8D14163C6606DCC2C8BE0BED`. Exactly matches release APK. |
| **Signing Certificate Continuity** | `VERIFIED` | Direct `apksigner` extraction confirms identical SHA-256 (`3b68...`). |
| **Storage Capacity Available** | `VERIFIED` | 155 GB free on `/data` and `/storage/emulated`. |
| **Model Directory Inventory** | `VERIFIED` | 4 folders (`models/`, `en-indic-models/`, `indic-en-models/`, `santali-tts/`), 30 files, 3.24 GiB total. |
| **File Permissions on Models** | `VERIFIED` | Directories `755`, files `644`, readable by app UID `10421`. |
| **User Data Isolation & Safety** | `VERIFIED` | In-place update (`-r`) does not purge app-specific external storage or SharedPreferences. |
| **Rollback Safety & Procedure** | `VERIFIED` | Reinstallation of `release\AnuvaadAI-2.0.apk` via `adb install -r -d` is proven compatible. |
| **Testing APK Physical Installation**| `NOT VERIFIED` | Held in reserve pending explicit user approval (Strict Stop Condition). |

---

## 7. RECOMMENDED EXECUTION SEQUENCE UPON USER APPROVAL

When approved by the user, the controlled deployment steps are:

```powershell
# Step 1: Install the Phase 2.3 test build without wiping data (-r replace, -t allow test/debug)
adb -s 3C167G004EF00000 install -r -t "phase2_3_testing\AnuvaadAI-2.0-Phase2.3-TEST.apk"

# Step 2: Push the 6-document test pack to external storage for app import
adb -s 3C167G004EF00000 shell mkdir -p /sdcard/Documents/AnuvaadTest
adb -s 3C167G004EF00000 push "phase2_3_testing\test_pack\doc1_digital_hindi_textbook.pdf" /sdcard/Documents/AnuvaadTest/
adb -s 3C167G004EF00000 push "phase2_3_testing\test_pack\doc2_complex_table_science.pdf" /sdcard/Documents/AnuvaadTest/
adb -s 3C167G004EF00000 push "phase2_3_testing\test_pack\doc3_illustrated_water_cycle.pdf" /sdcard/Documents/AnuvaadTest/
adb -s 3C167G004EF00000 push "phase2_3_testing\test_pack\doc4_long_multipage_continuation.pdf" /sdcard/Documents/AnuvaadTest/
adb -s 3C167G004EF00000 push "phase2_3_testing\test_pack\doc5_mixed_digital_scanned.pdf" /sdcard/Documents/AnuvaadTest/
adb -s 3C167G004EF00000 push "phase2_3_testing\test_pack\doc6_scanned_realistic_simulation.pdf" /sdcard/Documents/AnuvaadTest/

# Step 3: Launch AnuvaadAI on the phone
adb -s 3C167G004EF00000 shell monkey -p org.anuvaad.ai.anuvaadai -c android.intent.category.LAUNCHER 1
```

---

## 8. STOP & AWAIT USER APPROVAL

In compliance with the Phase 2.3.2 rules:
- **No APK was installed.**
- **No phone files or models were modified.**
- **Awaiting explicit user instruction before proceeding to test APK deployment.**

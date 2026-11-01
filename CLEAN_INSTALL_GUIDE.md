# AnuvaadAI 2.0 — Physical Device Clean Installation Guide
## Complete Fresh-Installation Procedure for Realme Narzo N55 (Android 13 / Target SDK 36: Android 16)

**Package:** `org.anuvaad.ai.anuvaadai`  
**Target File:** `release/AnuvaadAI-2.0.apk`  
**Compile / Target SDK:** API 36 (Android 16) | Minimum SDK: API 24 (Android 7.0)  
**Prerequisites:** Windows PC with PowerShell, Android Platform Tools (`adb`), USB Cable

---

## 1. Physical Device Preparation

1. On the **Realme Narzo N55**, open **Settings** → **About device** → **Version**.
2. Tap **Build number** 7 times until *"You are now in Developer mode!"* appears.
3. Go back to **Settings** → **System settings** → **Developer options**.
4. Enable **USB debugging**.
5. Connect the phone to your PC using a reliable USB-C cable.
6. When prompted on the phone (*"Allow USB debugging?"*), check **Always allow from this computer** and tap **Allow**.

---

## 2. Definitive 7-Step Fresh Installation Sequence

To guarantee a 100% clean installation where no stale models or old cache can be loaded accidentally, follow this exact 7-step sequence:

### Step 1: Uninstall the Old Application
Removes the existing package completely:
```powershell
adb uninstall org.anuvaad.ai.anuvaadai
```

### Step 2: Remove Only AnuvaadAI-Specific Stale Model Directories
Removes only the application's previous storage folders without touching any other phone directories:
```powershell
adb shell "rm -rf /sdcard/anuvaad-models"
adb shell "rm -rf /sdcard/Android/data/org.anuvaad.ai.anuvaadai"
```

### Step 3: Install the New Signed Release APK
Installs the production APK and grants all required runtime permissions:
```powershell
adb install -r -d "C:\AnuvaadAI Anti\release\AnuvaadAI-2.0.apk"
adb shell pm grant org.anuvaad.ai.anuvaadai android.permission.RECORD_AUDIO
adb shell pm grant org.anuvaad.ai.anuvaadai android.permission.READ_EXTERNAL_STORAGE
adb shell pm grant org.anuvaad.ai.anuvaadai android.permission.WRITE_EXTERNAL_STORAGE
```

### Step 4 & 5: Provision All 19 Model Files & Verify Destination Checksums
Executes the smart provisioning script, which pushes all 19 model files and cryptographically verifies destination SHA-256 hashes on the phone:
```powershell
.\scripts\setup\provision_models.ps1 -CleanFallbackDirectory
```
*Each model file is verified on-device via `sha256sum`. If any hash fails to match the reference manifest, deployment halts immediately.*

### Step 6: Run Device Installation Verification
Audits package installation, permissions, and models:
```powershell
.\scripts\setup\verify_device_installation.ps1
```

### Step 7: Force-Stop and Relaunch Application
Ensures the app boots with clean memory and freshly provisioned storage paths:
```powershell
adb shell am force-stop org.anuvaad.ai.anuvaadai
adb shell am start -n org.anuvaad.ai.anuvaadai/.MainActivity
```

---

## 3. Genuine Offline Speech Recognition Verification

On Android 13 (Realme UI / ColorOS), Google Speech Services returns Error Code 14 because OEM IPC does not report model file status. To genuinely verify offline recognition without false positives from online speech:

1. Open Android **Settings** → **System settings** → **Keyboard & input method** → **Google Voice Typing** → **Offline speech recognition**.
2. Download **Hindi (India)** (~45 MB) and **English (India)** (~48 MB).
3. Open **AnuvaadAI 2.0** → Navigate to **Speech Studio** (`Speak`).
4. Tap **"Acknowledge Setup"**. The status changes to *"Offline Setup Acknowledged (Airplane Mode Test Pending)"*. Red download nagging is permanently silenced.
5. **Turn ON Airplane Mode** on the phone (disconnecting all Wi-Fi and mobile data).
6. Tap the microphone and speak a Hindi sentence (e.g. *"नमस्ते बच्चों"*).
7. When the transcription appears while offline, tap **"Confirm Verified in Airplane Mode"**.
8. The status transitions permanently to **"Offline Speech Recognition Tested & Ready"** (Green).

---

## 4. Post-Installation Classroom Feature Verification

| Feature | Action | Verification Standard |
| :--- | :--- | :--- |
| **1. Model Status** | Open Model & Offline Status | IndicTrans2, Santali VITS, OCR, and TTS all display green **Ready** badges. |
| **2. Teacher Bridge** | Open Teacher Communication Mode | Speak in Hindi → Translates to Santali Ol Chiki → Speaks authentic Santali VITS audio → Automatically pauses mic during playback. |
| **3. Offline Translate**| Translate Hindi → Santali | Instant Ol Chiki translation with valid SentencePiece token sequences. |
| **4. Ol Chiki TTS** | Read Aloud in Speech Studio | Crystal-clear 22kHz 16-bit PCM Santali speech plays through phone speaker. |
| **5. Offline OCR** | Capture camera image of text | Bundled Google ML Kit OCR extracts text instantly without internet connection. |
| **6. Lesson Storage** | Save lesson in Teacher Mode | Persists in `SavedLessonsStore` across phone reboots. |

# AnuvaadAI 2.0 — Offline Speech Recognition Setup Guide
## Target: Realme Narzo N55 (Android 13 / Realme UI / ColorOS)

This guide provides instructions for configuring **100% offline speech recognition (ASR)** for Hindi and English on Realme Narzo N55 and Android 13+ devices.

---

## 1. Understanding Android Speech Recognition Architecture

AnuvaadAI 2.0 leverages Android's native `SpeechRecognizer` backed by **Google Speech Services** (`com.google.android.tts` / `com.google.android.apps.speech.tts.googletts.service.GoogleTTSRecognitionService`).

### The Error Code 14 Explanation
On Android 13 (API Level 33), the system `RecognitionSupportCallback` introduced an automated method to query whether offline language models are installed. However, on Realme UI / ColorOS, the OEM inter-process communication (IPC) layer between third-party apps and Google Speech Services returns:
```
error code: 14 (ERROR_CANNOT_CHECK_SUPPORT)
```
This is **NOT a crash** and does **NOT mean offline speech is broken**. It simply means the OS vendor does not permit automated background interrogation of the offline pack catalog.

### How AnuvaadAI 2.0 Handles Error Code 14
1. **Crash-Proof SafeResult**: MethodChannel single-completion guards prevent duplicate callback exceptions.
2. **Persistent Speech Memory**: Through `SpeechConfigStore`, AnuvaadAI remembers verified setups and live recognition test passes across device reboots and app restarts.
3. **One-Tap Verification**: Once the offline pack is downloaded in system settings, tapping **"Mark as Verified"** suppresses all download prompts permanently.

---

## 2. Step-by-Step Offline Model Installation on Realme Narzo N55

Follow these steps once on the physical phone:

### Step 1: Open Speech Settings
You can either:
- Tap **"Speech Settings"** inside AnuvaadAI's Speech Studio screen, OR
- Manually open Android **Settings** → **System settings** → **Keyboard & input method**.

### Step 2: Navigate to Google Speech Services Offline Packs
1. Tap **Google Voice Typing** (or **Voice Typing / Speech Services by Google**).
2. Tap **Offline speech recognition**.
3. You will see two tabs: **Installed** and **All**.

### Step 3: Download Hindi and English Language Packs
1. Switch to the **All** tab.
2. Scroll to or search for:
   - **Hindi (India)** (`hi-IN`) — ~45 MB
   - **English (India)** (`en-IN`) — ~48 MB
3. Tap the download icon next to each language pack.
4. Ensure the download completes while connected to Wi-Fi or mobile data.
5. Verify that both languages now appear under the **Installed** tab.

### Step 4: Confirm in AnuvaadAI 2.0
1. Open **AnuvaadAI 2.0**.
2. Tap **Speak** (or navigate to **Teacher Communication Mode**).
3. If the prompt shows "Status Unverified (Code 14)", tap **Mark as Verified**.
4. Tap the large microphone icon and speak:
   > *"नमस्ते, आज हम नया पाठ पढ़ेंगे।"*
5. The live text transcription will appear immediately in the box.
6. AnuvaadAI automatically records that the live test passed and persists the offline-ready state!

---

## 3. Native Santali (Ol Chiki) Speech Synthesis (TTS)

Unlike Hindi and English which utilize system speech engines, **Santali speech synthesis is 100% native and self-contained within AnuvaadAI**:
- Uses **Santali Piper VITS neural acoustic model** (`santali_piper_vits.onnx`).
- Employs authentic Ol Chiki phoneme rule mappings (`phoneme_id_map.json`).
- Synthesizes 22,050 Hz 16-bit PCM high-fidelity audio directly on device via ONNX Runtime Mobile.
- Operates with zero network dependency.
- Requires no external download from Google Play or system settings.

---

## 4. Verification Checklist

| Component | Status Check | Target Setting |
| :--- | :--- | :--- |
| **Microphone Permission** | Granted | `android.permission.RECORD_AUDIO` |
| **Hindi Offline Pack** | Installed | Google Speech Services → Offline Speech → Hindi (India) |
| **English Offline Pack** | Installed | Google Speech Services → Offline Speech → English (India) |
| **IndicTrans2 Models** | Provisioned | `/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/models/` |
| **Santali VITS Model** | Provisioned | `/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/santali-tts/` |
| **AnuvaadAI Persistence** | Confirmed | `SpeechConfigStore` reports verified |

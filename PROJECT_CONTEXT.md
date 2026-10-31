# AnuvaadAI 2.0 — Project Context

## Mission
Build a fully offline multilingual education and translation application
for Android and Windows.

## Supported languages
- Hindi: hin_Deva
- English: eng_Latn
- Santali: sat_Olck (Ol Chiki script)

## Required translation directions
1. Hindi -> Santali
2. Santali -> Hindi
3. English -> Santali
4. Santali -> English
5. Hindi -> English
6. English -> Hindi

## Core features
- Offline text translation
- Offline speech recognition
- Offline text-to-speech
- Native Santali TTS (must be genuine Santali speech)
- Hindi and English OCR
- PDF, DOCX and TXT extraction
- Translation of extracted document content
- Offline saved lessons
- Export translated content
- Android and Windows applications

## Non-negotiable requirements
- Final application must function without internet.
- No cloud inference at runtime.
- Never represent transliterated English speech as native Santali TTS.
- Never use fake translation, OCR or speech outputs.
- Preserve source text and provide clear error messages.
- Large model weights must not be committed to normal Git history.
- Test each engine independently before integration.

## Existing assets
Previous project: C:\AnuvaadAI2\
An IndicTrans2 distilled checkpoint of approximately 320M parameters
and previous ONNX exports were available. Inspect before re-downloading.
Do not assume this checkpoint supports all six translation directions.

## Hardware target
Android test phone: Realme Narzo N55, 6 GB RAM.
Windows desktop/laptop support is required.

## Team ownership
- Command center: repository, architecture, contracts, integration, release.
- Translation agent: engines/translation/
- Speech agent: engines/speech_recognition/ and engines/speech_synthesis/
- OCR/documents agent: engines/ocr/, engines/documents/, packages/local_database/
- UI developer: apps/ and packages/ui_components/

## Working rules
- Do not modify another agent's assigned module without approval.
- Do not change shared interfaces without approval.
- Commit focused changes with meaningful messages.
- Report changed files, tests, dependencies and blockers.
- Do not claim a feature works unless it has been tested.

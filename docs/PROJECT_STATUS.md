# AnuvaadAI 2.0 — Project Status

Last updated: Initial setup

## Team assignments

| Workstream | Owner | Branch | Status |
|---|---|---|---|
| Command center and integration | This device | dev | In progress |
| Translation | Codex 1 | feature/translation | Pending |
| Speech | Codex 2 | feature/speech | Pending |
| OCR and documents | Codex 3 | feature/ocr-documents | Pending |
| Flutter UI | Claude Pro | feature/flutter-ui | Pending |

## Translation checklist

- [ ] Inspect existing IndicTrans2 checkpoint
- [ ] Verify Hindi -> Santali
- [ ] Verify Santali -> Hindi
- [ ] Identify English-to-Indic checkpoint
- [ ] Identify Indic-to-English checkpoint
- [ ] Verify English -> Santali
- [ ] Verify Santali -> English
- [ ] Verify Hindi <-> English
- [ ] Android inference
- [ ] Windows inference
- [ ] Offline restart test

## Speech checklist

- [ ] Hindi offline STT
- [ ] English offline STT
- [ ] Evaluate Santali STT
- [ ] Hindi offline TTS
- [ ] English offline TTS
- [ ] Find and validate native Santali TTS
- [ ] Test actual audio output
- [ ] Android and Windows tests

## OCR and documents checklist

- [ ] Hindi OCR
- [ ] English OCR
- [ ] Investigate Ol Chiki OCR
- [ ] PDF text extraction
- [ ] Scanned PDF OCR
- [ ] DOCX extraction
- [ ] TXT extraction
- [ ] Feed extracted content into translation
- [ ] Offline lesson database
- [ ] Export translated content

## UI checklist

- [ ] Translation screen
- [ ] Speech screen
- [ ] Scan/OCR screen
- [ ] Saved lessons
- [ ] Settings and model status
- [ ] Android responsive layout
- [ ] Windows responsive layout

## Release acceptance

- [ ] All six translation directions tested
- [ ] Genuine offline Hindi and English speech
- [ ] Genuine native Santali TTS validated
- [ ] OCR and document workflows tested
- [ ] Saved lessons survive app restart
- [ ] Internet disconnected during acceptance test
- [ ] Android APK built and installed
- [ ] Windows application packaged

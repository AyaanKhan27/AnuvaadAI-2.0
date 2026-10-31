# AnuvaadAI 2.0 — Shared API Contracts

Version: 1.0
Status: Initial contract — changes require command-center approval.

## 1. Language identifiers

| Language | Code |
|---|---|
| Hindi | hin_Deva |
| English | eng_Latn |
| Santali (Ol Chiki) | sat_Olck |

## 2. Translation

Required directions:
- hin_Deva -> sat_Olck
- sat_Olck -> hin_Deva
- eng_Latn -> sat_Olck
- sat_Olck -> eng_Latn
- hin_Deva -> eng_Latn
- eng_Latn -> hin_Deva

TranslationEngine:
- initialize()
- translate(text, sourceLanguage, targetLanguage)
- dispose()

TranslationResult:
- translatedText
- sourceLanguage
- targetLanguage
- processingTimeMs
- engineName

Requirements:
- Must run locally without internet.
- Validate language-pair support before translation.
- Never silently return the original text as a translation.
- Report unsupported directions and model errors explicitly.

## 3. Speech recognition

SpeechRecognitionEngine:
- initialize(language)
- startListening(language)
- stopListening()
- dispose()

SpeechRecognitionResult:
- recognizedText
- language
- processingTimeMs
- engineName

Initial mandatory languages: Hindi and English.
Santali recognition must be evaluated separately and must not be
advertised as supported until validated.

## 4. Speech synthesis

SpeechSynthesisEngine:
- initialize(language)
- speak(text, language)
- stop()
- dispose()

Requirements:
- Offline audio generation/playback.
- Hindi and English offline TTS.
- Native Santali TTS is mandatory for the final requirement.
- Transliteration spoken by another language voice is NOT native Santali TTS.
- Report unsupported language and synthesis errors honestly.

## 5. OCR

OcrEngine:
- initialize()
- extractText(imagePath, language)
- dispose()

OcrResult:
- extractedText
- detectedLanguage
- confidence, when available
- processingTimeMs

Initial mandatory OCR languages: Hindi and English.
Ol Chiki support must be investigated separately.

## 6. Document extraction

DocumentEngine:
- extractText(filePath)

ExtractedDocument:
- text
- fileName
- fileType
- pageCount, when available

Required formats:
- PDF, including scanned PDF through OCR
- DOCX
- TXT

Extracted content must be usable by TranslationEngine.

## 7. Offline lessons

LessonRepository:
- saveLesson(lesson)
- getLessons()
- getLesson(id)
- deleteLesson(id)

Lesson:
- id
- title
- sourceText
- translatedText
- sourceLanguage
- targetLanguage
- createdAt
- sourceType

Use a local database. No cloud dependency.

## 8. Common rules

- All engine interfaces must be asynchronous.
- All engines must expose initialization errors.
- Provide clear errors for missing models, unsupported languages,
  invalid input and insufficient memory.
- No cloud inference or runtime internet dependency.
- Do not load every large model simultaneously.
- Model paths must be configurable.
- UI must call services through dependency injection.
- UI developers must use mock services only for visual development.
- Mock services must never be presented as real AI results.

## 9. Integration rules

- Shared interface changes require command-center approval.
- Each team owns its assigned module.
- Each module must include independent tests.
- Every implementation report must list changed files,
  dependencies, tests, results and known limitations.

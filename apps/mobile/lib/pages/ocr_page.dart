import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../app_theme.dart';
import '../services/speech_service.dart';
import 'translate_page.dart';

class OcrPage extends StatefulWidget {
  const OcrPage({super.key});

  @override
  State<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends State<OcrPage> {
  final _textController = TextEditingController();
  final _picker = ImagePicker();
  bool _isProcessing = false;
  String? _errorMessage;
  XFile? _image;
  TextRecognitionScript _script = TextRecognitionScript.devanagiri;

  Future<void> _scan(ImageSource source) async {
    setState(() {
      _errorMessage = null;
      _isProcessing = true;
    });
    try {
      final file = await _picker.pickImage(source: source);
      if (file == null) {
        setState(() => _isProcessing = false);
        return;
      }
      _image = file;
      final inputImage = InputImage.fromFilePath(file.path);
      final recognizer = TextRecognizer(script: _script);
      try {
        final recognized = await recognizer.processImage(inputImage);
        if (!mounted) return;
        setState(() {
          _textController.text = recognized.text;
          _isProcessing = false;
        });
      } finally {
        await recognizer.close();
      }
    } catch (e) {
      if (!mounted) return;
      final lower = e.toString().toLowerCase();
      final modelNotReady = lower.contains('model') ||
          lower.contains('download') ||
          lower.contains('unavailable') ||
          lower.contains('not found');
      setState(() {
        _isProcessing = false;
        _errorMessage = modelNotReady
            ? 'OCR model is downloading or not yet indexed. Text can be manually edited or typed below.'
            : 'OCR failed: $e';
      });
    }
  }

  void _translate() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recognized text is empty.')),
      );
      return;
    }

    final srcLang = _script == TextRecognitionScript.devanagiri ? 'hin_Deva' : 'eng_Latn';

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TranslatePage(
          initialText: text,
          initialSrcLang: srcLang,
          initialTgtLang: 'sat_Olck',
        ),
      ),
    );
  }

  Future<void> _readAloud() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final lang = _script == TextRecognitionScript.devanagiri ? 'hin_Deva' : 'eng_Latn';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Playing offline audio...')),
    );
    await SpeechService.speak(text, lang: lang);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan & OCR Studio')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.font_download_rounded, color: AppColors.forest),
                          SizedBox(width: 12),
                          Text('Recognition Script:', style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      DropdownButton<TextRecognitionScript>(
                        value: _script,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                            value: TextRecognitionScript.devanagiri,
                            child: Text('Devanagari (Hindi)'),
                          ),
                          DropdownMenuItem(
                            value: TextRecognitionScript.latin,
                            child: Text('Latin (English)'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _script = v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isProcessing ? null : () => _scan(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : () => _scan(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isProcessing)
                const Center(child: CircularProgressIndicator()),
              if (_image != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Selected image: ${_image!.name}',
                    style: const TextStyle(color: AppColors.forest, fontWeight: FontWeight.w600),
                  ),
                ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.terracotta),
                  ),
                ),
              TextField(
                controller: _textController,
                minLines: 6,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'Recognized Text (editable)',
                  hintText: 'OCR extraction results will appear here…',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _textController.text.isEmpty ? null : _translate,
                      icon: const Icon(Icons.translate_rounded),
                      label: const Text('Translate'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _textController.text.isEmpty ? null : _readAloud,
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('Read Aloud'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Uses on-device ML Kit OCR without cloud dependence. Recognized text can be corrected before translation or speech synthesis.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

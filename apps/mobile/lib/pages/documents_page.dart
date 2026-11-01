import 'dart:io';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../services/document_service.dart';
import '../services/speech_service.dart';
import 'translate_page.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final _pathController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isProcessing = false;
  String? _errorMessage;
  String? _currentFileName;
  String? _currentFileType;

  @override
  void dispose() {
    _pathController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _extractFromPath(String path) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('File does not exist: $path');
      }

      final doc = await DocumentService.extractTextFromFile(file);
      if (!mounted) return;

      setState(() {
        _currentFileName = doc.fileName;
        _currentFileType = doc.fileType;
        _contentController.text = doc.content;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Extraction failed: $e';
      });
    }
  }

  void _loadSampleDocument(String type) {
    String sampleContent = '';
    String sampleName = '';

    if (type == 'hindi_lesson') {
      sampleName = 'sample_hindi_lesson.txt';
      sampleContent = 'नमस्ते बच्चों। आज हम सब मिलकर नई भाषा सीखेंगे। ज्ञान ही शक्ति है।';
    } else if (type == 'english_worksheet') {
      sampleName = 'english_curriculum.txt';
      sampleContent = 'Hello children. Today we learn about nature and community in our classroom.';
    } else if (type == 'santali_reading') {
      sampleName = 'santali_reader.txt';
      sampleContent = 'ᱦᱮᱞᱳ ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱾ ᱟᱞᱮ ᱟᱹᱰᱤ ᱨᱟᱹᱥᱠᱟᱹ ᱛᱮ ᱥᱮᱪᱮᱫᱚᱜ ᱠᱟᱱᱟ ᱾';
    }

    setState(() {
      _currentFileName = sampleName;
      _currentFileType = 'TXT';
      _contentController.text = sampleContent;
      _errorMessage = null;
    });
  }

  void _translateExtracted() {
    final text = _contentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No extracted text to translate.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TranslatePage(initialText: text),
      ),
    );
  }

  Future<void> _readAloud() async {
    final text = _contentController.text.trim();
    if (text.isEmpty) return;

    // Detect script for appropriate TTS
    final isOlChiki = text.codeUnits.any((c) => c >= 0x1C50 && c <= 0x1C7F);
    final lang = isOlChiki ? 'sat_Olck' : 'hin_Deva';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Speaking offline (${isOlChiki ? 'Santali' : 'Hindi'})...')),
    );
    await SpeechService.speak(text, lang: lang);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Document Extraction')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offline Document Processor',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Extract readable text from PDF, Word (DOCX), or plain text files without internet.',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _pathController,
                        decoration: InputDecoration(
                          labelText: 'Document File Path',
                          hintText: '/sdcard/Download/lesson.docx or .pdf',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.file_open_rounded),
                            tooltip: 'Load File',
                            onPressed: _isProcessing
                                ? null
                                : () {
                                    final path = _pathController.text.trim();
                                    if (path.isNotEmpty) _extractFromPath(path);
                                  },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sample Classroom Documents:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.menu_book_rounded, size: 16),
                    label: const Text('Hindi Lesson'),
                    onPressed: () => _loadSampleDocument('hindi_lesson'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.school_rounded, size: 16),
                    label: const Text('English Curriculum'),
                    onPressed: () => _loadSampleDocument('english_worksheet'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.translate_rounded, size: 16),
                    label: const Text('Santali Ol Chiki Reader'),
                    onPressed: () => _loadSampleDocument('santali_reading'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isProcessing)
                const Center(child: CircularProgressIndicator())
              else if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.terracotta),
                  ),
                ),
              if (_currentFileName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Extracted from: $_currentFileName ($_currentFileType)',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.forest),
                  ),
                ),
              TextField(
                controller: _contentController,
                minLines: 8,
                maxLines: 14,
                decoration: const InputDecoration(
                  labelText: 'Extracted Document Content (editable)',
                  hintText: 'Document text will appear here ready for translation.',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _contentController.text.isEmpty ? null : _translateExtracted,
                      icon: const Icon(Icons.translate_rounded),
                      label: const Text('Translate'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _contentController.text.isEmpty ? null : _readAloud,
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('Read Aloud'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

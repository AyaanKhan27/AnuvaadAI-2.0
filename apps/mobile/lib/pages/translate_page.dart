import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../data/history_store.dart';
import '../data/saved_lesson.dart';
import '../services/speech_service.dart';
import '../services/translation_directions.dart';
import '../services/translation_service.dart';
import '../widgets/brand_mark.dart';
import 'history_page.dart';

class TranslatePage extends StatefulWidget {
  const TranslatePage({
    super.key,
    this.initialText,
    this.initialSrcLang = 'hin_Deva',
    this.initialTgtLang = 'sat_Olck',
  });

  final String? initialText;
  final String initialSrcLang;
  final String initialTgtLang;

  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage> {
  final _inputController = TextEditingController();
  final _outputController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  static const Map<String, String> _languages = {
    'hin_Deva': 'Hindi (Devanagari)',
    'sat_Olck': 'Santali (Ol Chiki)',
    'eng_Latn': 'English (Latin)',
  };

  String _srcLang = 'hin_Deva';
  String _tgtLang = 'sat_Olck';

  @override
  void initState() {
    super.initState();
    _srcLang = widget.initialSrcLang;
    _tgtLang = widget.initialTgtLang;
    if (widget.initialText != null) {
      _inputController.text = widget.initialText!;
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  int _characterCount(String value) => value.runes.length;

  Future<void> _translate() async {
    if (_isLoading) return;
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _errorMessage = 'Enter source text before translating.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
      _outputController.clear();
    });

    try {
      final result = await TranslationService.translate(
        input,
        srcLang: _srcLang,
        tgtLang: _tgtLang,
      );
      if (!mounted) return;
      setState(() {
        _outputController.text = result.text;
        _isLoading = false;
      });

      // Record in offline history
      await HistoryStore.add(
        sourceText: input,
        translatedText: result.text,
        sourceLang: _srcLang,
        targetLang: _tgtLang,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? 'Translation failed.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Translation failed: $e';
      });
    }
  }

  Future<void> _cancel() async {
    await TranslationService.cancel();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = 'Translation cancelled.';
    });
  }

  void _clear() {
    _inputController.clear();
    _outputController.clear();
    setState(() => _errorMessage = null);
  }

  void _swapLanguages() {
    final temp = _srcLang;
    final tempText = _inputController.text;
    setState(() {
      _srcLang = _tgtLang;
      _tgtLang = temp;
      _inputController.text = _outputController.text;
      _outputController.text = tempText;
      _errorMessage = null;
    });
  }

  Future<void> _speakOutput() async {
    final text = _outputController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There is no target text to speak yet.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Playing offline audio (${_languages[_tgtLang]})...')),
    );
    final ok = await SpeechService.speak(text, lang: _tgtLang);
    if (!ok && mounted && _tgtLang == 'sat_Olck') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Santali TTS model is loading or not present in storage.')),
      );
    }
  }

  Future<void> _speakInput() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    await SpeechService.speak(text, lang: _srcLang);
  }

  Future<void> _copyOutput() async {
    final text = _outputController.text;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There is no target text to copy yet.')),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Target text copied to clipboard.')),
    );
  }

  Future<void> _saveLesson() async {
    final sourceText = _inputController.text.trim();
    final targetText = _outputController.text.trim();
    if (sourceText.isEmpty || targetText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add source and target text before saving a lesson.'),
        ),
      );
      return;
    }

    try {
      await SavedLessonsStore.save(
        hindiText: sourceText,
        santaliText: targetText,
        sourceLang: _srcLang,
        targetLang: _tgtLang,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lesson saved locally on device.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save lesson: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSupported = TranslationDirections.isSupported(_srcLang, _tgtLang);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const BrandMark(compact: true),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HistoryPage()),
            ),
          ),
          IconButton(
            tooltip: 'Clear All',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _clear,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LanguageHeader(
                srcLang: _srcLang,
                tgtLang: _tgtLang,
                onSrcChanged: (v) => setState(() => _srcLang = v ?? _srcLang),
                onTgtChanged: (v) => setState(() => _tgtLang = v ?? _tgtLang),
                onSwap: _swapLanguages,
              ),
              const SizedBox(height: 14),
              if (!isSupported)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.paleTerracotta,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.terracotta, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Direction $_srcLang → $_tgtLang requires the companion indic-en model checkpoint.',
                          style: const TextStyle(color: AppColors.charcoal, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              _TextPanel(
                title: 'Source Text',
                characterCount: _characterCount(_inputController.text),
                hint: 'Type, speak, or paste text to translate…',
                controller: _inputController,
                minLines: 4,
                maxLines: 8,
                onChanged: (_) => setState(() {}),
                trailing: IconButton(
                  icon: const Icon(Icons.volume_up_outlined, size: 20),
                  tooltip: 'Listen to source',
                  onPressed: _speakInput,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isLoading || !isSupported ? null : _translate,
                      icon: const Icon(Icons.translate_rounded),
                      label: Text(_isLoading ? 'Translating…' : 'Translate'),
                    ),
                  ),
                  if (_isLoading) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _cancel,
                      child: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              if (_isLoading)
                const _LoadingNotice()
              else if (_errorMessage != null)
                _ErrorNotice(message: _errorMessage!),
              const SizedBox(height: 8),
              _TextPanel(
                title: 'Translation Result',
                characterCount: _characterCount(_outputController.text),
                hint: 'Translation will appear here offline.',
                controller: _outputController,
                minLines: 4,
                maxLines: 8,
                onChanged: (_) => setState(() {}),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded, color: AppColors.forest),
                      tooltip: 'Speak translation (Offline)',
                      onPressed: _speakOutput,
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      tooltip: 'Copy',
                      onPressed: _copyOutput,
                    ),
                    IconButton(
                      icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                      tooltip: 'Save Lesson',
                      onPressed: _saveLesson,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageHeader extends StatelessWidget {
  const _LanguageHeader({
    required this.srcLang,
    required this.tgtLang,
    required this.onSrcChanged,
    required this.onTgtChanged,
    required this.onSwap,
  });

  final String srcLang;
  final String tgtLang;
  final ValueChanged<String?> onSrcChanged;
  final ValueChanged<String?> onTgtChanged;
  final VoidCallback onSwap;

  static const Map<String, String> _languages = {
    'hin_Deva': 'Hindi (Deva)',
    'sat_Olck': 'Santali (Olck)',
    'eng_Latn': 'English (Latin)',
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: srcLang,
                  isExpanded: true,
                  items: _languages.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w700))))
                      .toList(),
                  onChanged: onSrcChanged,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.terracotta),
              tooltip: 'Swap Languages',
              onPressed: onSwap,
            ),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: tgtLang,
                  isExpanded: true,
                  items: _languages.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w700))))
                      .toList(),
                  onChanged: onTgtChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextPanel extends StatelessWidget {
  const _TextPanel({
    required this.title,
    required this.characterCount,
    required this.hint,
    required this.controller,
    required this.minLines,
    required this.maxLines,
    required this.onChanged,
    this.trailing,
  });

  final String title;
  final int characterCount;
  final String hint;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;
  final ValueChanged<String> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '$characterCount chars',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                if (trailing != null) ...[const SizedBox(width: 4), trailing!],
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              minLines: minLines,
              maxLines: maxLines,
              keyboardType: TextInputType.multiline,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingNotice extends StatelessWidget {
  const _LoadingNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paleGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Translating offline with ONNX Runtime…', style: TextStyle(color: AppColors.forest, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paleTerracotta,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.terracotta, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.terracotta, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

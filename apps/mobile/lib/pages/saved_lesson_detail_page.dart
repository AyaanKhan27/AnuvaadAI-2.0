import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../data/saved_lesson.dart';
import '../services/speech_service.dart';
import '../widgets/brand_mark.dart';
import 'translate_page.dart';

class SavedLessonDetailPage extends StatefulWidget {
  const SavedLessonDetailPage({super.key, required this.lesson});

  final SavedLesson lesson;

  @override
  State<SavedLessonDetailPage> createState() => _SavedLessonDetailPageState();
}

class _SavedLessonDetailPageState extends State<SavedLessonDetailPage> {
  late final TextEditingController _santaliController;
  bool _isSaving = false;

  bool get _hasChanges => _santaliController.text != widget.lesson.santaliText;

  @override
  void initState() {
    super.initState();
    _santaliController = TextEditingController(text: widget.lesson.santaliText);
  }

  @override
  void dispose() {
    _santaliController.dispose();
    super.dispose();
  }

  Future<void> _copy(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  void _speak(String text, String lang) {
    SpeechService.speak(text, lang: lang);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Playing offline audio...')),
    );
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await SavedLessonsStore.update(
        widget.lesson.copyWith(santaliText: _santaliController.text),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your edits.')),
      );
    }
  }

  String _formatDate(BuildContext context) =>
      MaterialLocalizations.of(context).formatMediumDate(widget.lesson.savedAt);

  @override
  Widget build(BuildContext context) {
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
            tooltip: 'Open in Translate',
            icon: const Icon(Icons.translate_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TranslatePage(
                  initialText: widget.lesson.hindiText,
                  initialSrcLang: widget.lesson.sourceLang,
                  initialTgtLang: widget.lesson.targetLang,
                ),
              ),
            ),
          ),
          if (_hasChanges)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveChanges,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 420 ? 16.0 : 24.0;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                14,
                horizontalPadding,
                28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.lesson.title.isNotEmpty ? widget.lesson.title : 'Saved Lesson',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Saved ${_formatDate(context)} • ${widget.lesson.sourceLang} → ${widget.lesson.targetLang}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 20),
                      _TextCard(
                        title: 'Source Text',
                        text: widget.lesson.hindiText,
                        onCopy: () => _copy(widget.lesson.hindiText, 'Source text'),
                        onSpeak: () => _speak(widget.lesson.hindiText, widget.lesson.sourceLang),
                      ),
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Santali Translation (Ol Chiki)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Listen to Santali (Offline VITS)',
                                    onPressed: () => _speak(_santaliController.text, 'sat_Olck'),
                                    icon: const Icon(Icons.volume_up_rounded),
                                    color: AppColors.forest,
                                  ),
                                  IconButton(
                                    tooltip: 'Copy Santali text',
                                    onPressed: () => _copy(_santaliController.text, 'Santali text'),
                                    icon: const Icon(Icons.content_copy_rounded),
                                    color: AppColors.forest,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _santaliController,
                                minLines: 5,
                                maxLines: 12,
                                keyboardType: TextInputType.multiline,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText: 'Edit Santali text',
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Edits stay permanently saved on this device.',
                                style: TextStyle(color: AppColors.muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_hasChanges) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _saveChanges,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save edits'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({
    required this.title,
    required this.text,
    required this.onCopy,
    required this.onSpeak,
  });

  final String title;
  final String text;
  final VoidCallback onCopy;
  final VoidCallback onSpeak;

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
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                IconButton(
                  tooltip: 'Speak',
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up_outlined),
                  color: AppColors.forest,
                ),
                IconButton(
                  tooltip: 'Copy',
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy_rounded),
                  color: AppColors.forest,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(text, style: const TextStyle(height: 1.55)),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../data/history_store.dart';
import '../services/speech_service.dart';
import 'translate_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<HistoryItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final items = await HistoryStore.getAll();
    if (!mounted) return;
    setState(() {
      _history = items;
      _isLoading = false;
    });
  }

  Future<void> _deleteItem(String id) async {
    await HistoryStore.delete(id);
    _loadHistory();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all translation history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirm == true) {
      await HistoryStore.clear();
      _loadHistory();
    }
  }

  void _speak(String text, String lang) {
    SpeechService.speak(text, lang: lang);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Playing audio offline...')),
    );
  }

  void _openTranslate(HistoryItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TranslatePage(
          initialText: item.sourceText,
          initialSrcLang: item.sourceLang,
          initialTgtLang: item.targetLang,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Translation History'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Clear All',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _history.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded, size: 64, color: AppColors.muted),
                          SizedBox(height: 12),
                          Text(
                            'No translation history yet.',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.charcoal),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Translations you perform will be saved here for offline review.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _history.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.paleGreen,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${item.sourceLang} → ${item.targetLang}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.forest,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${item.createdAt.hour}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    onPressed: () => _deleteItem(item.id),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.sourceText,
                                style: const TextStyle(fontSize: 14, color: AppColors.muted),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.translatedText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.charcoal,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.volume_up_rounded, size: 20),
                                    tooltip: 'Speak translation',
                                    onPressed: () => _speak(item.translatedText, item.targetLang),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 20),
                                    tooltip: 'Copy',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: item.translatedText));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Copied to clipboard')),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                                    tooltip: 'Open in Translate',
                                    onPressed: () => _openTranslate(item),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

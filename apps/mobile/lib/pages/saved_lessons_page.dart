import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/saved_lesson.dart';
import '../widgets/brand_mark.dart';
import 'saved_lesson_detail_page.dart';

class SavedLessonsPage extends StatefulWidget {
  const SavedLessonsPage({super.key});

  @override
  State<SavedLessonsPage> createState() => _SavedLessonsPageState();
}

class _SavedLessonsPageState extends State<SavedLessonsPage> {
  List<SavedLesson> _lessons = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedFilterIndex = 0; // 0 = All, 1 = Text Lessons, 2 = PDF Course Materials

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final lessons = await SavedLessonsStore.load();
      if (!mounted) return;
      setState(() {
        _lessons = lessons;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Saved lessons could not be loaded. Please try again.';
      });
    }
  }

  Future<void> _openLesson(SavedLesson lesson) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SavedLessonDetailPage(lesson: lesson),
      ),
    );
    if (changed == true) await _loadLessons();
  }

  Future<void> _deleteLesson(SavedLesson lesson) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lesson.isPdfDocument ? 'Delete course material?' : 'Delete saved lesson?'),
        content: Text(
          lesson.isPdfDocument
              ? 'This converted PDF course material (${lesson.title}) will be removed from this device.'
              : 'This lesson will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      await SavedLessonsStore.delete(lesson.id);
      if (!mounted) return;
      setState(() => _lessons.removeWhere((saved) => saved.id == lesson.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lesson.isPdfDocument ? 'Course material deleted.' : 'Lesson deleted.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete this item.')),
      );
    }
  }

  String _formatDate(BuildContext context, DateTime date) =>
      MaterialLocalizations.of(context).formatMediumDate(date);

  List<SavedLesson> get _filteredLessons {
    if (_selectedFilterIndex == 1) {
      return _lessons.where((l) => !l.isPdfDocument).toList();
    } else if (_selectedFilterIndex == 2) {
      return _lessons.where((l) => l.isPdfDocument).toList();
    }
    return _lessons;
  }

  @override
  Widget build(BuildContext context) {
    final pdfCount = _lessons.where((l) => l.isPdfDocument).length;
    final textCount = _lessons.where((l) => !l.isPdfDocument).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const BrandMark(compact: true),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Classroom Materials & Lessons',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Offline converted PDF textbooks, worksheets, and saved lesson translations.',
                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: Text('All (${_lessons.length})'),
                          selected: _selectedFilterIndex == 0,
                          onSelected: (val) {
                            if (val) setState(() => _selectedFilterIndex = 0);
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          avatar: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                          label: Text('PDF Course Materials ($pdfCount)'),
                          selected: _selectedFilterIndex == 2,
                          onSelected: (val) {
                            if (val) setState(() => _selectedFilterIndex = 2);
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          avatar: const Icon(Icons.article_outlined, size: 16),
                          label: Text('Text Lessons ($textCount)'),
                          selected: _selectedFilterIndex == 1,
                          onSelected: (val) {
                            if (val) setState(() => _selectedFilterIndex = 1);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildContent(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage case final message?) {
      return Center(
        child: _InfoCard(
          icon: Icons.error_outline_rounded,
          title: 'Could not open lessons',
          message: message,
          action: FilledButton.tonalIcon(
            onPressed: _loadLessons,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ),
      );
    }

    final displayList = _filteredLessons;

    if (displayList.isEmpty) {
      return Center(
        child: _InfoCard(
          icon: _selectedFilterIndex == 2
              ? Icons.picture_as_pdf_outlined
              : Icons.bookmarks_outlined,
          title: _selectedFilterIndex == 2
              ? 'No PDF Course Materials yet'
              : 'No saved lessons yet',
          message: _selectedFilterIndex == 2
              ? 'Convert a Hindi PDF in the PDF-to-Santali Studio and tap "Save to Course Materials".'
              : 'Translate classroom text in Translate Studio and save it here.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLessons,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: displayList.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final lesson = displayList[index];
          final isPdf = lesson.isPdfDocument;

          return Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            elevation: isPdf ? 1.5 : 0.8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isPdf ? AppColors.forest.withValues(alpha: 0.35) : AppColors.line,
                width: isPdf ? 1.2 : 0.8,
              ),
            ),
            child: InkWell(
              onTap: () => _openLesson(lesson),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPdf ? Icons.picture_as_pdf_rounded : Icons.bookmark_rounded,
                          size: 18,
                          color: isPdf ? AppColors.terracotta : AppColors.forest,
                        ),
                        const SizedBox(width: 8),
                        if (isPdf) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.paleGreen,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${lesson.category} • ${lesson.pageCount ?? 1} pgs',
                              style: const TextStyle(
                                color: AppColors.forest,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            _formatDate(context, lesson.savedAt),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete item',
                          onPressed: () => _deleteLesson(lesson),
                          icon: const Icon(Icons.delete_outline_rounded),
                          color: AppColors.terracotta,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lesson.title.isNotEmpty ? lesson.title : lesson.hindiText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      lesson.santaliText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    if (isPdf && lesson.translatedPdfPath != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.folder_open_rounded, size: 14, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              lesson.translatedPdfPath!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          isPdf ? 'View Course Material' : 'Open lesson',
                          style: TextStyle(
                            color: isPdf ? AppColors.forest : AppColors.forest,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: AppColors.forest,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.forest),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.5),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

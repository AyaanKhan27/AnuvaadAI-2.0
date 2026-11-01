import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../widgets/action_card.dart';
import '../widgets/brand_mark.dart';
import '../widgets/section_heading.dart';
import 'documents_page.dart';
import 'pdf_translation_studio_page.dart';
import 'history_page.dart';
import 'model_status_page.dart';
import 'ocr_page.dart';
import 'saved_lessons_page.dart';
import 'settings_page.dart';
import 'speak_page.dart';
import 'teacher_communication_page.dart';
import 'translate_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            final pagePadding = isWide ? 32.0 : 20.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    pagePadding,
                    isWide ? 26 : 18,
                    pagePadding,
                    34,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TopBar(
                        onSavedLessons: () => _open(context, const SavedLessonsPage()),
                        onHistory: () => _open(context, const HistoryPage()),
                        onStatus: () => _open(context, const ModelStatusPage()),
                        onSettings: () => _open(context, const SettingsPage()),
                      ),
                      const SizedBox(height: 32),
                      _WelcomePanel(isWide: isWide),
                      const SizedBox(height: 20),
                      _TeacherBridgeHero(
                        onTap: () => _open(context, const TeacherCommunicationPage()),
                      ),
                      const SizedBox(height: 14),
                      _PdfStudioHero(
                        onTap: () => _open(context, const PdfTranslationStudioPage()),
                      ),
                      const SizedBox(height: 28),
                      SectionHeading(
                        title: 'Classroom Learning Studios',
                        action: isWide
                            ? TextButton.icon(
                                onPressed: () => _open(context, const SavedLessonsPage()),
                                icon: const Icon(Icons.bookmarks_outlined),
                                label: const Text('Saved lessons'),
                              )
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _ActionGrid(
                        availableWidth: (constraints.maxWidth - pagePadding * 2).clamp(0, 1180),
                        onTranslate: () => _open(context, const TranslatePage()),
                        onSpeak: () => _open(context, const SpeakPage()),
                        onScan: () => _open(context, const OcrPage()),
                        onDocuments: () => _open(context, const DocumentsPage()),
                      ),
                      const SizedBox(height: 26),
                      SectionHeading(title: 'Classroom Tools & Storage'),
                      const SizedBox(height: 12),
                      _QuickLink(
                        icon: Icons.bookmarks_outlined,
                        title: 'Saved Lessons',
                        subtitle: 'Review and manage curated classroom lessons',
                        onTap: () => _open(context, const SavedLessonsPage()),
                      ),
                      const SizedBox(height: 10),
                      _QuickLink(
                        icon: Icons.history_rounded,
                        title: 'Translation History',
                        subtitle: 'View, copy, and replay recent translations offline',
                        onTap: () => _open(context, const HistoryPage()),
                      ),
                      const SizedBox(height: 10),
                      _QuickLink(
                        icon: Icons.picture_as_pdf_rounded,
                        title: 'PDF-to-Santali Document Studio',
                        subtitle: 'Multi-page layout preservation & Ol Chiki PDF export',
                        onTap: () => _open(context, const PdfTranslationStudioPage()),
                      ),
                      const SizedBox(height: 10),
                      _QuickLink(
                        icon: Icons.offline_pin_outlined,
                        title: 'Model & Offline Status',
                        subtitle: 'Diagnostics for IndicTrans2, Santali VITS, OCR, and TTS',
                        onTap: () => _open(context, const ModelStatusPage()),
                      ),
                      const SizedBox(height: 10),
                      _QuickLink(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        subtitle: 'App preferences and system information',
                        onTap: () => _open(context, const SettingsPage()),
                      ),
                      const SizedBox(height: 26),
                      const _FooterNote(),
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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onSavedLessons,
    required this.onHistory,
    required this.onStatus,
    required this.onSettings,
  });

  final VoidCallback onSavedLessons;
  final VoidCallback onHistory;
  final VoidCallback onStatus;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BrandMark(),
        const Spacer(),
        IconButton.filledTonal(
          tooltip: 'Translation History',
          onPressed: onHistory,
          icon: const Icon(Icons.history_rounded),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Offline Status',
          onPressed: onStatus,
          icon: const Icon(Icons.speed_rounded),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Settings',
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Offline Classroom Translation 2.0',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'AnuvaadAI 2.0',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Complete offline translation and speech system supporting Hindi, English, and Santali (Ol Chiki).',
          style: TextStyle(color: Color(0xFFE0EAE3), height: 1.45, fontSize: 14),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWide ? 28 : 20),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: isWide
          ? Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 24),
                const _WelcomeIllustration(),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: 20),
                const Center(child: _WelcomeIllustration()),
              ],
            ),
    );
  }
}

class _WelcomeIllustration extends StatelessWidget {
  const _WelcomeIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Icon(Icons.translate_rounded, color: AppColors.cream, size: 36),
          Icon(Icons.record_voice_over_rounded, color: Color(0xFFF4B49D), size: 36),
          Icon(Icons.document_scanner_rounded, color: Color(0xFFD5E5DC), size: 36),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.availableWidth,
    required this.onTranslate,
    required this.onSpeak,
    required this.onScan,
    required this.onDocuments,
  });

  final double availableWidth;
  final VoidCallback onTranslate;
  final VoidCallback onSpeak;
  final VoidCallback onScan;
  final VoidCallback onDocuments;

  @override
  Widget build(BuildContext context) {
    final columns = availableWidth >= 900 ? 4 : availableWidth >= 560 ? 2 : 1;
    const spacing = 14.0;
    final cardWidth = (availableWidth - spacing * (columns - 1)) / columns;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        SizedBox(
          width: cardWidth,
          height: 210,
          child: ActionCard(
            title: 'Translate',
            description: 'Offline neural translation between Hindi, English, and Santali.',
            icon: Icons.translate_rounded,
            tint: AppColors.paleGreen,
            onTap: onTranslate,
          ),
        ),
        SizedBox(
          width: cardWidth,
          height: 210,
          child: ActionCard(
            title: 'Speak',
            description: 'Speech recognition & authentic Santali Ol Chiki neural voice.',
            icon: Icons.record_voice_over_rounded,
            tint: AppColors.paleTerracotta,
            onTap: onSpeak,
          ),
        ),
        SizedBox(
          width: cardWidth,
          height: 210,
          child: ActionCard(
            title: 'Scan / OCR',
            description: 'On-device camera & image text recognition for worksheets.',
            icon: Icons.document_scanner_outlined,
            tint: const Color(0xFFE8EBF5),
            onTap: onScan,
          ),
        ),
        SizedBox(
          width: cardWidth,
          height: 210,
          child: ActionCard(
            title: 'Documents',
            description: 'Offline text extraction from PDF, DOCX, and TXT materials.',
            icon: Icons.description_outlined,
            tint: const Color(0xFFFFF2DF),
            onTap: onDocuments,
          ),
        ),
      ],
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.forest),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.auto_awesome_outlined, size: 17, color: AppColors.terracotta),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Built with care for multilingual classrooms.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TeacherBridgeHero extends StatelessWidget {
  const _TeacherBridgeHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2C5E43), Color(0xFF1E4330)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.forest.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.terracotta,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.terracotta.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'LIVE CLASSROOM BRIDGE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Text(
                          'Hindi → Santali',
                          style: TextStyle(color: Color(0xFFE0EAE3), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Teacher Communication Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Continuous teacher speech recognition translated & spoken in authentic Ol Chiki neural audio.',
                      style: TextStyle(color: Color(0xFFE0EAE3), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfStudioHero extends StatelessWidget {
  const _PdfStudioHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF334E68), Color(0xFF1F2D3D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'PDF-to-Santali Studio',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD5E5DC),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Color(0xFF1E4330),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Multi-page PDF translation with structural preservation (headings, tables, lists) & Ol Chiki PDF export.',
                      style: TextStyle(
                        color: Color(0xFFD9E2EC),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white70,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

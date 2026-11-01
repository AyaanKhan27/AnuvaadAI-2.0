import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/section_heading.dart';
import 'model_status_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
            tooltip: 'Model Status',
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ModelStatusPage()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pagePadding = constraints.maxWidth < 420 ? 16.0 : 24.0;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(pagePadding, 16, pagePadding, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings & Diagnostics',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _AppInfoCard(),
                      const SizedBox(height: 24),
                      Card(
                        color: AppColors.paleGreen,
                        child: ListTile(
                          leading: const Icon(Icons.speed_rounded, color: AppColors.forest, size: 28),
                          title: const Text('Model & Engine Diagnostics', style: TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: const Text('View offline status of neural models, ASR, TTS and OCR'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const ModelStatusPage()),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const SectionHeading(title: 'Offline Readiness Architecture'),
                      const SizedBox(height: 8),
                      const _ReadinessNotice(),
                      const SizedBox(height: 14),
                      const _FeatureStatusCard(
                        icon: Icons.translate_rounded,
                        title: 'Hindi ↔ Santali Neural Translation',
                        status: 'Integrated & Operational',
                        statusColor: AppColors.forest,
                        statusBackground: AppColors.paleGreen,
                        detail: 'Local ONNX Runtime mobile inference with KV-caching and Viterbi segmentation.',
                      ),
                      const SizedBox(height: 10),
                      const _FeatureStatusCard(
                        icon: Icons.translate_rounded,
                        title: 'English → Santali & English → Hindi',
                        status: 'Integrated & Operational',
                        statusColor: AppColors.forest,
                        statusBackground: AppColors.paleGreen,
                        detail: 'On-device IndicTrans2 English-to-Indic distilled ONNX engine.',
                      ),
                      const SizedBox(height: 10),
                      const _FeatureStatusCard(
                        icon: Icons.record_voice_over_rounded,
                        title: 'Native Santali Speech Synthesis (TTS)',
                        status: 'Integrated & Operational',
                        statusColor: AppColors.forest,
                        statusBackground: AppColors.paleGreen,
                        detail: 'Authentic Ol Chiki VITS neural synthesizer running at 22,050 Hz PCM.',
                      ),
                      const SizedBox(height: 10),
                      const _FeatureStatusCard(
                        icon: Icons.mic_rounded,
                        title: 'Offline Speech Recognition (ASR)',
                        status: 'Integrated & Operational',
                        statusColor: AppColors.forest,
                        statusBackground: AppColors.paleGreen,
                        detail: 'On-device Android SpeechRecognizer with offline language model fallback.',
                      ),
                      const SizedBox(height: 10),
                      const _FeatureStatusCard(
                        icon: Icons.document_scanner_outlined,
                        title: 'Camera & Document OCR',
                        status: 'Integrated & Operational',
                        statusColor: AppColors.forest,
                        statusBackground: AppColors.paleGreen,
                        detail: 'Google ML Kit vision engine bundled for Devanagari and Latin scripts.',
                      ),
                      const SizedBox(height: 10),
                      const _FeatureStatusCard(
                        icon: Icons.description_outlined,
                        title: 'Document Extraction (PDF, DOCX, TXT)',
                        status: 'Integrated & Operational',
                        statusColor: AppColors.forest,
                        statusBackground: AppColors.paleGreen,
                        detail: 'Offline document parser with direct routing to translation and lesson studio.',
                      ),
                      const SizedBox(height: 10),
                      const _FeatureStatusCard(
                        icon: Icons.bookmarks_outlined,
                        title: 'Saved Lessons & History',
                        status: 'Integrated & Operational',
                        statusColor: AppColors.forest,
                        statusBackground: AppColors.paleGreen,
                        detail: 'Persistent on-device storage with export and playback capabilities.',
                      ),
                      const SizedBox(height: 24),
                      const SectionHeading(title: 'Supported Languages & Scripts'),
                      const SizedBox(height: 8),
                      const _LanguageCard(language: 'Santali', script: 'Ol Chiki (sat_Olck)'),
                      const SizedBox(height: 8),
                      const _LanguageCard(language: 'Hindi', script: 'Devanagari (hin_Deva)'),
                      const SizedBox(height: 8),
                      const _LanguageCard(language: 'English', script: 'Latin (eng_Latn)'),
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

class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.school_rounded, color: AppColors.forest, size: 36),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AnuvaadAI 2.0',
                    style: TextStyle(
                      color: AppColors.forest,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Offline Classroom Translation & Education System • v2.0.0',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadinessNotice extends StatelessWidget {
  const _ReadinessNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.paleGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.forest.withValues(alpha: 0.22)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_rounded, color: AppColors.forest),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '100% Offline Architecture Verified',
                  style: TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'No active internet connection, external telemetry, or cloud inference is required during operation.',
                  style: TextStyle(color: AppColors.charcoal, height: 1.4, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureStatusCard extends StatelessWidget {
  const _FeatureStatusCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.statusColor,
    required this.statusBackground,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String status;
  final Color statusColor;
  final Color statusBackground;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.forest, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(detail, style: const TextStyle(color: AppColors.muted, height: 1.4, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.language, required this.script});

  final String language;
  final String script;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.language_rounded, color: AppColors.forest),
        title: Text(language, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(script, style: const TextStyle(color: AppColors.muted)),
      ),
    );
  }
}

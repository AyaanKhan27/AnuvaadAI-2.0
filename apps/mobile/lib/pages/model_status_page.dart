import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../services/speech_service.dart';
import '../services/translation_service.dart';

class ModelStatusPage extends StatefulWidget {
  const ModelStatusPage({super.key});

  @override
  State<ModelStatusPage> createState() => _ModelStatusPageState();
}

class _ModelStatusPageState extends State<ModelStatusPage> {
  bool _isLoading = true;
  Map<String, dynamic> _translationStatus = {};
  Map<String, dynamic> _speechStatus = {};

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    final tStatus = await TranslationService.getModelStatus();
    final sStatus = await SpeechService.getStatus();
    if (!mounted) return;
    setState(() {
      _translationStatus = tStatus;
      _speechStatus = sStatus;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final indicPresent = _translationStatus['indic_model_present'] == true;
    final enPresent = _translationStatus['en_indic_model_present'] == true;
    final indicEnPresent = _translationStatus['indic_en_model_present'] == true;
    final santaliTtsPresent = _speechStatus['santali_vits_ready'] == true || _translationStatus['santali_tts_present'] == true;
    final hindiTtsPresent = _speechStatus['hindi_tts_ready'] == true;
    final asrDiag = _speechStatus['asr_diagnostics'] as Map<dynamic, dynamic>? ?? {};
    final asrAvailable = asrDiag['is_recognition_available'] == true;
    final asrOnDevice = asrDiag['is_on_device_available'] == true;
    final asrProvider = (asrDiag['preferred_service'] as String? ?? 'Google Speech Services').contains('com.google.android.tts')
        ? 'Google Speech Services'
        : (asrDiag['preferred_service'] as String? ?? 'System Recognizer');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Model Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Status',
            onPressed: _checkStatus,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.paleGreen,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.offline_pin_rounded, color: AppColors.forest, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Offline First Architecture',
                                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.forest),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'All active features execute completely on-device without cloud servers.',
                                  style: TextStyle(fontSize: 12, color: AppColors.charcoal),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Translation Engines',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    _StatusTile(
                      title: 'IndicTrans2 Indic-to-Indic Model',
                      subtitle: 'Hindi ↔ Santali (hin_Deva ↔ sat_Olck)',
                      isReady: indicPresent,
                      detail: 'Storage: /Android/data/.../files/models (encoder & decoder ONNX)',
                    ),
                    const SizedBox(height: 10),
                    _StatusTile(
                      title: 'IndicTrans2 English-to-Indic Model',
                      subtitle: 'English → Santali & Hindi (eng_Latn → sat_Olck / hin_Deva)',
                      isReady: enPresent,
                      detail: 'Storage: /Android/data/.../files/en-indic-models (shared ONNX)',
                    ),
                    const SizedBox(height: 10),
                    _StatusTile(
                      title: 'IndicTrans2 Indic-to-English Model',
                      subtitle: 'Hindi & Santali → English (hin_Deva / sat_Olck → eng_Latn)',
                      isReady: indicEnPresent,
                      detail: 'Storage: /Android/data/.../files/indic-en-models (distilled 200M ONNX)',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Speech Synthesis (TTS)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    _StatusTile(
                      title: 'Native Santali VITS ONNX',
                      subtitle: 'Authentic Ol Chiki neural speech (22,050 Hz PCM)',
                      isReady: santaliTtsPresent,
                      detail: 'VITS neural synthesizer with pure Kotlin Ol Chiki phonemizer',
                    ),
                    const SizedBox(height: 10),
                    _StatusTile(
                      title: 'Hindi & English TTS Engine',
                      subtitle: 'On-device Android TextToSpeech engine',
                      isReady: hindiTtsPresent,
                      detail: 'System offline voice synthesizer (Locale: hi-IN, en-US)',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Speech Recognition (ASR)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    _StatusTile(
                      title: 'Google On-Device Speech Recognition',
                      subtitle: 'Offline Hindi & English ASR (Android 9+ / API 33+)',
                      isReady: asrAvailable,
                      detail: asrOnDevice
                          ? 'On-device recognition capable (Provider: $asrProvider)'
                          : 'System speech recognizer available (manage via Speech Studio)',
                    ),
                    const SizedBox(height: 10),
                    const _StatusTile(
                      title: 'Santali Ol Chiki Speech Recognition',
                      subtitle: 'Active Research Track',
                      isReady: false,
                      detail: 'Acoustic models in research; neural VITS TTS & translation fully active',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Vision & OCR',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    const _StatusTile(
                      title: 'Google ML Kit Text Recognition',
                      subtitle: 'Devanagari (Hindi) & Latin (English) OCR',
                      isReady: true,
                      detail: 'Bundled directly inside APK release binary',
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.title,
    required this.subtitle,
    required this.isReady,
    required this.detail,
  });

  final String title;
  final String subtitle;
  final bool isReady;
  final String detail;

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
                Icon(
                  isReady ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: isReady ? AppColors.forest : AppColors.terracotta,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isReady ? AppColors.paleGreen : AppColors.paleTerracotta,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isReady ? 'READY' : 'PROVISIONABLE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isReady ? AppColors.forest : AppColors.terracotta,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: AppColors.charcoal, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

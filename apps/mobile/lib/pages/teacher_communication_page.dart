import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../data/history_store.dart';
import '../data/saved_lesson.dart';
import '../services/speech_service.dart';
import '../services/translation_service.dart';

enum TeacherModeState {
  idle,
  listening,
  translating,
  speaking,
  paused,
  error,
}

class CommunicationTurn {
  CommunicationTurn({
    required this.id,
    required this.hindiText,
    required this.santaliText,
    required this.timestamp,
  });

  final String id;
  final String hindiText;
  final String santaliText;
  final DateTime timestamp;
}

class TeacherCommunicationPage extends StatefulWidget {
  const TeacherCommunicationPage({super.key});

  @override
  State<TeacherCommunicationPage> createState() => _TeacherCommunicationPageState();
}

class _TeacherCommunicationPageState extends State<TeacherCommunicationPage> {
  TeacherModeState _state = TeacherModeState.idle;
  bool _isActive = false;
  bool _autoSpeak = true;
  String _currentPartialHindi = '';
  String? _statusMessage;
  String? _errorMessage;
  double? _rmsDb;

  final List<CommunicationTurn> _turns = [];
  StreamSubscription<Map<String, dynamic>>? _speechSub;

  @override
  void initState() {
    super.initState();
    _subscribeToSpeechEvents();
  }

  void _subscribeToSpeechEvents() {
    _speechSub = SpeechService.speechEvents.listen(
      (event) {
        if (!mounted) return;
        final type = event['event'] as String?;
        final data = event['data'];

        switch (type) {
          case 'ready':
            if (_isActive && _state == TeacherModeState.listening) {
              setState(() {
                _statusMessage = 'Listening for Hindi speech…';
                _errorMessage = null;
              });
            }
            break;

          case 'beginning_of_speech':
            if (_isActive) {
              setState(() {
                _statusMessage = 'Teacher speaking… capturing Hindi';
              });
            }
            break;

          case 'rms':
            if (_isActive && _state == TeacherModeState.listening && data is num) {
              setState(() {
                _rmsDb = data.toDouble();
              });
            }
            break;

          case 'partial_result':
            if (_isActive && data is Map) {
              final text = data['text'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                setState(() {
                  _currentPartialHindi = text;
                });
              }
            }
            break;

          case 'final_result':
            if (_isActive && data is Map) {
              final text = data['text'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                _handleFinalHindiUtterance(text.trim());
              }
            }
            break;

          case 'error':
            if (_isActive && _state == TeacherModeState.listening) {
              final msg = (data is Map) ? (data['message'] as String? ?? 'Speech error') : 'Speech error';
              setState(() {
                _rmsDb = null;
                _statusMessage = null;
                // If the error was just a brief timeout with no speech, auto-restart if still active
                if (msg.contains('No match') || msg.contains('Speech timeout')) {
                  _statusMessage = 'Waiting for teacher to speak…';
                  _resumeListening();
                } else {
                  _errorMessage = msg;
                }
              });
            }
            break;

          case 'end_of_speech':
          case 'done':
            if (_isActive && _state == TeacherModeState.listening && _currentPartialHindi.isNotEmpty) {
              // Utterance ended; if final_result has not triggered yet, use partial
              _handleFinalHindiUtterance(_currentPartialHindi.trim());
            }
            break;
        }
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Speech stream error: $err';
        });
      },
    );
  }

  Future<void> _handleFinalHindiUtterance(String hindiText) async {
    if (hindiText.isEmpty) return;

    // 1. Immediately pause microphone so Santali speaker output is not fed back
    await SpeechService.stopListening();

    setState(() {
      _currentPartialHindi = hindiText;
      _state = TeacherModeState.translating;
      _statusMessage = 'Translating Hindi to Santali (Ol Chiki)…';
      _rmsDb = null;
      _errorMessage = null;
    });

    try {
      // 2. Perform offline IndicTrans2 translation (hin_Deva -> sat_Olck)
      final result = await TranslationService.translate(
        hindiText,
        srcLang: 'hin_Deva',
        tgtLang: 'sat_Olck',
      );

      final santaliText = result.text.trim();
      final turn = CommunicationTurn(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        hindiText: hindiText,
        santaliText: santaliText,
        timestamp: DateTime.now(),
      );

      // Record to history store
      HistoryStore.add(
        sourceText: hindiText,
        translatedText: santaliText,
        sourceLang: 'hin_Deva',
        targetLang: 'sat_Olck',
      );

      if (!mounted) return;
      setState(() {
        _turns.insert(0, turn);
        _currentPartialHindi = '';
      });

      // 3. Synthesize Santali VITS speech if enabled
      if (_autoSpeak && santaliText.isNotEmpty) {
        setState(() {
          _state = TeacherModeState.speaking;
          _statusMessage = 'Speaking Santali via neural VITS…';
        });

        await SpeechService.speak(santaliText, lang: 'sat_Olck');

        // Wait until Santali audio playback completes (with 15s safety timeout)
        final startTime = DateTime.now();
        while (mounted && _isActive && await SpeechService.isSpeaking()) {
          if (DateTime.now().difference(startTime).inSeconds > 15) break;
          await Future.delayed(const Duration(milliseconds: 120));
        }
      }

      // 4. Resume listening for the teacher's next sentence
      if (mounted && _isActive && _state != TeacherModeState.paused) {
        await _resumeListening();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = TeacherModeState.error;
        _errorMessage = 'Translation failed: $e. Please verify offline model files.';
      });
    }
  }

  Future<void> _startSession() async {
    setState(() {
      _isActive = true;
      _state = TeacherModeState.listening;
      _statusMessage = 'Starting microphone for Hindi speech…';
      _errorMessage = null;
      _currentPartialHindi = '';
    });

    final ok = await SpeechService.startListening(
      locale: 'hi-IN',
      preferOffline: true,
    );

    if (!ok && mounted) {
      setState(() {
        _isActive = false;
        _state = TeacherModeState.error;
        _errorMessage = 'Could not start Hindi speech recognition. Check microphone permissions.';
      });
    }
  }

  Future<void> _resumeListening() async {
    if (!_isActive) return;
    setState(() {
      _state = TeacherModeState.listening;
      _statusMessage = 'Listening now… Speak in Hindi';
      _rmsDb = null;
      _errorMessage = null;
    });

    await SpeechService.startListening(
      locale: 'hi-IN',
      preferOffline: true,
    );
  }

  Future<void> _pauseSession() async {
    await SpeechService.stopListening();
    await SpeechService.stop(); // Stop any active Santali TTS
    if (!mounted) return;
    setState(() {
      _state = TeacherModeState.paused;
      _statusMessage = 'Session paused. Tap Resume to continue.';
      _rmsDb = null;
    });
  }

  Future<void> _stopSession() async {
    await SpeechService.stopListening();
    await SpeechService.stop();
    if (!mounted) return;
    setState(() {
      _isActive = false;
      _state = TeacherModeState.idle;
      _statusMessage = 'Session stopped.';
      _currentPartialHindi = '';
      _rmsDb = null;
    });
  }

  Future<void> _replayTurn(CommunicationTurn turn) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Replaying Santali audio…')),
    );
    await SpeechService.speak(turn.santaliText, lang: 'sat_Olck');
  }

  Future<void> _saveAsClassroomLesson() async {
    if (_turns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No spoken phrases to save in this session.')),
      );
      return;
    }

    final fullHindi = _turns.reversed.map((t) => t.hindiText).join('\n');
    final fullSantali = _turns.reversed.map((t) => t.santaliText).join('\n');
    final titleController = TextEditingController(
      text: 'Classroom Lesson ${DateTime.now().day}/${DateTime.now().month} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Lesson to Library'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Save this entire Hindi-to-Santali classroom dialogue to your offline Saved Lessons library for future review.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Lesson Title'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save Lesson'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      await SavedLessonsStore.save(
        hindiText: fullHindi,
        santaliText: fullSantali,
        title: titleController.text.trim(),
        sourceLang: 'hin_Deva',
        targetLang: 'sat_Olck',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lesson saved successfully! View it in Saved Lessons.')),
        );
      }
    }
  }

  void _clearSession() {
    setState(() {
      _turns.clear();
      _currentPartialHindi = '';
      _errorMessage = null;
    });
  }

  @override
  void dispose() {
    _speechSub?.cancel();
    SpeechService.stopListening();
    SpeechService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Communication Bridge'),
        actions: [
          IconButton(
            icon: Icon(_autoSpeak ? Icons.volume_up_rounded : Icons.volume_off_rounded),
            tooltip: _autoSpeak ? 'Auto Santali Audio ON' : 'Auto Santali Audio OFF',
            onPressed: () {
              setState(() {
                _autoSpeak = !_autoSpeak;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_autoSpeak ? 'Auto Santali Speech Enabled' : 'Auto Santali Speech Disabled'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Save Session as Lesson',
            onPressed: _turns.isNotEmpty ? _saveAsClassroomLesson : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear Timeline',
            onPressed: _turns.isNotEmpty ? _clearSession : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Live Mode & Status Banner
            _buildStatusHeader(),

            // Live Utterance Banner (shows captured Hindi in real time)
            if (_currentPartialHindi.isNotEmpty || _state == TeacherModeState.translating || _state == TeacherModeState.speaking)
              _buildLiveUtteranceCard(),

            // Error Message Card
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.paleTerracotta,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.terracotta.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.terracotta, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: AppColors.charcoal)),
                      ),
                    ],
                  ),
                ),
              ),

            // Scrollable Timeline of Classroom Turns
            Expanded(
              child: _turns.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: _turns.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (ctx, index) {
                        final turn = _turns[index];
                        final isLatest = index == 0;
                        return _TurnCard(
                          turn: turn,
                          isLatest: isLatest,
                          onReplay: () => _replayTurn(turn),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildControlBar(),
    );
  }

  Widget _buildStatusHeader() {
    Color badgeColor;
    IconData badgeIcon;
    String statusText;

    switch (_state) {
      case TeacherModeState.listening:
        badgeColor = AppColors.terracotta;
        badgeIcon = Icons.mic_rounded;
        statusText = 'Teacher Speaking (Listening in Hindi…)';
        break;
      case TeacherModeState.translating:
        badgeColor = Colors.orange;
        badgeIcon = Icons.auto_mode_rounded;
        statusText = 'Translating to Santali (IndicTrans2)…';
        break;
      case TeacherModeState.speaking:
        badgeColor = AppColors.forest;
        badgeIcon = Icons.record_voice_over_rounded;
        statusText = 'Playing Santali Audio (Neural VITS)…';
        break;
      case TeacherModeState.paused:
        badgeColor = Colors.grey;
        badgeIcon = Icons.pause_circle_rounded;
        statusText = 'Session Paused';
        break;
      case TeacherModeState.error:
        badgeColor = AppColors.terracotta;
        badgeIcon = Icons.warning_amber_rounded;
        statusText = 'Speech Error';
        break;
      case TeacherModeState.idle:
        badgeColor = AppColors.muted;
        badgeIcon = Icons.power_settings_new_rounded;
        statusText = 'Ready to Start Live Classroom Bridge';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: badgeColor.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Icon(badgeIcon, color: badgeColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage ?? statusText,
              style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          if (_state == TeacherModeState.listening && _rmsDb != null)
            Container(
              width: 8 + (_rmsDb!.clamp(0, 15)),
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.terracotta,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveUtteranceCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paleGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.forest.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hearing_rounded, color: AppColors.forest, size: 18),
              SizedBox(width: 8),
              Text(
                'LIVE CAPTURE (HINDI)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.forest,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currentPartialHindi.isEmpty ? 'Processing speech…' : _currentPartialHindi,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.forest.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school_rounded, size: 48, color: AppColors.forest),
            ),
            const SizedBox(height: 18),
            const Text(
              'Real-Time Mother-Tongue Bridge',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.charcoal),
            ),
            const SizedBox(height: 8),
            const Text(
              'Empowers Hindi-speaking teachers to teach Santali children in their mother tongue.\n\n'
              '1. Tap "Start Session" below.\n'
              '2. Speak your lesson explanation in Hindi.\n'
              '3. App instantly translates and speaks authentic Santali (Ol Chiki) aloud.\n'
              '4. Microphone automatically waits and loops continuously.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_isActive) ...[
            IconButton.filledTonal(
              tooltip: _state == TeacherModeState.paused ? 'Resume' : 'Pause',
              onPressed: _state == TeacherModeState.paused ? _resumeListening : _pauseSession,
              icon: Icon(_state == TeacherModeState.paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _isActive ? AppColors.terracotta : AppColors.forest,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isActive ? _stopSession : _startSession,
              icon: Icon(_isActive ? Icons.stop_rounded : Icons.mic_rounded),
              label: Text(
                _isActive ? 'Stop Teacher Session' : 'Start Teacher Bridge',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnCard extends StatelessWidget {
  const _TurnCard({
    required this.turn,
    required this.isLatest,
    required this.onReplay,
  });

  final CommunicationTurn turn;
  final bool isLatest;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final timeStr = '${turn.timestamp.hour.toString().padLeft(2, '0')}:${turn.timestamp.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: isLatest ? AppColors.paleGreen.withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLatest ? AppColors.forest : Colors.black.withValues(alpha: 0.08),
          width: isLatest ? 1.5 : 1.0,
        ),
        boxShadow: isLatest
            ? [
                BoxShadow(
                  color: AppColors.forest.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isLatest ? AppColors.forest : AppColors.muted.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isLatest ? 'LATEST UTTERANCE' : timeStr,
                  style: TextStyle(
                    color: isLatest ? Colors.white : AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy Santali',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: turn.santaliText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Santali text copied to clipboard.')),
                  );
                },
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.volume_up_rounded, size: 20, color: AppColors.forest),
                tooltip: 'Replay Santali Audio',
                onPressed: onReplay,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Teacher Hindi input
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'शिक्षक: ',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.charcoal),
              ),
              Expanded(
                child: Text(
                  turn.hindiText,
                  style: const TextStyle(fontSize: 14, color: AppColors.charcoal),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Santali translation in prominent Ol Chiki
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ᱥᱟᱱᱛᱟᱲᱤ: ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.forest),
              ),
              Expanded(
                child: Text(
                  turn.santaliText,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

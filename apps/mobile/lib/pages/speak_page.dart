import 'dart:async';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/speech_config_store.dart';
import '../services/speech_service.dart';
import 'translate_page.dart';

class SpeakPage extends StatefulWidget {
  const SpeakPage({super.key});

  @override
  State<SpeakPage> createState() => _SpeakPageState();
}

class _SpeakPageState extends State<SpeakPage> {
  final _textController = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _speechSub;

  String _selectedLang = 'hi-IN';
  bool _isListening = false;
  double? _rmsDb;
  String? _errorMessage;
  String? _infoMessage;

  // Language support state & async guard
  int _refreshSeq = 0;
  bool _isCheckingSupport = false;
  bool _isModelInstalled = false;
  bool _isDownloading = false;
  int _downloadProgress = 0;
  String _providerName = 'Google Speech Services';
  Map<String, dynamic> _diagnostics = {};
  int? _lastSupportErrorCode;
  String? _lastSupportErrorName;

  // Persistent speech verification state (Realme Narzo N55 / Error 14 fix)
  bool _isAcknowledged = false;
  bool _hasTestPassed = false;
  int? _lastTestTimestamp;
  SpeechReadinessState _readinessState = SpeechReadinessState.capabilityUnverified;

  final Map<String, String> _languages = {
    'hi-IN': 'Hindi (Devanagari)',
    'en-IN': 'English (India)',
    'en-US': 'English (United States)',
    'sat_Olck': 'Santali (Ol Chiki - Neural TTS Mode)',
  };

  @override
  void initState() {
    super.initState();
    _subscribeToSpeechEvents();
    _initPersistenceAndRefresh();
  }

  Future<void> _initPersistenceAndRefresh() async {
    try {
      final savedLang = await SpeechConfigStore.getSelectedLanguage();
      if (mounted) {
        setState(() {
          _selectedLang = savedLang;
        });
      }
    } catch (_) {}
    if (mounted) {
      await _refreshSupportAndDiagnostics();
    }
  }

  void _subscribeToSpeechEvents() {
    _speechSub = SpeechService.speechEvents.listen(
      (event) {
        if (!mounted) return;
        final type = event['event'] as String?;
        final data = event['data'];

        switch (type) {
          case 'ready':
            setState(() {
              _isListening = true;
              _errorMessage = null;
              _infoMessage = 'Listening now… speak into microphone';
            });
            break;

          case 'beginning_of_speech':
            setState(() {
              _infoMessage = 'Speech detected, transcribing…';
            });
            break;

          case 'rms':
            if (data is num) {
              setState(() => _rmsDb = data.toDouble());
            }
            break;

          case 'partial_result':
            if (data is Map) {
              final partial = data['text'] as String?;
              if (partial != null && partial.isNotEmpty) {
                _recordSuccessAndMarkReady();
                setState(() {
                  _textController.text = partial;
                });
              }
            }
            break;

          case 'final_result':
            if (data is Map) {
              final finalWords = data['text'] as String?;
              if (finalWords != null && finalWords.isNotEmpty) {
                _recordSuccessAndMarkReady();
                setState(() {
                  _textController.text = finalWords;
                  _infoMessage = 'Recognition complete.';
                });
              }
            }
            break;

          case 'error':
            if (data is Map) {
              final msg = data['message'] as String? ?? 'Speech recognition error';
              final canDownload = data['can_download'] == true;
              setState(() {
                _isListening = false;
                _rmsDb = null;
                _errorMessage = msg;
                if (canDownload && !_isAcknowledged && !_hasTestPassed) {
                  _isModelInstalled = false;
                }
              });
            }
            break;

          case 'download_progress':
            if (data is Map) {
              final status = data['status'] as String?;
              final prog = data['progress'] as int? ?? 0;
              final msg = data['message'] as String?;
              setState(() {
                if (status == 'downloading') {
                  _isDownloading = true;
                  _downloadProgress = prog;
                  _infoMessage = 'Downloading offline model: $prog%';
                } else if (status == 'success') {
                  _isDownloading = false;
                  _isModelInstalled = true;
                  _downloadProgress = 100;
                  _infoMessage = msg ?? 'Offline language pack ready!';
                  SpeechConfigStore.setAcknowledgedUnverified(_selectedLang, true);
                } else if (status == 'error') {
                  _isDownloading = false;
                  _errorMessage = msg ?? 'Model download failed.';
                } else if (status == 'scheduled') {
                  _isDownloading = true;
                  _infoMessage = msg ?? 'Download scheduled by system.';
                }
              });
            }
            break;

          case 'end_of_speech':
          case 'done':
            setState(() {
              _isListening = false;
              _rmsDb = null;
            });
            break;
        }
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _rmsDb = null;
          _errorMessage = 'Speech event stream error: $err';
        });
      },
    );
  }

  Future<void> _recordSuccessAndMarkReady() async {
    if (_selectedLang == 'sat_Olck') return;
    if (!mounted) return;
    if (_readinessState == SpeechReadinessState.offlineTested) {
      setState(() {
        _errorMessage = null;
        _infoMessage = 'Recognition complete.';
      });
    } else if (_readinessState == SpeechReadinessState.setupAcknowledged) {
      setState(() {
        _errorMessage = null;
        _infoMessage = 'Speech captured! Tap "Confirm Verified in Airplane Mode" if tested offline.';
      });
    }
  }

  Future<void> _refreshSupportAndDiagnostics() async {
    final currentSeq = ++_refreshSeq;

    if (_selectedLang == 'sat_Olck') {
      if (mounted && currentSeq == _refreshSeq) {
        setState(() {
          _isModelInstalled = false;
          _errorMessage = null;
          _infoMessage = null;
          _lastSupportErrorCode = null;
          _lastSupportErrorName = null;
        });
      }
      return;
    }

    setState(() {
      _isCheckingSupport = true;
      _errorMessage = null;
      _lastSupportErrorCode = null;
      _lastSupportErrorName = null;
    });

    try {
      final diag = await SpeechService.getSpeechDiagnostics(locale: _selectedLang);
      if (!mounted || currentSeq != _refreshSeq) return;

      final support = await SpeechService.checkRecognitionSupport(locale: _selectedLang);
      if (!mounted || currentSeq != _refreshSeq) return;

      final preferredService = diag['preferred_service'] as String? ?? 'system_default';
      final serviceName = preferredService.contains('com.google.android.tts')
          ? 'Google Speech Services'
          : preferredService.contains('com.google.android.as')
              ? 'Android System Intelligence'
              : preferredService;

      final rawInstalled = support['is_installed'] == true;
      final errorCode = support['error_code'] as int?;
      final errorName = support['error_name'] as String?;
      final message = support['message'] as String?;

      // Check persistent memory
      bool ack = false;
      bool passed = false;
      int? time;
      try {
        ack = await SpeechConfigStore.isAcknowledgedUnverified(_selectedLang);
        passed = await SpeechConfigStore.isTestPassed(_selectedLang);
        time = await SpeechConfigStore.getLastTestTimestamp(_selectedLang);
      } catch (_) {}

      // Distinct readiness calculation
      SpeechReadinessState readiness = SpeechReadinessState.capabilityUnverified;
      try {
        readiness = await SpeechConfigStore.getReadinessState(
          locale: _selectedLang,
          nativeReportedInstalled: rawInstalled,
          supportErrorCode: errorCode,
        );
      } catch (_) {}

      setState(() {
        _diagnostics = diag;
        _providerName = serviceName;
        _isAcknowledged = ack;
        _hasTestPassed = passed;
        _lastTestTimestamp = time;
        _readinessState = readiness;
        _isModelInstalled = (readiness == SpeechReadinessState.offlineTested);
        _isCheckingSupport = false;

        if (readiness == SpeechReadinessState.offlineTested) {
          _errorMessage = null;
        } else if (readiness == SpeechReadinessState.setupAcknowledged) {
          _errorMessage = null;
          _infoMessage = 'Setup acknowledged. Speak into microphone to perform live offline test.';
        } else if (readiness == SpeechReadinessState.capabilityUnverified) {
          _lastSupportErrorCode = 14;
          _lastSupportErrorName = errorName ?? 'ERROR_CANNOT_CHECK_SUPPORT';
          _errorMessage = message ??
              'Speech recognition provider does not report automated offline status (Code 14). Please verify or download offline language models in Speech Settings.';
        } else {
          _lastSupportErrorCode = errorCode;
          _lastSupportErrorName = errorName;
          _errorMessage = message;
        }
      });
    } catch (e) {
      if (!mounted || currentSeq != _refreshSeq) return;
      setState(() {
        _isCheckingSupport = false;
        _errorMessage = 'Speech capability check notice: $e';
      });
    }
  }

  Future<void> _toggleListening() async {
    if (_selectedLang == 'sat_Olck') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Santali STT is in active research. Type Ol Chiki text below to synthesize offline audio or translate.',
          ),
        ),
      );
      return;
    }

    if (_isListening) {
      await SpeechService.stopListening();
      setState(() {
        _isListening = false;
        _rmsDb = null;
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _infoMessage = 'Starting microphone…';
    });

    final started = await SpeechService.startListening(
      locale: _selectedLang,
      preferOffline: true,
    );

    if (!started && mounted) {
      setState(() {
        _isListening = false;
        _errorMessage = 'Could not start speech recognition. Please check microphone permissions.';
      });
    }
  }

  Future<void> _triggerModelDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _errorMessage = null;
      _infoMessage = 'Initiating offline model download…';
    });

    final ok = await SpeechService.triggerModelDownload(locale: _selectedLang);
    if (!ok && mounted) {
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Could not trigger model download automatically. Please use Speech Settings.';
      });
    }
  }

  Future<void> _openSettings() async {
    final opened = await SpeechService.openSpeechSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open system speech settings directly.')),
      );
    }
  }

  Future<void> _acknowledgeSetup() async {
    await SpeechConfigStore.setAcknowledgedUnverified(_selectedLang, true);
    if (!mounted) return;
    setState(() {
      _isAcknowledged = true;
      _readinessState = SpeechReadinessState.setupAcknowledged;
      _isModelInstalled = false; // Not falsely marked offline ready until tested
      _errorMessage = null;
      _infoMessage = 'Setup acknowledged. Speak into microphone to perform live offline test.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Offline speech setup for ${_languages[_selectedLang]} acknowledged. Live test pending.',
        ),
      ),
    );
  }

  Future<void> _confirmAirplaneVerified() async {
    await SpeechConfigStore.setOfflineVerified(_selectedLang, true);
    if (!mounted) return;
    setState(() {
      _hasTestPassed = true;
      _isAcknowledged = true;
      _isModelInstalled = true;
      _readinessState = SpeechReadinessState.offlineTested;
      _errorMessage = null;
      _infoMessage = 'Offline speech verified via Airplane Mode test!';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Offline speech for ${_languages[_selectedLang]} verified in Airplane Mode.',
        ),
      ),
    );
  }

  Future<void> _resetVerification() async {
    await SpeechConfigStore.resetLocale(_selectedLang);
    if (!mounted) return;
    setState(() {
      _isAcknowledged = false;
      _hasTestPassed = false;
      _lastTestTimestamp = null;
    });
    await _refreshSupportAndDiagnostics();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech status reset. Refreshing diagnostics...')),
      );
    }
  }

  void _showDiagnosticsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final apiLevel = _diagnostics['api_level'] ?? 'Unknown';
        final onDeviceAvail = _diagnostics['is_on_device_available'] == true ? 'Yes' : 'No';
        final recAvail = _diagnostics['is_recognition_available'] == true ? 'Yes' : 'No';
        final prefService = _diagnostics['preferred_service'] ?? 'Default';
        final installedLangs = (_diagnostics['cached_installed_languages'] as List?)?.join(', ') ?? 'None reported';
        final testTimeStr = _lastTestTimestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(_lastTestTimestamp!).toLocal().toString().split('.')[0]
            : 'None recorded';

        String readinessDesc;
        switch (_readinessState) {
          case SpeechReadinessState.offlineTested:
            readinessDesc = 'Offline Tested & Ready';
            break;
          case SpeechReadinessState.setupAcknowledged:
            readinessDesc = 'Setup Acknowledged (Pending Live Test)';
            break;
          case SpeechReadinessState.capabilityUnverified:
            readinessDesc = 'Capability Unverified (Code 14)';
            break;
          case SpeechReadinessState.unavailable:
            readinessDesc = 'Unavailable / Model Missing';
            break;
        }

        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.perm_device_information_rounded, color: AppColors.forest),
              SizedBox(width: 10),
              Text('Speech Diagnostics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _DiagRow(label: 'Android API Level', value: '$apiLevel'),
                _DiagRow(label: 'Speech Recognizer Ready', value: recAvail),
                _DiagRow(label: 'On-Device Capable', value: onDeviceAvail),
                _DiagRow(label: 'Configured Provider', value: '$prefService'),
                _DiagRow(label: 'Selected Target Locale', value: _selectedLang),
                _DiagRow(label: 'Readiness State', value: readinessDesc),
                _DiagRow(label: 'Setup Acknowledged', value: _isAcknowledged ? 'Yes' : 'No'),
                _DiagRow(label: 'Live Test Passed', value: _hasTestPassed ? 'Yes ($testTimeStr)' : 'Not yet'),
                _DiagRow(label: 'Support API Code', value: _lastSupportErrorCode != null ? 'Code $_lastSupportErrorCode ($_lastSupportErrorName)' : 'Normal (0)'),
                _DiagRow(label: 'Cached Installed Locales', value: installedLangs),
                const SizedBox(height: 12),
                const Text(
                  'On Android 13+ (Realme Narzo N55), Google Speech Services returns Code 14. Once setup is acknowledged, download prompts are silenced; once live speech is tested, offline recognition is verified ready.',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _resetVerification();
              },
              child: const Text('Reset Status', style: TextStyle(color: AppColors.terracotta)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _openSettings();
              },
              child: const Text('Open Settings'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _translate() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recognized speech text is empty.')),
      );
      return;
    }

    final srcLang = _selectedLang.startsWith('hi')
        ? 'hin_Deva'
        : _selectedLang.startsWith('en')
            ? 'eng_Latn'
            : 'sat_Olck';
    final tgtLang = srcLang == 'sat_Olck' ? 'hin_Deva' : 'sat_Olck';

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TranslatePage(
          initialText: text,
          initialSrcLang: srcLang,
          initialTgtLang: tgtLang,
        ),
      ),
    );
  }

  Future<void> _speakText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final lang = _selectedLang.startsWith('hi')
        ? 'hin_Deva'
        : _selectedLang.startsWith('en')
            ? 'eng_Latn'
            : 'sat_Olck';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Playing offline audio (${_languages[_selectedLang]})...')),
    );
    await SpeechService.speak(text, lang: lang);
  }

  @override
  void dispose() {
    _refreshSeq++;
    _speechSub?.cancel();
    SpeechService.cancelListening();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speech Studio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Speech Diagnostics',
            onPressed: _showDiagnosticsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Capabilities',
            onPressed: _refreshSupportAndDiagnostics,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Language Selector
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.language_rounded, color: AppColors.forest),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedLang,
                            isExpanded: true,
                            items: _languages.entries
                                .map((e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(
                                        e.value,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _selectedLang = v;
                                  _errorMessage = null;
                                  _infoMessage = null;
                                  _lastSupportErrorCode = null;
                                  _lastSupportErrorName = null;
                                });
                                SpeechConfigStore.setSelectedLanguage(v);
                                _refreshSupportAndDiagnostics();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Capability & Model Status Card
              if (_selectedLang == 'sat_Olck')
                _buildSantaliCard()
              else
                _buildOfflineStatusCard(),

              const SizedBox(height: 20),

              // Microphone Button with audio ripple visualizer
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_isListening && _rmsDb != null)
                          Container(
                            width: 100 + (_rmsDb!.clamp(0, 20) * 2),
                            height: 100 + (_rmsDb!.clamp(0, 20) * 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.terracotta.withValues(alpha: 0.18),
                            ),
                          ),
                        FloatingActionButton.large(
                          onPressed: _toggleListening,
                          backgroundColor: _isListening ? AppColors.terracotta : AppColors.forest,
                          child: Icon(
                            _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isListening
                          ? 'Listening now… speak into microphone'
                          : _selectedLang == 'sat_Olck'
                              ? 'Santali neural TTS active. Type text below to speak.'
                              : 'Tap microphone to speak offline',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _isListening ? AppColors.terracotta : AppColors.charcoal,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Status messages / download progress
              if (_isDownloading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      LinearProgressIndicator(value: _downloadProgress > 0 ? _downloadProgress / 100.0 : null),
                      const SizedBox(height: 6),
                      Text('Downloading speech model ($_downloadProgress%)…', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),

              if (_infoMessage != null && !_isDownloading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _infoMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.forest, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.paleTerracotta,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.terracotta.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _lastSupportErrorCode == 14 ? Icons.info_outline_rounded : Icons.error_outline_rounded,
                            color: AppColors.terracotta,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _lastSupportErrorCode == 14
                                  ? 'Speech Recognition Support Notice (Code 14)'
                                  : 'Speech Recognition Notice',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.terracotta, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.charcoal, fontSize: 12),
                      ),
                      if (!_isModelInstalled && _selectedLang != 'sat_Olck') ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: _acknowledgeSetup,
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                              label: const Text('Mark as Verified', style: TextStyle(fontSize: 12)),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _isDownloading ? null : _triggerModelDownload,
                              icon: const Icon(Icons.download_rounded, size: 16),
                              label: const Text('Download Model', style: TextStyle(fontSize: 12)),
                            ),
                            OutlinedButton.icon(
                              onPressed: _openSettings,
                              icon: const Icon(Icons.settings_rounded, size: 16),
                              label: const Text('Speech Settings', style: TextStyle(fontSize: 12)),
                            ),
                            OutlinedButton.icon(
                              onPressed: _refreshSupportAndDiagnostics,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Retry Check', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

              // Recognized / Editable Text Box
              TextField(
                controller: _textController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Recognized / Spoken Text (editable)',
                  hintText: 'Speech recognition output will appear here in real time…',
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _translate,
                      icon: const Icon(Icons.translate_rounded),
                      label: const Text('Translate Text'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _textController.text.isEmpty ? null : _speakText,
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('Read Aloud'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              const Text(
                'Includes native Santali neural VITS speech synthesis for Ol Chiki, and Google on-device speech recognition for Hindi and English.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineStatusCard() {
    switch (_readinessState) {
      case SpeechReadinessState.offlineTested:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.paleGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.forest, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _hasTestPassed
                          ? 'Offline Speech Recognition Tested & Ready'
                          : 'Offline Speech Ready (On-Device)',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.forest, fontSize: 13),
                    ),
                  ),
                  if (_isCheckingSupport)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Speech recognition for ${_languages[_selectedLang]} has been tested and verified operational via $_providerName.',
                style: const TextStyle(fontSize: 11, color: AppColors.charcoal),
              ),
            ],
          ),
        );

      case SpeechReadinessState.setupAcknowledged:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F1F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF7CA3C2).withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: Color(0xFF2B5B84), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Offline Setup Acknowledged (Airplane Mode Test Pending)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2B5B84), fontSize: 13),
                    ),
                  ),
                  if (_isCheckingSupport)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Setup is recorded. To ensure 100% offline speech recognition, turn on Airplane Mode, speak a sentence into the microphone, then tap "Confirm Verified in Airplane Mode".',
                style: const TextStyle(fontSize: 11, color: AppColors.charcoal),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _confirmAirplaneVerified,
                    icon: const Icon(Icons.airplanemode_active_rounded, size: 16),
                    label: const Text('Confirm Verified in Airplane Mode', style: TextStyle(fontSize: 11)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_rounded, size: 16),
                    label: const Text('Speech Settings', style: TextStyle(fontSize: 11)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _resetVerification,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reset Status', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        );

      case SpeechReadinessState.capabilityUnverified:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.paleTerracotta,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.terracotta, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Offline Capability Unverified (Code 14)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.terracotta, fontSize: 13),
                    ),
                  ),
                  if (_isCheckingSupport)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Provider cannot check offline model status directly. If Hindi/English is downloaded in settings, tap "Acknowledge Setup".',
                style: const TextStyle(fontSize: 11, color: AppColors.charcoal),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _acknowledgeSetup,
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: const Text('Acknowledge Setup', style: TextStyle(fontSize: 11)),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _isDownloading ? null : _triggerModelDownload,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(_isDownloading ? 'Downloading…' : 'Download Model', style: const TextStyle(fontSize: 11)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_rounded, size: 16),
                    label: const Text('Speech Settings', style: TextStyle(fontSize: 11)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _refreshSupportAndDiagnostics,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry Check', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        );

      case SpeechReadinessState.unavailable:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.paleTerracotta,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.terracotta, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Offline Language Pack Required',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.terracotta, fontSize: 13),
                    ),
                  ),
                  if (_isCheckingSupport)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Offline model for ${_languages[_selectedLang]} (~45MB) is not installed.',
                style: const TextStyle(fontSize: 11, color: AppColors.charcoal),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _isDownloading ? null : _triggerModelDownload,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(_isDownloading ? 'Downloading…' : 'Download Model', style: const TextStyle(fontSize: 11)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_rounded, size: 16),
                    label: const Text('Speech Settings', style: TextStyle(fontSize: 11)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _refreshSupportAndDiagnostics,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry Check', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }

  Widget _buildSantaliCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paleGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.record_voice_over_rounded, color: AppColors.forest, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Santali Neural VITS TTS Mode',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.forest, fontSize: 13),
                ),
                SizedBox(height: 2),
                Text(
                  'Authentic Ol Chiki neural speech synthesizer is active. Type or paste Ol Chiki script below to hear offline audio or translate.',
                  style: TextStyle(fontSize: 11, color: AppColors.charcoal),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagRow extends StatelessWidget {
  const _DiagRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.charcoal)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
        ],
      ),
    );
  }
}

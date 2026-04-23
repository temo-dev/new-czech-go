import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'api_client.dart';
import 'models.dart';

class AppColors {
  static const primary = Color(0xFFF05A28);
  static const primaryStrong = Color(0xFFE4610A);
  static const primarySoft = Color(0xFFFFF1EA);
  static const accent = Color(0xFF3D5BB5);
  static const accentSoft = Color(0xFFEBF0FF);
  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF2F5F9);
  static const text = Color(0xFF0D1218);
  static const muted = Color(0xFF495265);
  static const border = Color(0xFFE4E8EF);
  static const success = Color(0xFF2F9E44);
  static const successSoft = Color(0xFFEAF7EE);
  static const danger = Color(0xFFC92A2A);
}

class AppRadii {
  static const pill = Radius.circular(999);
  static const card = Radius.circular(24);
  static const hero = Radius.circular(28);
}

void main() {
  runApp(const MluveniSprintApp());
}

void _logAudioDebug(
  String scope,
  Object error, {
  StackTrace? stackTrace,
  Map<String, Object?> extra = const {},
}) {
  final details = extra.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join(' ');
  debugPrint(
    '[audio-debug] scope=$scope error_type=${error.runtimeType} error=$error'
    '${details.isEmpty ? '' : ' $details'}',
  );
  if (stackTrace != null) {
    debugPrint('[audio-debug] scope=$scope stack=$stackTrace');
  }
}

String _playbackErrorMessage(String fallback, Object error, {String? prefix}) {
  if (error is PlayerException) {
    final lead = prefix == null ? '' : '$prefix ';
    return '$lead(code ${error.code}) ${error.message}';
  }
  if (error is PlayerInterruptedException) {
    final lead = prefix == null ? '' : '$prefix ';
    return '$lead${error.message}';
  }
  return fallback;
}

class MluveniSprintApp extends StatelessWidget {
  const MluveniSprintApp({super.key});

  @override
  Widget build(BuildContext context) {
    const baseTextTheme = TextTheme(
      headlineMedium: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: AppColors.text,
        letterSpacing: -0.8,
        fontFamily: 'PlayfairDisplay',
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
        fontFamily: 'PlayfairDisplay',
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
        fontFamily: 'PlayfairDisplay',
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
        fontFamily: 'PlayfairDisplay',
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: AppColors.text),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: AppColors.muted),
    );
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.danger,
    );

    return MaterialApp(
      title: 'A2 Mluveni Sprint',
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        textTheme: baseTextTheme,
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.text,
          centerTitle: false,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text,
            minimumSize: const Size(0, 52),
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: const LearnerShell(),
    );
  }
}

class LearnerShell extends StatefulWidget {
  const LearnerShell({super.key});

  @override
  State<LearnerShell> createState() => _LearnerShellState();
}

class _LearnerShellState extends State<LearnerShell> {
  final ApiClient _client = ApiClient();
  bool _loading = true;
  String? _error;
  String _learnerName = '';
  List<ModuleSummary> _modules = const [];
  Map<String, List<ExerciseSummary>> _exercisesByModule = const {};
  List<AttemptResult> _recentAttempts = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final login = await _client.login(
        email: 'learner@example.com',
        password: 'demo123',
      );
      final modulesPayload = await _client.getModules();
      final modules =
          modulesPayload
              .map(
                (item) => ModuleSummary.fromJson(item as Map<String, dynamic>),
              )
              .toList();

      final exerciseMap = <String, List<ExerciseSummary>>{};
      for (final module in modules) {
        final exercisePayload = await _client.getExercises(module.id);
        exerciseMap[module.id] =
            exercisePayload
                .map(
                  (item) =>
                      ExerciseSummary.fromJson(item as Map<String, dynamic>),
                )
                .toList();
      }
      final attemptsPayload = await _client.getAttempts();
      final recentAttempts =
          attemptsPayload
              .map(
                (item) => AttemptResult.fromJson(item as Map<String, dynamic>),
              )
              .toList();

      setState(() {
        _learnerName =
            (login['user'] as Map<String, dynamic>)['display_name']
                as String? ??
            'Learner';
        _modules = modules;
        _exercisesByModule = exerciseMap;
        _recentAttempts = recentAttempts;
      });
    } catch (err) {
      setState(() {
        _error = err.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _bootstrap,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
                : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: const BorderRadius.all(AppRadii.hero),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(13, 18, 24, 0.08),
                            blurRadius: 30,
                            offset: Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Focused speaking practice',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'A2 Mluveni Sprint',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Xin chao, $_learnerName. Bai hoc nay uu tien su ro rang, nhe nha, va tien do lien tuc giong mot coach binh tinh hon la mot bai test dang so.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: AppColors.muted),
                          ),
                          const SizedBox(height: 20),
                          const Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _InfoPill(
                                label: '14 ngay',
                                tone: _PillTone.primary,
                              ),
                              _InfoPill(
                                label: '1 task moi man hinh',
                                tone: _PillTone.neutral,
                              ),
                              _InfoPill(
                                label: 'Feedback ngay sau moi lan noi',
                                tone: _PillTone.accent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_recentAttempts.isNotEmpty) ...[
                      _RecentAttemptsSection(
                        attempts: _recentAttempts.take(5).toList(),
                        exerciseTitleForAttempt: _exerciseTitleForAttempt,
                        onOpenAttemptExercise: (attempt) async {
                          final navigator = Navigator.of(context);
                          final detail = ExerciseDetail.fromJson(
                            await _client.getExercise(attempt.exerciseId),
                          );
                          if (!mounted) {
                            return;
                          }
                          await navigator.push(
                            MaterialPageRoute(
                              builder:
                                  (_) => ExerciseScreen(
                                    client: _client,
                                    detail: detail,
                                  ),
                            ),
                          );
                          await _loadRecentAttempts();
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                    for (final module in _modules) ...[
                      _ModuleCard(
                        module: module,
                        exercises: _exercisesByModule[module.id] ?? const [],
                        onOpenExercise: (exercise) async {
                          final navigator = Navigator.of(context);
                          final detail = ExerciseDetail.fromJson(
                            await _client.getExercise(exercise.id),
                          );
                          if (!mounted) {
                            return;
                          }
                          await navigator.push(
                            MaterialPageRoute(
                              builder:
                                  (_) => ExerciseScreen(
                                    client: _client,
                                    detail: detail,
                                  ),
                            ),
                          );
                          await _loadRecentAttempts();
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
      ),
    );
  }

  Future<void> _loadRecentAttempts() async {
    try {
      final attemptsPayload = await _client.getAttempts();
      if (!mounted) {
        return;
      }
      setState(() {
        _recentAttempts =
            attemptsPayload
                .map(
                  (item) =>
                      AttemptResult.fromJson(item as Map<String, dynamic>),
                )
                .toList();
      });
    } catch (_) {
      // Keep the shell usable if the attempt history refresh fails.
    }
  }

  String _exerciseTitleForAttempt(AttemptResult attempt) {
    for (final exercises in _exercisesByModule.values) {
      for (final exercise in exercises) {
        if (exercise.id == attempt.exerciseId) {
          return exercise.title;
        }
      }
    }
    return attempt.exerciseId;
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.exercises,
    required this.onOpenExercise,
  });

  final ModuleSummary module;
  final List<ExerciseSummary> exercises;
  final ValueChanged<ExerciseSummary> onOpenExercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.all(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              module.moduleKind.replaceAll('_', ' '),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            module.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${exercises.length} bai tap trong module nay',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          for (final exercise in exercises) ...[
            InkWell(
              onTap: () => onOpenExercise(exercise),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.surfaceMuted,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(exercise.shortInstruction),
                    const SizedBox(height: 8),
                    Text(
                      exercise.exerciseType,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _RecentAttemptsSection extends StatelessWidget {
  const _RecentAttemptsSection({
    required this.attempts,
    required this.exerciseTitleForAttempt,
    required this.onOpenAttemptExercise,
  });

  final List<AttemptResult> attempts;
  final String Function(AttemptResult attempt) exerciseTitleForAttempt;
  final ValueChanged<AttemptResult> onOpenAttemptExercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.all(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lan tap gan day',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Xem transcript va feedback cua cac lan noi gan nhat de theo doi tien bo that nhanh.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < attempts.length; index++) ...[
            _RecentAttemptCard(
              attempt: attempts[index],
              exerciseTitle: exerciseTitleForAttempt(attempts[index]),
              onOpen: () => onOpenAttemptExercise(attempts[index]),
            ),
            if (index != attempts.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _RecentAttemptCard extends StatelessWidget {
  const _RecentAttemptCard({
    required this.attempt,
    required this.exerciseTitle,
    required this.onOpen,
  });

  final AttemptResult attempt;
  final String exerciseTitle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final preview =
        attempt.feedback?.overallSummary.isNotEmpty == true
            ? attempt.feedback!.overallSummary
            : (attempt.transcriptPreview.isNotEmpty
                ? attempt.transcriptPreview
                : _statusCopy(attempt.status));
    final readinessTone = _readinessTone(attempt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatAttemptTimestamp(attempt.startedAt),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: readinessTone.$2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  readinessTone.$1,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            preview,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.text),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoPill(
                label: 'Status: ${attempt.status}',
                tone: _PillTone.neutral,
              ),
              if (attempt.transcriptIsSynthetic)
                _InfoPill(label: 'Transcript gia lap', tone: _PillTone.primary),
              if (attempt.failureCode.isNotEmpty)
                _InfoPill(
                  label: 'Failure: ${attempt.failureCode}',
                  tone: _PillTone.primary,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onOpen,
              child: const Text('Open exercise'),
            ),
          ),
        ],
      ),
    );
  }
}

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key, required this.client, required this.detail});

  final ApiClient client;
  final ExerciseDetail detail;

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  String _status = 'ready';
  String? _attemptId;
  String? _recordingPath;
  int _seconds = 0;
  Timer? _ticker;
  Timer? _poller;
  AttemptResult? _result;
  String? _error;
  String? _playbackPath;
  String? _playbackError;
  Duration _playbackPosition = Duration.zero;
  Duration? _playbackDuration;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _playerPositionSubscription;
  StreamSubscription<Duration?>? _playerDurationSubscription;
  StreamSubscription<PlayerException>? _playerErrorSubscription;

  @override
  void initState() {
    super.initState();
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) {
        return;
      }
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        setState(() {
          _playbackPosition = Duration.zero;
        });
      } else {
        setState(() {});
      }
    });
    _playerPositionSubscription = _player.positionStream.listen((position) {
      if (!mounted) {
        return;
      }
      setState(() {
        _playbackPosition = position;
      });
    });
    _playerDurationSubscription = _player.durationStream.listen((duration) {
      if (!mounted) {
        return;
      }
      setState(() {
        _playbackDuration = duration;
      });
    });
    _playerErrorSubscription = _player.errorStream.listen((error) {
      _logAudioDebug(
        'local_attempt_playback_stream',
        error,
        extra: {'attempt_id': _attemptId, 'recording_path': _playbackPath},
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _playbackError = _playbackErrorMessage(
          'Playback gap loi. Thu nghe lai sau mot lan ghi moi.',
          error,
        );
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _poller?.cancel();
    _playerStateSubscription?.cancel();
    _playerPositionSubscription?.cancel();
    _playerDurationSubscription?.cancel();
    _playerErrorSubscription?.cancel();
    _recorder.dispose();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _error = null;
      _result = null;
      _seconds = 0;
      _status = 'starting';
      _playbackError = null;
    });
    try {
      await _player.stop();
      await _player.seek(Duration.zero);
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        throw const FileSystemException(
          'Microphone permission was not granted.',
        );
      }

      final attempt = await widget.client.createAttempt(widget.detail.id);
      _attemptId = attempt['id'] as String;
      _recordingPath = await _buildRecordingPath(_attemptId!);
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: _recordingPath!,
      );
      await widget.client.markRecordingStarted(_attemptId!);
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _seconds += 1;
        });
      });
      setState(() {
        _status = 'recording';
      });
    } catch (err) {
      setState(() {
        _status = 'ready';
        _error = err.toString();
      });
    }
  }

  Future<void> _stopRecording() async {
    if (_attemptId == null) {
      return;
    }
    _ticker?.cancel();
    setState(() {
      _status = 'uploading';
    });
    try {
      final recordedPath = await _recorder.stop();
      final audioPath = recordedPath ?? _recordingPath;
      if (audioPath == null) {
        throw const FileSystemException('Recording file was not created.');
      }
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        throw FileSystemException('Recording file not found.', audioPath);
      }
      final fileSizeBytes = await audioFile.length();
      await _preparePlayback(audioPath);

      await widget.client.submitRecordedAudio(
        _attemptId!,
        audioPath: audioPath,
        mimeType: 'audio/m4a',
        fileSizeBytes: fileSizeBytes,
        durationMs: _seconds * 1000,
      );
      setState(() {
        _status = 'processing';
        _recordingPath = audioPath;
      });
      _poller?.cancel();
      _poller = Timer.periodic(const Duration(seconds: 2), (_) async {
        final attempt = AttemptResult.fromJson(
          await widget.client.getAttempt(_attemptId!),
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _result = attempt;
          _status = attempt.status;
        });
        if (attempt.status == 'completed' || attempt.status == 'failed') {
          _poller?.cancel();
        }
      });
    } catch (err) {
      setState(() {
        _status = 'ready';
        _error = err.toString();
      });
    }
  }

  Future<void> _preparePlayback(String audioPath) async {
    try {
      await _player.setFilePath(audioPath);
      if (!mounted) {
        return;
      }
      setState(() {
        _playbackPath = audioPath;
        _playbackError = null;
        _playbackPosition = Duration.zero;
        _playbackDuration = _player.duration;
      });
    } catch (err) {
      _logAudioDebug(
        'local_attempt_prepare',
        err,
        stackTrace: StackTrace.current,
        extra: {'audio_path': audioPath},
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _playbackPath = audioPath;
        _playbackError = _playbackErrorMessage(
          'Khong mo duoc ban ghi de nghe lai.',
          err,
        );
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_playbackPath == null) {
      return;
    }
    try {
      final duration = _playbackDuration ?? _player.duration;
      if (_player.playing) {
        await _player.pause();
        return;
      }
      if (duration != null && _playbackPosition >= duration) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    } catch (err) {
      _logAudioDebug(
        'local_attempt_toggle',
        err,
        stackTrace: StackTrace.current,
        extra: {'audio_path': _playbackPath, 'attempt_id': _attemptId},
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _playbackError = _playbackErrorMessage(
          'Playback gap loi. Thu nghe lai sau mot lan ghi moi.',
          err,
        );
      });
    }
  }

  Future<void> _seekPlayback(double value) async {
    final duration = _playbackDuration;
    if (duration == null) {
      return;
    }
    final target = Duration(milliseconds: value.round());
    await _player.seek(target > duration ? duration : target);
  }

  Future<void> _resetForRetryWithModel() async {
    _ticker?.cancel();
    _poller?.cancel();
    await _player.stop();
    await _player.seek(Duration.zero);
    if (!mounted) {
      return;
    }
    setState(() {
      _status = 'ready';
      _attemptId = null;
      _recordingPath = null;
      _seconds = 0;
      _result = null;
      _error = null;
      _playbackPath = null;
      _playbackError = null;
      _playbackPosition = Duration.zero;
      _playbackDuration = null;
    });
  }

  Future<String> _buildRecordingPath(String attemptId) async {
    final tempDirectory = await getTemporaryDirectory();
    return '${tempDirectory.path}/attempt_$attemptId.m4a';
  }

  @override
  Widget build(BuildContext context) {
    final canStart = _status == 'ready';
    final isRecording = _status == 'recording';

    return Scaffold(
      appBar: AppBar(title: Text(widget.detail.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.all(AppRadii.card),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _exerciseTypeLabel(widget.detail.exerciseType),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(widget.detail.learnerInstruction),
                const SizedBox(height: 16),
                ..._buildExercisePromptCards(context),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coach note',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Noi ngan, ro y, dung cau don gian truoc. V1 uu tien tra loi dung task hon la co gang noi qua phuc tap.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.all(AppRadii.card),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Attempt status: $_status',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_seconds}s',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_seconds / 45).clamp(0, 1),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: AppColors.surfaceMuted,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _statusCopy(_status),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: canStart ? _startRecording : null,
                      child: const Text('Start practice'),
                    ),
                    OutlinedButton(
                      onPressed: isRecording ? _stopRecording : null,
                      child: const Text('Stop and analyze'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _recordingPath == null
                      ? 'App dang ghi am that vao file local de khoa UX truoc khi cam upload binary that.'
                      : 'Ban ghi hien tai: ${_recordingPath!.split(Platform.pathSeparator).last}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                if (_playbackPath != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nghe lai bai vua ghi',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Learner co the nghe lai truoc khi thu mot lan moi.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            FilledButton.tonal(
                              onPressed:
                                  _playbackError == null
                                      ? _togglePlayback
                                      : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accentSoft,
                                foregroundColor: AppColors.accent,
                              ),
                              child: Text(_player.playing ? 'Pause' : 'Play'),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${_formatPlaybackDuration(_playbackPosition)} / ${_formatPlaybackDuration(_playbackDuration ?? Duration.zero)}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.muted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                          ),
                          child: Slider(
                            min: 0,
                            max: ((_playbackDuration ?? Duration.zero)
                                    .inMilliseconds
                                    .toDouble())
                                .clamp(1, double.infinity),
                            value:
                                _playbackDuration == null
                                    ? 0
                                    : _playbackPosition.inMilliseconds
                                        .clamp(
                                          0,
                                          _playbackDuration!.inMilliseconds,
                                        )
                                        .toDouble(),
                            onChanged:
                                _playbackDuration == null
                                    ? null
                                    : (value) =>
                                        unawaited(_seekPlayback(value)),
                          ),
                        ),
                        if (_playbackError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _playbackError!,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            _ResultCard(
              client: widget.client,
              result: _result!,
              onRetryWithModel: _resetForRetryWithModel,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildExercisePromptCards(BuildContext context) {
    if (widget.detail.exerciseType == 'uloha_2_dialogue_questions') {
      final cards = <Widget>[
        if (widget.detail.scenarioTitle.isNotEmpty) ...[
          Text(
            widget.detail.scenarioTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
        ],
        if (widget.detail.scenarioPrompt.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(widget.detail.scenarioPrompt),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          'Thong tin ban can hoi',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
      ];

      for (final slot in widget.detail.requiredInfoSlots) {
        cards.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (slot.sampleQuestion.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Goi y: ${slot.sampleQuestion}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        );
        cards.add(const SizedBox(height: 10));
      }

      if (widget.detail.customQuestionHint.isNotEmpty) {
        cards.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'Cau hoi bo sung: ${widget.detail.customQuestionHint}',
              style: const TextStyle(color: AppColors.primaryStrong),
            ),
          ),
        );
        cards.add(const SizedBox(height: 10));
      }

      return cards;
    }

    if (widget.detail.exerciseType == 'uloha_3_story_narration') {
      final storyImageAssets = widget.detail.storyImageAssets;
      final missingStoryImageCount =
          widget.detail.imageAssetIds.length - storyImageAssets.length;
      final cards = <Widget>[
        if (widget.detail.storyTitle.isNotEmpty) ...[
          Text(
            widget.detail.storyTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
        ],
        if (storyImageAssets.isNotEmpty) ...[
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: storyImageAssets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final asset = storyImageAssets[index];
                return _ExerciseImageCard(
                  label: 'Obrazek ${index + 1}',
                  imageUrl:
                      widget.client
                          .exerciseAssetUri(widget.detail.id, asset.id)
                          .toString(),
                  headers: widget.client.authHeaders(),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (widget.detail.imageAssetIds.isEmpty) ...[
          const _PromptHintCard(
            title: 'Images are optional for now',
            body:
                'Task nay van test duoc theo checkpoint text. Khi CMS gan image asset, learner screen se hien o day.',
            tone: _PromptHintTone.neutral,
          ),
          const SizedBox(height: 14),
        ] else if (missingStoryImageCount > 0) ...[
          _PromptHintCard(
            title: 'Some images are still missing',
            body:
                'Da dang ky ${storyImageAssets.length} / ${widget.detail.imageAssetIds.length} prompt images. Neu can, quay lai CMS de kiem tra asset id va upload.',
            tone: _PromptHintTone.warning,
          ),
          const SizedBox(height: 14),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.detail.imageAssetIds.isEmpty
                ? 'Ke cau chuyen theo thu tu nejdriv, pak, nakonec.'
                : 'Hay ke cau chuyen theo ${widget.detail.imageAssetIds.length} buc tranh theo dung thu tu.',
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Cac moc can nhac den',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
      ];

      for (final checkpoint in widget.detail.narrativeCheckpoints) {
        cards.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(checkpoint),
          ),
        );
        cards.add(const SizedBox(height: 10));
      }

      if (widget.detail.grammarFocus.isNotEmpty) {
        cards.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'Ngu phap nen uu tien: ${widget.detail.grammarFocus.join(', ')}',
              style: const TextStyle(color: AppColors.primaryStrong),
            ),
          ),
        );
        cards.add(const SizedBox(height: 10));
      }

      return cards;
    }

    if (widget.detail.exerciseType == 'uloha_4_choice_reasoning') {
      final cards = <Widget>[
        if (widget.detail.choiceScenarioPrompt.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(widget.detail.choiceScenarioPrompt),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          'Cac lua chon',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
      ];

      for (final option in widget.detail.choiceOptions) {
        final optionAsset =
            option.imageAssetId.isEmpty
                ? null
                : widget.detail.assetById(option.imageAssetId);
        cards.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (optionAsset?.isImage == true) ...[
                  _ExerciseImageCard(
                    label: option.label,
                    imageUrl:
                        widget.client
                            .exerciseAssetUri(
                              widget.detail.id,
                              option.imageAssetId,
                            )
                            .toString(),
                    headers: widget.client.authHeaders(),
                    aspectRatio: 16 / 9,
                  ),
                  const SizedBox(height: 10),
                ] else if (option.imageAssetId.isNotEmpty) ...[
                  _PromptHintCard(
                    title: 'Choice image unavailable',
                    body:
                        'Option nay dang tro toi asset `${option.imageAssetId}`, nhung learner app chua tim thay anh hop le.',
                    tone: _PromptHintTone.warning,
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  option.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (option.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    option.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        );
        cards.add(const SizedBox(height: 10));
      }

      if (widget.detail.expectedReasoningAxes.isNotEmpty) {
        cards.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'Goi y ly do: ${widget.detail.expectedReasoningAxes.join(', ')}',
              style: const TextStyle(color: AppColors.primaryStrong),
            ),
          ),
        );
        cards.add(const SizedBox(height: 10));
      }

      return cards;
    }

    return [
      for (final question in widget.detail.questions) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(question),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  String _exerciseTypeLabel(String exerciseType) {
    switch (exerciseType) {
      case 'uloha_2_dialogue_questions':
        return 'Uloha 2 · Dialogue questions';
      case 'uloha_3_story_narration':
        return 'Uloha 3 · Story narration';
      case 'uloha_4_choice_reasoning':
        return 'Uloha 4 · Choice reasoning';
      default:
        return 'Uloha 1 · Topic answers';
    }
  }
}

String _formatPlaybackDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _ExerciseImageCard extends StatelessWidget {
  const _ExerciseImageCard({
    required this.label,
    required this.imageUrl,
    required this.headers,
    this.aspectRatio = 1,
  });

  final String label;
  final String imageUrl;
  final Map<String, String> headers;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const _ImageStateCard(
        icon: Icons.image_not_supported_outlined,
        title: 'No image yet',
        message: 'Prompt image has not been attached yet.',
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: aspectRatio == 1 ? 132 : 220,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.surfaceMuted,
                child: Image.network(
                  imageUrl,
                  headers: headers,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) {
                      return child;
                    }
                    final expectedBytes = progress.expectedTotalBytes;
                    final cumulativeBytes = progress.cumulativeBytesLoaded;
                    final value =
                        expectedBytes == null || expectedBytes == 0
                            ? null
                            : cumulativeBytes / expectedBytes;
                    return Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          value: value,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const _ImageStateCard(
                      icon: Icons.broken_image_outlined,
                      title: 'Image unavailable',
                      message: 'Learner app khong tai duoc prompt image nay.',
                    );
                  },
                ),
              ),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(13, 18, 24, 0.72),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PromptHintTone { neutral, warning }

class _PromptHintCard extends StatelessWidget {
  const _PromptHintCard({
    required this.title,
    required this.body,
    required this.tone,
  });

  final String title;
  final String body;
  final _PromptHintTone tone;

  @override
  Widget build(BuildContext context) {
    final background = switch (tone) {
      _PromptHintTone.neutral => AppColors.surfaceMuted,
      _PromptHintTone.warning => AppColors.primarySoft,
    };
    final foreground = switch (tone) {
      _PromptHintTone.neutral => AppColors.muted,
      _PromptHintTone.warning => AppColors.primaryStrong,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _ImageStateCard extends StatelessWidget {
  const _ImageStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.muted, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.client,
    required this.result,
    required this.onRetryWithModel,
  });

  final ApiClient client;
  final AttemptResult result;
  final Future<void> Function() onRetryWithModel;

  @override
  Widget build(BuildContext context) {
    final feedback = result.feedback;
    final transcriptSourceLabel = _transcriptSourceLabel(result);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.all(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Transcript tu backend',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (transcriptSourceLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        result.transcriptIsSynthetic
                            ? AppColors.primarySoft
                            : AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    transcriptSourceLabel,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (result.transcriptIsSynthetic) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Transcript nay dang la ban gia lap cho local dev. Feedback ben duoi dang dua tren transcript mau theo task va do dai file, khong phai noi dung audio that cua ban.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.text),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(result.transcript ?? 'Transcript chua san sang.'),
          if (result.audio != null) ...[
            const SizedBox(height: 14),
            _AttemptAudioPlaybackCard(
              client: client,
              attemptId: result.id,
              audio: result.audio!,
            ),
          ],
          if (feedback != null) ...[
            const SizedBox(height: 18),
            Text(
              feedback.readinessLevel,
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(feedback.overallSummary),
            const SizedBox(height: 14),
            _FeedbackSection(
              title: 'Strengths',
              items: feedback.strengths,
              tone: _FeedbackTone.success,
            ),
            const SizedBox(height: 14),
            _FeedbackSection(
              title: 'Improve next',
              items: feedback.improvements,
              tone: _FeedbackTone.primary,
            ),
            const SizedBox(height: 14),
            _FeedbackSection(
              title: 'Retry advice',
              items: feedback.retryAdvice,
              tone: _FeedbackTone.accent,
            ),
            if (feedback.sampleAnswer.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Sample answer',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(feedback.sampleAnswer),
            ],
          ],
          if (result.status == 'completed') ...[
            const SizedBox(height: 18),
            _ReviewArtifactSection(
              client: client,
              result: result,
              onRetryWithModel: onRetryWithModel,
            ),
          ],
        ],
      ),
    );
  }
}

String _transcriptSourceLabel(AttemptResult result) {
  if (result.transcriptIsSynthetic) {
    return 'Transcript gia lap';
  }
  switch (result.transcriptProvider) {
    case 'amazon_transcribe':
      return 'Amazon Transcribe';
    case 'dev_stub':
      return 'Transcript gia lap';
    default:
      return '';
  }
}

class _ReviewArtifactSection extends StatefulWidget {
  const _ReviewArtifactSection({
    required this.client,
    required this.result,
    required this.onRetryWithModel,
  });

  final ApiClient client;
  final AttemptResult result;
  final Future<void> Function() onRetryWithModel;

  @override
  State<_ReviewArtifactSection> createState() => _ReviewArtifactSectionState();
}

class _ReviewArtifactSectionState extends State<_ReviewArtifactSection> {
  AttemptReviewArtifactView? _artifact;
  Timer? _poller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadReviewArtifact());
  }

  @override
  void didUpdateWidget(covariant _ReviewArtifactSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result.id != widget.result.id) {
      _poller?.cancel();
      _artifact = null;
      _loading = true;
      _error = null;
      unawaited(_loadReviewArtifact());
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _loadReviewArtifact() async {
    try {
      final artifact = AttemptReviewArtifactView.fromJson(
        await widget.client.getAttemptReview(widget.result.id),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _artifact = artifact;
        _loading = false;
        _error = null;
      });
      _syncPolling(artifact);
    } catch (err) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = err.toString();
      });
    }
  }

  void _syncPolling(AttemptReviewArtifactView artifact) {
    if (artifact.isPending) {
      _poller ??= Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_loadReviewArtifact());
      });
      return;
    }
    _poller?.cancel();
    _poller = null;
  }

  @override
  Widget build(BuildContext context) {
    final artifact = _artifact;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Repair and shadowing',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Ban nay tach ro transcript cua ban, ban da sua, va ban mau de shadow theo.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          if (_loading && artifact == null) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            ),
          ] else if (_error != null && artifact == null) ...[
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: _loadReviewArtifact,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primarySoft,
                foregroundColor: AppColors.primaryStrong,
              ),
              child: const Text('Retry review'),
            ),
          ] else if (artifact == null || artifact.isPending) ...[
            _ReviewStatusCard(
              title: 'Dang tao ban sua va audio mau...',
              body:
                  'Learner van co the doc feedback hien tai truoc, review artifact se xuat hien ngay khi backend xong.',
              tone: _ReviewStatusTone.pending,
            ),
          ] else if (artifact.isFailed) ...[
            _ReviewStatusCard(
              title: 'Review artifact gap loi',
              body:
                  artifact.failureCode.isEmpty
                      ? 'Backend chua tao duoc ban sua cho attempt nay.'
                      : 'Backend tra ve failure_code: ${artifact.failureCode}',
              tone: _ReviewStatusTone.failed,
            ),
          ] else ...[
            _ReviewTextBlock(
              title: 'Transcript cua ban',
              body:
                  artifact.sourceTranscriptText.isEmpty
                      ? (widget.result.transcript ??
                          'Transcript chua san sang.')
                      : artifact.sourceTranscriptText,
              tone: _ReviewBlockTone.neutral,
            ),
            const SizedBox(height: 12),
            _ReviewTextBlock(
              title: 'Ban nen noi',
              body: artifact.correctedTranscriptText,
              tone: _ReviewBlockTone.primary,
            ),
            const SizedBox(height: 12),
            _ReviewTextBlock(
              title: 'Ban mau de shadow',
              body: artifact.modelAnswerText,
              tone: _ReviewBlockTone.accent,
            ),
            if (artifact.diffChunks.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ReviewDiffBlock(chunks: artifact.diffChunks),
            ],
            if (artifact.speakingFocusItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SpeakingFocusBlock(items: artifact.speakingFocusItems),
            ],
            if (artifact.ttsAudio != null) ...[
              const SizedBox(height: 12),
              _ReviewArtifactAudioPlaybackCard(
                client: widget.client,
                attemptId: widget.result.id,
                audio: artifact.ttsAudio!,
              ),
            ],
            const SizedBox(height: 12),
            _RetryWithModelCard(onPressed: widget.onRetryWithModel),
          ],
        ],
      ),
    );
  }
}

class _RetryWithModelCard extends StatelessWidget {
  const _RetryWithModelCard({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Retry with this model',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.primaryStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Quay lai cung bai nay de bat dau mot attempt moi binh thuong sau khi nghe ban mau.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.primaryStrong),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => unawaited(onPressed()),
            child: const Text('Retry with this model'),
          ),
        ],
      ),
    );
  }
}

enum _ReviewStatusTone { pending, failed }

class _ReviewStatusCard extends StatelessWidget {
  const _ReviewStatusCard({
    required this.title,
    required this.body,
    required this.tone,
  });

  final String title;
  final String body;
  final _ReviewStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final background = switch (tone) {
      _ReviewStatusTone.pending => AppColors.accentSoft,
      _ReviewStatusTone.failed => AppColors.primarySoft,
    };
    final foreground = switch (tone) {
      _ReviewStatusTone.pending => AppColors.accent,
      _ReviewStatusTone.failed => AppColors.danger,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

enum _ReviewBlockTone { neutral, primary, accent }

class _ReviewTextBlock extends StatelessWidget {
  const _ReviewTextBlock({
    required this.title,
    required this.body,
    required this.tone,
  });

  final String title;
  final String body;
  final _ReviewBlockTone tone;

  @override
  Widget build(BuildContext context) {
    final background = switch (tone) {
      _ReviewBlockTone.neutral => AppColors.surface,
      _ReviewBlockTone.primary => AppColors.primarySoft,
      _ReviewBlockTone.accent => AppColors.accentSoft,
    };
    final foreground = switch (tone) {
      _ReviewBlockTone.neutral => AppColors.text,
      _ReviewBlockTone.primary => AppColors.primaryStrong,
      _ReviewBlockTone.accent => AppColors.accent,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(body.isEmpty ? 'Chua co noi dung.' : body),
        ],
      ),
    );
  }
}

class _ReviewDiffBlock extends StatelessWidget {
  const _ReviewDiffBlock({required this.chunks});

  final List<DiffChunkView> chunks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cho sua nhanh',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final chunk in chunks) ...[
            _DiffChunkTile(chunk: chunk),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _DiffChunkTile extends StatelessWidget {
  const _DiffChunkTile({required this.chunk});

  final DiffChunkView chunk;

  @override
  Widget build(BuildContext context) {
    final background = switch (chunk.kind) {
      'inserted' => AppColors.successSoft,
      'replaced' => AppColors.primarySoft,
      'deleted' => AppColors.primarySoft,
      _ => AppColors.surfaceMuted,
    };
    final label = switch (chunk.kind) {
      'inserted' => 'Them',
      'replaced' => 'Sua',
      'deleted' => 'Bo',
      _ => 'Giu nguyen',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (chunk.sourceText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Ban noi: ${chunk.sourceText}'),
          ],
          if (chunk.targetText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Nen noi: ${chunk.targetText}'),
          ],
        ],
      ),
    );
  }
}

class _SpeakingFocusBlock extends StatelessWidget {
  const _SpeakingFocusBlock({required this.items});

  final List<SpeakingFocusItemView> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Speaking focus',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final item in items) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(item.commentVi),
                  if (item.learnerFragment.isNotEmpty ||
                      item.targetFragment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    if (item.learnerFragment.isNotEmpty)
                      Text('Ban noi: ${item.learnerFragment}'),
                    if (item.targetFragment.isNotEmpty)
                      Text('Nen thu: ${item.targetFragment}'),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewArtifactAudioPlaybackCard extends StatefulWidget {
  const _ReviewArtifactAudioPlaybackCard({
    required this.client,
    required this.attemptId,
    required this.audio,
  });

  final ApiClient client;
  final String attemptId;
  final ReviewArtifactAudioView audio;

  @override
  State<_ReviewArtifactAudioPlaybackCard> createState() =>
      _ReviewArtifactAudioPlaybackCardState();
}

class _ReviewArtifactAudioPlaybackCardState
    extends State<_ReviewArtifactAudioPlaybackCard> {
  final AudioPlayer _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration? _duration;
  String? _error;
  bool _loading = true;
  String? _downloadedAudioPath;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _playerPositionSubscription;
  StreamSubscription<Duration?>? _playerDurationSubscription;
  StreamSubscription<PlayerException>? _playerErrorSubscription;

  @override
  void initState() {
    super.initState();
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) {
        return;
      }
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        setState(() {
          _position = Duration.zero;
        });
      } else {
        setState(() {});
      }
    });
    _playerPositionSubscription = _player.positionStream.listen((position) {
      if (!mounted) {
        return;
      }
      setState(() {
        _position = position;
      });
    });
    _playerDurationSubscription = _player.durationStream.listen((duration) {
      if (!mounted) {
        return;
      }
      setState(() {
        _duration = duration;
      });
    });
    _playerErrorSubscription = _player.errorStream.listen((error) {
      _logAudioDebug(
        'review_audio_playback_stream',
        error,
        extra: {
          'attempt_id': widget.attemptId,
          'audio_url':
              widget.client.attemptReviewAudioUri(widget.attemptId).toString(),
          'mime_type': widget.audio.mimeType,
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _playbackErrorMessage(
          'Khong mo duoc audio mau tu backend.',
          error,
        );
      });
    });
    unawaited(_prepareRemoteAudio());
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _playerPositionSubscription?.cancel();
    _playerDurationSubscription?.cancel();
    _playerErrorSubscription?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _prepareRemoteAudio() async {
    try {
      final tempDirectory = await getTemporaryDirectory();
      final audioExtension = _inferAudioExtension(
        widget.audio.storageKey,
        widget.audio.mimeType,
      );
      final downloadedFile = await widget.client.downloadAttemptReviewAudio(
        widget.attemptId,
        destinationPath:
            '${tempDirectory.path}/review_model_${widget.attemptId}.$audioExtension',
      );
      final duration = await _player.setFilePath(downloadedFile.path);
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = null;
        _downloadedAudioPath = downloadedFile.path;
        _position = Duration.zero;
        _duration = duration ?? _player.duration;
      });
    } catch (err) {
      _logAudioDebug(
        'review_audio_prepare',
        err,
        stackTrace: StackTrace.current,
        extra: {
          'attempt_id': widget.attemptId,
          'audio_url':
              widget.client.attemptReviewAudioUri(widget.attemptId).toString(),
          'mime_type': widget.audio.mimeType,
          'storage_key': widget.audio.storageKey,
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = _playbackErrorMessage(
          'Khong tai duoc audio mau tu backend.',
          err,
        );
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_loading || _error != null) {
      return;
    }
    try {
      final duration = _duration ?? _player.duration;
      if (_player.playing) {
        await _player.pause();
        return;
      }
      if (duration != null && _position >= duration) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    } catch (err) {
      _logAudioDebug(
        'review_audio_toggle',
        err,
        stackTrace: StackTrace.current,
        extra: {
          'attempt_id': widget.attemptId,
          'downloaded_audio_path': _downloadedAudioPath,
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _playbackErrorMessage('Playback audio mau gap loi.', err);
      });
    }
  }

  Future<void> _seekPlayback(double value) async {
    final duration = _duration;
    if (duration == null) {
      return;
    }
    final target = Duration(milliseconds: value.round());
    await _player.seek(target > duration ? duration : target);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nghe ban mau',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _downloadedAudioPath == null
                ? 'Dang tai audio mau ve may...'
                : 'Da cache local: ${_downloadedAudioPath!.split(Platform.pathSeparator).last}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.tonal(
                onPressed: _loading || _error != null ? null : _togglePlayback,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentSoft,
                  foregroundColor: AppColors.accent,
                ),
                child: Text(
                  _loading
                      ? 'Loading...'
                      : (_player.playing ? 'Pause' : 'Play'),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_formatPlaybackDuration(_position)} / ${_formatPlaybackDuration(_duration ?? Duration.zero)}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              min: 0,
              max: ((_duration ?? Duration.zero).inMilliseconds.toDouble())
                  .clamp(1, double.infinity),
              value:
                  _duration == null
                      ? 0
                      : _position.inMilliseconds
                          .clamp(0, _duration!.inMilliseconds)
                          .toDouble(),
              onChanged:
                  _duration == null || _loading || _error != null
                      ? null
                      : (value) => unawaited(_seekPlayback(value)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
        ],
      ),
    );
  }
}

class _AttemptAudioPlaybackCard extends StatefulWidget {
  const _AttemptAudioPlaybackCard({
    required this.client,
    required this.attemptId,
    required this.audio,
  });

  final ApiClient client;
  final String attemptId;
  final AttemptAudioView audio;

  @override
  State<_AttemptAudioPlaybackCard> createState() =>
      _AttemptAudioPlaybackCardState();
}

class _AttemptAudioPlaybackCardState extends State<_AttemptAudioPlaybackCard> {
  final AudioPlayer _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration? _duration;
  String? _error;
  bool _loading = true;
  String? _downloadedAudioPath;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _playerPositionSubscription;
  StreamSubscription<Duration?>? _playerDurationSubscription;
  StreamSubscription<PlayerException>? _playerErrorSubscription;

  @override
  void initState() {
    super.initState();
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) {
        return;
      }
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        setState(() {
          _position = Duration.zero;
        });
      } else {
        setState(() {});
      }
    });
    _playerPositionSubscription = _player.positionStream.listen((position) {
      if (!mounted) {
        return;
      }
      setState(() {
        _position = position;
      });
    });
    _playerDurationSubscription = _player.durationStream.listen((duration) {
      if (!mounted) {
        return;
      }
      setState(() {
        _duration = duration;
      });
    });
    _playerErrorSubscription = _player.errorStream.listen((error) {
      _logAudioDebug(
        'remote_attempt_playback_stream',
        error,
        extra: {
          'attempt_id': widget.attemptId,
          'audio_url':
              widget.client.attemptAudioUri(widget.attemptId).toString(),
          'mime_type': widget.audio.mimeType,
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _playbackErrorMessage(
          'Khong mo duoc audio da nop tu backend.',
          error,
        );
      });
    });
    unawaited(_prepareRemoteAudio());
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _playerPositionSubscription?.cancel();
    _playerDurationSubscription?.cancel();
    _playerErrorSubscription?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _prepareRemoteAudio() async {
    try {
      final tempDirectory = await getTemporaryDirectory();
      final audioExtension = _inferAudioExtension(
        widget.audio.storageKey,
        widget.audio.mimeType,
      );
      final downloadedFile = await widget.client.downloadAttemptAudio(
        widget.attemptId,
        destinationPath:
            '${tempDirectory.path}/submitted_attempt_${widget.attemptId}.$audioExtension',
      );
      final duration = await _player.setFilePath(downloadedFile.path);
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = null;
        _downloadedAudioPath = downloadedFile.path;
        _position = Duration.zero;
        _duration = duration ?? _player.duration;
      });
    } catch (err) {
      _logAudioDebug(
        'remote_attempt_prepare',
        err,
        stackTrace: StackTrace.current,
        extra: {
          'attempt_id': widget.attemptId,
          'audio_url':
              widget.client.attemptAudioUri(widget.attemptId).toString(),
          'mime_type': widget.audio.mimeType,
          'storage_key': widget.audio.storageKey,
          'downloaded_audio_path': _downloadedAudioPath,
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = _playbackErrorMessage(
          'Khong mo duoc audio da nop tu backend.',
          err,
        );
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_loading || _error != null) {
      return;
    }
    try {
      final duration = _duration ?? _player.duration;
      if (_player.playing) {
        await _player.pause();
        return;
      }
      if (duration != null && _position >= duration) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    } catch (err) {
      _logAudioDebug(
        'remote_attempt_toggle',
        err,
        stackTrace: StackTrace.current,
        extra: {
          'attempt_id': widget.attemptId,
          'audio_url':
              widget.client.attemptAudioUri(widget.attemptId).toString(),
          'downloaded_audio_path': _downloadedAudioPath,
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _playbackErrorMessage(
          'Playback audio backend gap loi. Thu tai lai attempt sau.',
          err,
        );
      });
    }
  }

  Future<void> _seekPlayback(double value) async {
    final duration = _duration;
    if (duration == null) {
      return;
    }
    final target = Duration(milliseconds: value.round());
    await _player.seek(target > duration ? duration : target);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nghe lai audio da nop',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _downloadedAudioPath == null
                ? 'Dang tai audio tu backend ve may...'
                : 'Da cache local: ${_downloadedAudioPath!.split(Platform.pathSeparator).last}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          Text(
            'Duration: ${(widget.audio.durationMs / 1000).toStringAsFixed(1)}s',
          ),
          Text('Size: ${widget.audio.fileSizeBytes} bytes'),
          Text('Type: ${widget.audio.mimeType}'),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton.tonal(
                onPressed: _loading || _error != null ? null : _togglePlayback,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentSoft,
                  foregroundColor: AppColors.accent,
                ),
                child: Text(
                  _loading
                      ? 'Loading...'
                      : (_player.playing ? 'Pause' : 'Play'),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_formatPlaybackDuration(_position)} / ${_formatPlaybackDuration(_duration ?? Duration.zero)}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              min: 0,
              max: ((_duration ?? Duration.zero).inMilliseconds.toDouble())
                  .clamp(1, double.infinity),
              value:
                  _duration == null
                      ? 0
                      : _position.inMilliseconds
                          .clamp(0, _duration!.inMilliseconds)
                          .toDouble(),
              onChanged:
                  _duration == null || _loading || _error != null
                      ? null
                      : (value) => unawaited(_seekPlayback(value)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
        ],
      ),
    );
  }
}

String _inferAudioExtension(String storageKey, String mimeType) {
  final dotIndex = storageKey.lastIndexOf('.');
  if (dotIndex >= 0 && dotIndex < storageKey.length - 1) {
    final storageExtension = storageKey.substring(dotIndex + 1);
    return storageExtension;
  }

  switch (mimeType.toLowerCase()) {
    case 'audio/m4a':
    case 'audio/mp4a-latm':
    case 'audio/x-m4a':
      return 'm4a';
    case 'audio/mp4':
      return 'mp4';
    case 'audio/mpeg':
      return 'mp3';
    case 'audio/wav':
    case 'audio/x-wav':
    case 'audio/wave':
    case 'audio/vnd.wave':
      return 'wav';
    default:
      return 'bin';
  }
}

enum _PillTone { primary, accent, neutral }

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.tone});

  final String label;
  final _PillTone tone;

  @override
  Widget build(BuildContext context) {
    final background = switch (tone) {
      _PillTone.primary => AppColors.primarySoft,
      _PillTone.accent => AppColors.accentSoft,
      _PillTone.neutral => AppColors.surfaceMuted,
    };
    final foreground = switch (tone) {
      _PillTone.primary => AppColors.primaryStrong,
      _PillTone.accent => AppColors.accent,
      _PillTone.neutral => AppColors.muted,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum _FeedbackTone { success, primary, accent }

class _FeedbackSection extends StatelessWidget {
  const _FeedbackSection({
    required this.title,
    required this.items,
    required this.tone,
  });

  final String title;
  final List<String> items;
  final _FeedbackTone tone;

  @override
  Widget build(BuildContext context) {
    final background = switch (tone) {
      _FeedbackTone.success => AppColors.successSoft,
      _FeedbackTone.primary => AppColors.primarySoft,
      _FeedbackTone.accent => AppColors.accentSoft,
    };
    final foreground = switch (tone) {
      _FeedbackTone.success => AppColors.success,
      _FeedbackTone.primary => AppColors.primaryStrong,
      _FeedbackTone.accent => AppColors.accent,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items) ...[
            Text('• $item'),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

String _statusCopy(String status) {
  switch (status) {
    case 'starting':
      return 'Chuan bi bat dau attempt moi.';
    case 'recording':
      return 'Tap trung vao su ro rang va tra loi dung y chinh.';
    case 'uploading':
      return 'Dang dong goi ban ghi de gui len pipeline.';
    case 'processing':
      return 'He thong dang transcript va tong hop feedback.';
    case 'completed':
      return 'Feedback da san sang. Hay doc ket qua va thu lai ngay.';
    case 'failed':
      return 'Attempt gap loi. Ban co the thu lai voi mot lan ghi moi.';
    default:
      return 'San sang cho mot lan noi moi.';
  }
}

(String, Color) _readinessTone(AttemptResult attempt) {
  if (attempt.failureCode.isNotEmpty || attempt.status == 'failed') {
    return ('Failed', AppColors.primarySoft);
  }

  switch (attempt.readinessLevel) {
    case 'ready_for_mock':
      return ('Ready for mock', AppColors.successSoft);
    case 'almost_ready':
      return ('Almost ready', AppColors.accentSoft);
    case 'needs_work':
      return ('Needs work', AppColors.primarySoft);
    case 'not_ready':
      return ('Not ready', AppColors.primarySoft);
    default:
      return (attempt.status, AppColors.surfaceMuted);
  }
}

String _formatAttemptTimestamp(String startedAt) {
  final parsed = DateTime.tryParse(startedAt)?.toLocal();
  if (parsed == null) {
    return startedAt;
  }
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
}

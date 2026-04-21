import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
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

      setState(() {
        _learnerName =
            (login['user'] as Map<String, dynamic>)['display_name']
                as String? ??
            'Learner';
        _modules = modules;
        _exercisesByModule = exerciseMap;
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
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
      ),
    );
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

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key, required this.client, required this.detail});

  final ApiClient client;
  final ExerciseDetail detail;

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  String _status = 'ready';
  String? _attemptId;
  String? _recordingPath;
  int _seconds = 0;
  Timer? _ticker;
  Timer? _poller;
  AttemptResult? _result;
  String? _error;

  @override
  void dispose() {
    _ticker?.cancel();
    _poller?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _error = null;
      _result = null;
      _seconds = 0;
      _status = 'starting';
    });
    try {
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
                  widget.detail.exerciseType,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(widget.detail.learnerInstruction),
                const SizedBox(height: 16),
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
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            _ResultCard(result: _result!),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final AttemptResult result;

  @override
  Widget build(BuildContext context) {
    final feedback = result.feedback;
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
            'Transcript',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(result.transcript ?? 'Transcript chua san sang.'),
          if (result.audio != null) ...[
            const SizedBox(height: 14),
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
                    'Uploaded audio',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Duration: ${(result.audio!.durationMs / 1000).toStringAsFixed(1)}s',
                  ),
                  Text('Size: ${result.audio!.fileSizeBytes} bytes'),
                  Text('Type: ${result.audio!.mimeType}'),
                ],
              ),
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
        ],
      ),
    );
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

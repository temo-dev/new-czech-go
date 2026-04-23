import 'dart:async';

import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/exercise/screens/exercise_screen.dart' as exercise_feature;
import 'features/home/screens/home_screen.dart';
import 'models/models.dart';

void main() {
  runApp(const MluveniSprintApp());
}

class MluveniSprintApp extends StatelessWidget {
  const MluveniSprintApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'A2 Mluveni Sprint',
      theme: AppTheme.light,
      routerConfig: appRouter,
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
      final modules = modulesPayload
          .map((item) => ModuleSummary.fromJson(item as Map<String, dynamic>))
          .toList();

      final exerciseMap = <String, List<ExerciseSummary>>{};
      for (final module in modules) {
        final payload = await _client.getExercises(module.id);
        exerciseMap[module.id] = payload
            .map((item) => ExerciseSummary.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      final attemptsPayload = await _client.getAttempts();
      final recentAttempts = attemptsPayload
          .map((item) => AttemptResult.fromJson(item as Map<String, dynamic>))
          .toList();

      setState(() {
        _learnerName =
            (login['user'] as Map<String, dynamic>)['display_name'] as String? ??
                'Learner';
        _modules = modules;
        _exercisesByModule = exerciseMap;
        _recentAttempts = recentAttempts;
      });
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadRecentAttempts() async {
    try {
      final payload = await _client.getAttempts();
      if (!mounted) return;
      setState(() {
        _recentAttempts = payload
            .map((item) => AttemptResult.fromJson(item as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {
      // Keep shell usable if refresh fails.
    }
  }

  Future<void> _openExercise(BuildContext context, ExerciseSummary exercise) async {
    final navigator = Navigator.of(context);
    final detail =
        ExerciseDetail.fromJson(await _client.getExercise(exercise.id));
    if (!mounted) return;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) =>
            exercise_feature.ExerciseScreen(client: _client, detail: detail),
      ),
    );
    await _loadRecentAttempts();
  }

  Future<void> _openAttemptExercise(
      BuildContext context, AttemptResult attempt) async {
    final navigator = Navigator.of(context);
    final detail =
        ExerciseDetail.fromJson(await _client.getExercise(attempt.exerciseId));
    if (!mounted) return;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) =>
            exercise_feature.ExerciseScreen(client: _client, detail: detail),
      ),
    );
    await _loadRecentAttempts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
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
                : HomeScreen(
                    learnerName: _learnerName,
                    modules: _modules,
                    exercisesByModule: _exercisesByModule,
                    recentAttempts: _recentAttempts,
                    onOpenExercise: (e) => _openExercise(context, e),
                    onOpenAttemptExercise: (a) =>
                        _openAttemptExercise(context, a),
                  ),
      ),
    );
  }
}

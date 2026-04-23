import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api/api_client.dart';
import 'core/locale/locale_provider.dart';
import 'core/locale/locale_scope.dart';
import 'core/theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';
import 'features/exercise/screens/exercise_screen.dart' as exercise_feature;
import 'features/history/screens/history_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'models/models.dart';
import 'shared/widgets/app_bottom_nav.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeProvider = await LocaleProvider.load();
  runApp(MluveniSprintApp(localeProvider: localeProvider));
}

class MluveniSprintApp extends StatelessWidget {
  const MluveniSprintApp({super.key, required this.localeProvider});

  final LocaleProvider localeProvider;

  @override
  Widget build(BuildContext context) {
    return LocaleScope(
      notifier: localeProvider,
      child: AnimatedBuilder(
        animation: localeProvider,
        builder: (context, _) => MaterialApp(
          title: 'A2 Mluveni Sprint',
          theme: AppTheme.light,
          home: const LearnerShell(),
          locale: Locale(localeProvider.code),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
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
  int _tabIndex = 0;

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
    final l = AppLocalizations.of(context);
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _bootstrap,
                child: Text(l.retry),
              ),
            ],
          ),
        ),
      );
    } else if (_tabIndex == 1) {
      body = HistoryScreen(
        attempts: _recentAttempts,
        exercisesByModule: _exercisesByModule,
        onOpenAttemptExercise: (a) => _openAttemptExercise(context, a),
      );
    } else {
      body = HomeScreen(
        learnerName: _learnerName,
        modules: _modules,
        exercisesByModule: _exercisesByModule,
        onOpenExercise: (e) => _openExercise(context, e),
      );
    }
    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: (_loading || _error != null)
          ? null
          : AppBottomNav(
              selectedIndex: _tabIndex,
              onSelected: (i) => setState(() => _tabIndex = i),
              items: [
                AppBottomNavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: l.bottomNavHome,
                ),
                AppBottomNavItem(
                  icon: Icons.history_outlined,
                  selectedIcon: Icons.history_rounded,
                  label: l.bottomNavHistory,
                ),
              ],
            ),
    );
  }
}

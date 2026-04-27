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
import 'features/home/screens/course_list_screen.dart';
import 'features/mock_exam/screens/mock_test_list_screen.dart';
import 'features/profile/screens/profile_screen.dart';
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
      await _client.login(
        email: 'learner@example.com',
        password: 'demo123',
      );
      final attemptsPayload = await _client.getAttempts();
      final recentAttempts = attemptsPayload
          .map((item) => AttemptResult.fromJson(item as Map<String, dynamic>))
          .toList();

      setState(() {
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

  Future<void> _openAttemptExercise(
      BuildContext context, AttemptResult attempt) async {
    final navigator = Navigator.of(context);
    final detail =
        ExerciseDetail.fromJson(await _client.getExercise(attempt.exerciseId));
    if (!mounted) return;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => exercise_feature.ExerciseScreen(
          client: _client,
          detail: detail,
        ),
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
        exercisesByModule: const {},
        onOpenAttemptExercise: (a) => _openAttemptExercise(context, a),
      );
    } else if (_tabIndex == 2) {
      body = MockTestListScreen(client: _client);
    } else if (_tabIndex == 3) {
      body = const ProfileScreen();
    } else {
      body = CourseListScreen(client: _client);
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
                AppBottomNavItem(
                  icon: Icons.assignment_outlined,
                  selectedIcon: Icons.assignment_rounded,
                  label: l.bottomNavTests,
                ),
                AppBottomNavItem(
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: l.bottomNavProfile,
                ),
              ],
            ),
    );
  }
}

import 'package:go_router/go_router.dart';

// LearnerShell is defined in main.dart until Phase 4 extraction.
// Import updated as screens move to features/.
import '../../main.dart' show LearnerShell;

import 'app_routes.dart';

final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  debugLogDiagnostics: false,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const LearnerShell(),
    ),
    // Uloha routes added in Phase 5 as screens are built.
    // GoRoute(path: AppRoutes.ulohaPrompt, ...),
    // GoRoute(path: AppRoutes.ulohaRecording, ...),
    // GoRoute(path: AppRoutes.ulohaFeedback, ...),
  ],
);

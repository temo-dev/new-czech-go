import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_czech/core/router/app_routes.dart';

/// Redirects unauthenticated users to login.
/// Applied to all /app/** routes.
String? authGuard(GoRouterState state) {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) {
    // Preserve the deep-link target so we redirect back after login
    final from = Uri.encodeComponent(state.uri.toString());
    return '${AppRoutes.login}?from=$from';
  }
  return null; // allow
}

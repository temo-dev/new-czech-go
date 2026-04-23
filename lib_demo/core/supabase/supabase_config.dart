import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_czech/core/env/app_env.dart';
import 'package:app_czech/core/storage/prefs_storage.dart';

const guestAccessHeader = 'x-guest-token';

/// Initialise Supabase once before runApp.
/// Access the client anywhere via [supabase].
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
    debug: AppEnv.isDev,
    headers: {
      guestAccessHeader: PrefsStorage.instance.guestAccessToken,
    },
  );
}

/// Convenience top-level accessor — mirrors Supabase's own pattern.
SupabaseClient get supabase => Supabase.instance.client;

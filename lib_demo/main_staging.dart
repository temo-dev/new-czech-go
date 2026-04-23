import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_czech/core/env/app_env.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';
import 'package:app_czech/core/storage/prefs_storage.dart';
import 'package:app_czech/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnv.validate();
  await PrefsStorage.init();
  await initSupabase();

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/app.dart';
import 'package:faunawatch/core/constants/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  assert(
    AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty,
    'Missing Supabase config. Run with:\n'
    '  flutter run '
    '--dart-define=SUPABASE_URL=<url> '
    '--dart-define=SUPABASE_ANON_KEY=<key>',
  );
  assert(
    AppConfig.mapboxPublicToken.isNotEmpty,
    'Missing Mapbox config. Run with:\n'
    '  flutter run --dart-define=MAPBOX_PUBLIC_TOKEN=<public-token>',
  );

  MapboxOptions.setAccessToken(AppConfig.mapboxPublicToken);

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: FaunaWatchApp()));
}

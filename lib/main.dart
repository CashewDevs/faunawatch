import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/app.dart';
import 'package:faunawatch/core/constants/app_config.dart';
import 'package:faunawatch/features/push/services/local_notification_service.dart';
import 'package:faunawatch/features/push/services/push_messaging_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // DM Sans ships in assets/google_fonts/, so it shows offline and on first
  // launch; its licence asks to be listed with the app's licences.
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });

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
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // Without Firebase config files this resolves to a no-op service and push
  // stays off; the app works as before.
  final pushService = await initializePushMessaging();

  // Creates the high-importance Android channel before any push can arrive;
  // a no-op on iOS and without Firebase.
  final localNotifications = pushService.isAvailable
      ? await initializeLocalNotifications()
      : const NoopLocalNotificationService();

  runApp(
    ProviderScope(
      overrides: [
        pushMessagingServiceProvider.overrideWithValue(pushService),
        localNotificationServiceProvider.overrideWithValue(localNotifications),
      ],
      child: const FaunaWatchApp(),
    ),
  );
}

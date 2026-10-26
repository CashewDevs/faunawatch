/// Build-time configuration values injected via --dart-define.
///
/// Usage (run / build):
///   flutter run \
///     --dart-define=SUPABASE_URL=https://your-ref.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=your-anon-key \
///     --dart-define=MAPBOX_PUBLIC_TOKEN=your-public-token
///
/// NEVER hardcode real values here. Use placeholder defaults only so the app
/// fails fast with a clear error if the defines are missing.
abstract final class AppConfig {
  /// The Supabase project URL.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// The Supabase anon (publishable) key. Safe to ship in the client bundle.
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Public Mapbox access token used by the mobile Maps SDK.
  ///
  /// This is intentionally supplied at build time rather than committed to
  /// source control. Mapbox public tokens are designed to be bundled in
  /// client applications; never use a Mapbox secret token here.
  static const mapboxPublicToken = String.fromEnvironment(
    'MAPBOX_PUBLIC_TOKEN',
    defaultValue: '',
  );
}

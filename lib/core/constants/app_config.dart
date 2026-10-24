/// Build-time configuration values injected via --dart-define.
///
/// Usage (run / build):
///   flutter run \
///     --dart-define=SUPABASE_URL=https://your-ref.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=your-anon-key
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
}

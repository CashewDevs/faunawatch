import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether [error] says [column] does not exist yet, i.e. the database is
/// older than the migration that adds it (applied by hand, so the app can
/// reach a database without it). Uses the same signals as
/// `SupabaseProfileReaderService`.
bool isMissingColumnError(Object error, String column) {
  if (error is! PostgrestException) return false;
  final code = error.code ?? '';
  final message = error.message.toLowerCase();
  final missingColumn =
      code == '42703' ||
      code == 'PGRST204' ||
      message.contains('42703') ||
      message.contains('pgrst204') ||
      message.contains('does not exist') ||
      message.contains('schema cache');
  return missingColumn && message.contains(column);
}

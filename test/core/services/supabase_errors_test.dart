import 'package:faunawatch/core/services/supabase_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('recognises a missing column only for the column asked about', () {
    const postgres = PostgrestException(
      message: 'column reports.hidden_at does not exist',
      code: '42703',
    );
    const cache = PostgrestException(
      message:
          "Could not find the 'hidden_at' column of 'reports' in the "
          'schema cache',
      code: 'PGRST204',
    );
    expect(isMissingColumnError(postgres, 'hidden_at'), isTrue);
    expect(isMissingColumnError(cache, 'hidden_at'), isTrue);
    expect(isMissingColumnError(postgres, 'bio'), isFalse);
  });

  test('other errors are not a missing column', () {
    expect(
      isMissingColumnError(
        const PostgrestException(
          message: 'hidden_at: permission denied',
          code: '42501',
        ),
        'hidden_at',
      ),
      isFalse,
    );
    expect(isMissingColumnError(Exception('hidden_at'), 'hidden_at'), isFalse);
  });
}

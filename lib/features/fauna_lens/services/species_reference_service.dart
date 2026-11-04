import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';

/// Looks up AI guesses in the curated `species_reference` table, the only
/// source allowed to raise the possible-invasive hint.
abstract interface class SpeciesReferenceService {
  /// The common name of the invasive reference entry matching [species] by
  /// scientific or common name (ignoring case), or null when none does.
  Future<String?> invasiveMatch(PossibleSpecies species);
}

class SupabaseSpeciesReferenceService implements SpeciesReferenceService {
  SupabaseSpeciesReferenceService(this._client);

  // TODO(team): The status vocabulary of species_reference is still an open
  // question in its migration. 'invasive' is assumed here; update it if the
  // team settles on a different value.
  static const invasiveStatus = 'invasive';

  final SupabaseClient _client;
  List<({String common, String scientific})>? _invasive;

  @override
  Future<String?> invasiveMatch(PossibleSpecies species) async {
    // The table is small reference data, so it is read once and matched here
    // rather than putting AI-written text into a query filter.
    final entries = _invasive ??= await _loadInvasive();
    final scientific = _normalize(species.scientificName);
    final common = _normalize(species.commonName);
    for (final entry in entries) {
      if ((scientific.isNotEmpty &&
              _normalize(entry.scientific) == scientific) ||
          (common.isNotEmpty && _normalize(entry.common) == common)) {
        return entry.common;
      }
    }
    return null;
  }

  Future<List<({String common, String scientific})>> _loadInvasive() async {
    final rows = await _client
        .from('species_reference')
        .select('common_name, scientific_name')
        .eq('status', invasiveStatus);
    return [
      for (final row in rows)
        (
          common: row['common_name'] as String,
          scientific: row['scientific_name'] as String,
        ),
    ];
  }

  static String _normalize(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

final speciesReferenceServiceProvider = Provider<SpeciesReferenceService>(
  (ref) => SupabaseSpeciesReferenceService(ref.watch(supabaseClientProvider)),
);

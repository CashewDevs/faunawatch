import 'package:faunawatch/core/theme/tag_colors.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';

/// The chip colour of each species confidence level: high green, medium
/// yellow, low blue, uncertain grey (the same colours the chip always had,
/// now with dark-mode versions).
extension ConfidenceTagTone on SpeciesConfidence {
  TagTone get tagTone => switch (this) {
    SpeciesConfidence.high => TagTone.low,
    SpeciesConfidence.medium => TagTone.moderate,
    SpeciesConfidence.low => TagTone.info,
    SpeciesConfidence.uncertain => TagTone.neutral,
  };
}

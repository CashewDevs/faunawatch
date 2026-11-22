import 'package:faunawatch/core/theme/tag_colors.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';

/// The tag colour of each severity level, from green (low) to red (critical).
/// Used by the AI result chip and the feed's severity tag so they match.
extension SeverityTagTone on SeverityLevel {
  TagTone get tagTone => switch (this) {
    SeverityLevel.low => TagTone.low,
    SeverityLevel.moderate => TagTone.moderate,
    SeverityLevel.high => TagTone.high,
    SeverityLevel.critical => TagTone.critical,
    SeverityLevel.uncertain => TagTone.neutral,
  };
}

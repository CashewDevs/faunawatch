import 'dart:math' as math;

import 'package:faunawatch/core/theme/tag_colors.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/ai_result_cards.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/confidence_tone.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/severity_tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG contrast ratio between two colours (1 to 21).
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('TagColors', () {
    for (final brightness in Brightness.values) {
      for (final tone in TagTone.values) {
        test('${tone.name} text is readable in ${brightness.name} mode', () {
          final colors = TagColors.forTone(tone, brightness);
          expect(
            contrast(colors.foreground, colors.background),
            greaterThanOrEqualTo(4.5),
          );
        });
      }

      test('every tone looks different in ${brightness.name} mode', () {
        final backgrounds = {
          for (final tone in TagTone.values)
            TagColors.forTone(tone, brightness).background,
        };
        expect(backgrounds, hasLength(TagTone.values.length));
      });
    }

    testWidgets('of() follows the app light or dark mode', (tester) async {
      late TagColors light;
      late TagColors dark;
      await tester.pumpWidget(
        Theme(
          data: ThemeData.light(),
          child: Builder(
            builder: (context) {
              light = TagColors.of(context, TagTone.critical);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        Theme(
          data: ThemeData.dark(),
          child: Builder(
            builder: (context) {
              dark = TagColors.of(context, TagTone.critical);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        light,
        same(TagColors.forTone(TagTone.critical, Brightness.light)),
      );
      expect(dark, same(TagColors.forTone(TagTone.critical, Brightness.dark)));
    });
  });

  group('SeverityTagTone', () {
    test('goes from green (low) to red (critical), grey when uncertain', () {
      expect(SeverityLevel.low.tagTone, TagTone.low);
      expect(SeverityLevel.moderate.tagTone, TagTone.moderate);
      expect(SeverityLevel.high.tagTone, TagTone.high);
      expect(SeverityLevel.critical.tagTone, TagTone.critical);
      expect(SeverityLevel.uncertain.tagTone, TagTone.neutral);
    });
  });

  group('ConfidenceTagTone', () {
    test('high green, medium yellow, low blue, uncertain grey', () {
      expect(SpeciesConfidence.high.tagTone, TagTone.low);
      expect(SpeciesConfidence.medium.tagTone, TagTone.moderate);
      expect(SpeciesConfidence.low.tagTone, TagTone.info);
      expect(SpeciesConfidence.uncertain.tagTone, TagTone.neutral);
    });
  });

  testWidgets('AI result chips use the dark colours in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: Column(
            children: [
              ConfidenceChip(confidence: SpeciesConfidence.low),
              SeverityChip(severity: SeverityLevel.critical),
            ],
          ),
        ),
      ),
    );
    Color? fill(Type chip) {
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(chip),
          matching: find.byType(Container),
        ),
      );
      return (box.decoration as BoxDecoration).color;
    }

    expect(
      fill(ConfidenceChip),
      TagColors.forTone(TagTone.info, Brightness.dark).background,
    );
    expect(
      fill(SeverityChip),
      TagColors.forTone(TagTone.critical, Brightness.dark).background,
    );
  });
}

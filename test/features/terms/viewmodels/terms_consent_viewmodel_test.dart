import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/terms/viewmodels/terms_consent_viewmodel.dart';

void main() {
  group('TermsConsentViewModel', () {
    late ProviderContainer container;
    late TermsConsentViewModel viewModel;

    setUp(() {
      container = ProviderContainer();
      viewModel = container.read(termsConsentViewModelProvider.notifier);
    });

    tearDown(() => container.dispose());

    TermsConsentState state() => container.read(termsConsentViewModelProvider);

    test('starts collapsed with nothing accepted', () {
      expect(state().expandedSection, isNull);
      expect(state().acceptedTerms, isFalse);
      expect(state().acknowledgedAiLimits, isFalse);
      expect(state().canContinue, isFalse);
    });

    test('keeps only one section open and collapses it on second tap', () {
      viewModel.toggleSection(1);
      expect(state().expandedSection, 1);

      viewModel.toggleSection(3);
      expect(state().expandedSection, 3);

      viewModel.toggleSection(3);
      expect(state().expandedSection, isNull);
    });

    test('requires both boxes before accepting', () {
      viewModel.setAcceptedTerms(true);
      expect(state().canContinue, isFalse);
      expect(viewModel.accept(), isFalse);

      viewModel.setAcknowledgedAiLimits(true);
      expect(state().canContinue, isTrue);
      expect(viewModel.accept(), isTrue);

      viewModel.setAcceptedTerms(false);
      expect(viewModel.accept(), isFalse);
    });

    test('ticking boxes keeps the open section', () {
      viewModel.toggleSection(2);
      viewModel.setAcceptedTerms(true);
      expect(state().expandedSection, 2);
    });
  });
}

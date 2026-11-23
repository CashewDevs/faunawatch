import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/terms/models/terms_consent_state.dart';

export 'package:faunawatch/features/terms/models/terms_consent_state.dart';

/// ViewModel for the stepped terms consent flow: active step, expanded section,
/// and ticked consent checkboxes.
class TermsConsentViewModel extends Notifier<TermsConsentState> {
  @override
  TermsConsentState build() => const TermsConsentState();

  /// Sets the active step index within `0..consentPageIndex`.
  void setPage(int page) {
    final clamped = page.clamp(0, TermsConsentState.consentPageIndex);
    if (clamped == state.currentPage) return;
    state = state.copyWith(currentPage: clamped);
  }

  /// Advances one step forward until the final agreement step.
  void nextPage() => setPage(state.currentPage + 1);

  /// Moves one step back until the first rule screen.
  void previousPage() => setPage(state.currentPage - 1);

  /// Jumps directly to the final "Almost there" agreement screen.
  void skipToConsent() => setPage(TermsConsentState.consentPageIndex);

  /// Opens [index], or closes it when it is already open. Only one section
  /// is open at a time.
  void toggleSection(int index) {
    state = state.expandedSection == index
        ? state.copyWith(clearExpandedSection: true)
        : state.copyWith(expandedSection: index);
  }

  void setAcceptedTerms(bool value) {
    state = state.copyWith(acceptedTerms: value);
  }

  void setAcknowledgedAiLimits(bool value) {
    state = state.copyWith(acknowledgedAiLimits: value);
  }

  /// Confirms consent. Returns `false` while any box is still unticked.
  // TODO(legal): Persist the accepted terms version and timestamp once the
  // team decides where consent is recorded (e.g. a Supabase column). Until
  // then acceptance only gates navigation for this session.
  bool accept() => state.canContinue;
}

/// Riverpod provider exposing [TermsConsentViewModel] and [TermsConsentState].
final termsConsentViewModelProvider =
    NotifierProvider<TermsConsentViewModel, TermsConsentState>(
      TermsConsentViewModel.new,
    );

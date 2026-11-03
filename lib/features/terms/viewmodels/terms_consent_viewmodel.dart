import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/terms/models/terms_consent_state.dart';

export 'package:faunawatch/features/terms/models/terms_consent_state.dart';

/// ViewModel for the terms consent screen: which summary is open and which
/// boxes are ticked.
class TermsConsentViewModel extends Notifier<TermsConsentState> {
  @override
  TermsConsentState build() => const TermsConsentState();

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

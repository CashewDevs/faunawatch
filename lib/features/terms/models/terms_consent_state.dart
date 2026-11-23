import 'package:faunawatch/features/terms/models/terms_section.dart';

/// Immutable state for the stepped terms consent walkthrough.
class TermsConsentState {
  const TermsConsentState({
    this.currentPage = 0,
    this.expandedSection,
    this.acceptedTerms = false,
    this.acknowledgedAiLimits = false,
  });

  /// Total steps: the 4 rule screens followed by the final agreement screen.
  static int get totalPages => termsSections.length + 1;

  /// Index of the final "Almost there" agreement screen.
  static int get consentPageIndex => termsSections.length;

  /// Current step index (`0..3` for the 4 rules, `4` for "Almost there").
  final int currentPage;

  /// Whether the user is currently on the final agreement screen.
  bool get isConsentPage => currentPage == consentPageIndex;

  /// Index of the open summary section, or `null` when all are collapsed.
  final int? expandedSection;

  /// Whether the Terms of Service and Privacy Policy box is ticked.
  final bool acceptedTerms;

  /// Whether the "AI results are preliminary" box is ticked.
  final bool acknowledgedAiLimits;

  /// The user may continue only after ticking every box.
  bool get canContinue => acceptedTerms && acknowledgedAiLimits;

  TermsConsentState copyWith({
    int? currentPage,
    int? expandedSection,
    bool clearExpandedSection = false,
    bool? acceptedTerms,
    bool? acknowledgedAiLimits,
  }) {
    return TermsConsentState(
      currentPage: currentPage ?? this.currentPage,
      expandedSection: clearExpandedSection
          ? null
          : expandedSection ?? this.expandedSection,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      acknowledgedAiLimits: acknowledgedAiLimits ?? this.acknowledgedAiLimits,
    );
  }
}

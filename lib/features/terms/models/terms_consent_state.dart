/// Immutable state for the terms consent screen.
class TermsConsentState {
  const TermsConsentState({
    this.expandedSection,
    this.acceptedTerms = false,
    this.acknowledgedAiLimits = false,
  });

  /// Index of the open summary section, or `null` when all are collapsed.
  final int? expandedSection;

  /// Whether the Terms of Service and Privacy Policy box is ticked.
  final bool acceptedTerms;

  /// Whether the "AI results are preliminary" box is ticked.
  final bool acknowledgedAiLimits;

  /// The user may continue only after ticking every box.
  bool get canContinue => acceptedTerms && acknowledgedAiLimits;

  TermsConsentState copyWith({
    int? expandedSection,
    bool clearExpandedSection = false,
    bool? acceptedTerms,
    bool? acknowledgedAiLimits,
  }) {
    return TermsConsentState(
      expandedSection: clearExpandedSection
          ? null
          : expandedSection ?? this.expandedSection,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      acknowledgedAiLimits: acknowledgedAiLimits ?? this.acknowledgedAiLimits,
    );
  }
}

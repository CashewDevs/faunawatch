enum AiProvider { gemini, groq, openRouter }

extension AiProviderDetails on AiProvider {
  String get displayName => switch (this) {
    AiProvider.gemini => 'Gemini',
    AiProvider.groq => 'Groq',
    AiProvider.openRouter => 'OpenRouter',
  };

  /// Two-letter monogram shown on the provider's badge.
  String get monogram => switch (this) {
    AiProvider.gemini => 'Ge',
    AiProvider.groq => 'Gq',
    AiProvider.openRouter => 'OR',
  };

  /// Short one-line description shown under the provider name.
  String get tagline => switch (this) {
    AiProvider.gemini => 'Google AI · strong with photos',
    AiProvider.groq => 'Very fast responses',
    AiProvider.openRouter => 'One key, hundreds of models',
  };

  /// Placeholder hinting at the provider's key format.
  String get keyHint => switch (this) {
    AiProvider.gemini => 'AIza...',
    AiProvider.groq => 'gsk_...',
    AiProvider.openRouter => 'sk-or-...',
  };

  /// Page where users create an API key for this provider.
  Uri get keyConsoleUri => switch (this) {
    AiProvider.gemini => Uri.https('aistudio.google.com', '/app/apikey'),
    AiProvider.groq => Uri.https('console.groq.com', '/keys'),
    AiProvider.openRouter => Uri.https('openrouter.ai', '/settings/keys'),
  };

  /// The provider's own terms, which users agree to follow.
  Uri get termsUri => switch (this) {
    AiProvider.gemini => Uri.https('ai.google.dev', '/gemini-api/terms'),
    AiProvider.groq => Uri.https('groq.com', '/terms-of-use'),
    AiProvider.openRouter => Uri.https('openrouter.ai', '/terms'),
  };

  String get _providerKeySuffix => switch (this) {
    AiProvider.gemini => 'gemini',
    AiProvider.groq => 'groq',
    AiProvider.openRouter => 'openrouter',
  };

  /// Builds a storage key scoped to [userId].
  ///
  /// Format: `faunawatch.ai_key.<userId>.<provider>`
  String storageKey(String userId) =>
      'faunawatch.ai_key.$userId.$_providerKeySuffix';
}

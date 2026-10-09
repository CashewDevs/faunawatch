enum AiProvider {
  gemini,
  groq,
  openRouter,
}

extension AiProviderDetails on AiProvider {
  String get displayName => switch (this) {
        AiProvider.gemini => 'Gemini',
        AiProvider.groq => 'Groq',
        AiProvider.openRouter => 'OpenRouter',
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

  /// Alias for [storageKey].
  String storageKeyForUser(String userId) => storageKey(userId);

  /// Key prefix shared by all providers for a given [userId].
  static String storageKeyPrefix(String userId) =>
      'faunawatch.ai_key.$userId.';
}
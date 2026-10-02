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

  String get storageKey => switch (this) {
        AiProvider.gemini => 'faunawatch.ai_key.gemini',
        AiProvider.groq => 'faunawatch.ai_key.groq',
        AiProvider.openRouter => 'faunawatch.ai_key.openrouter',
      };
}
/// One numbered, expandable summary point on the terms consent screen.
class TermsSection {
  const TermsSection({
    required this.title,
    required this.summary,
    required this.details,
  });

  final String title;
  final String summary;
  final String details;
}

/// Version of the terms the user agrees to on the consent screen.
const String termsVersion = '1.0';

// TODO(legal): Replace with the real publication date once the Terms of
// Service and Privacy Policy are finalized. The design leaves it as [DATE].
const String termsLastUpdated = '[DATE]';

/// The short-form terms shown before the user starts exploring.
const List<TermsSection> termsSections = [
  TermsSection(
    title: 'Be a good neighbour',
    summary: 'Post real sightings and be kind.',
    details:
        'Only share photos you took yourself. No harassment, spam or '
        'misleading reports. We may remove posts that break these rules.',
  ),
  TermsSection(
    title: 'AI is a helper, not an expert',
    summary: 'Species guesses are preliminary.',
    details:
        'FaunaLens results are a preliminary AI assessment, not a veterinary '
        'or wildlife authority finding. For injured or dangerous animals, '
        'contact your local wildlife office.',
  ),
  TermsSection(
    title: 'Your photos & location',
    summary: 'Posts are public; locations are approximate.',
    details:
        'Photos you post can be seen by other users. We only show an '
        'approximate area like a city, never your exact spot.',
  ),
  TermsSection(
    title: 'Stay safe out there',
    summary: 'Never approach or handle wild animals.',
    details:
        'Keep a safe distance, respect protected areas and never disturb '
        'nests or young animals for a photo.',
  ),
];

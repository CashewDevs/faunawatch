/// Model representing an application accent theme palette for "Change Theme".
class AppThemePalette {
  const AppThemePalette({
    required this.id,
    required this.name,
    required this.primaryColorValue,
    required this.accentColorValue,
    required this.description,
  });

  final String id;
  final String name;
  final int primaryColorValue;
  final int accentColorValue;
  final String description;

  static const List<AppThemePalette> presets = [
    AppThemePalette(
      id: 'forest',
      name: 'Forest Emerald',
      primaryColorValue: 0xFF1B5E20,
      accentColorValue: 0xFF81C784,
      description: 'Lush natural greenery inspired by wild forests',
    ),
    AppThemePalette(
      id: 'ocean',
      name: 'Ocean Breeze',
      primaryColorValue: 0xFF1A5DC9,
      accentColorValue: 0xFF60A5FA,
      description: 'Cool aquatic tones representing coastal fauna',
    ),
    AppThemePalette(
      id: 'sunset',
      name: 'Sunset Amber',
      primaryColorValue: 0xFFD97706,
      accentColorValue: 0xFFFCD34D,
      description: 'Warm golden savanna at twilight',
    ),
    AppThemePalette(
      id: 'arctic',
      name: 'Arctic Cyan',
      primaryColorValue: 0xFF0891B2,
      accentColorValue: 0xFF67E8F9,
      description: 'Crisp polar glaciers and tundra skies',
    ),
    AppThemePalette(
      id: 'meadow',
      name: 'Lavender Meadow',
      primaryColorValue: 0xFF7C3AED,
      accentColorValue: 0xFFC4B5FD,
      description: 'Vibrant highland blooms and flora',
    ),
  ];
}

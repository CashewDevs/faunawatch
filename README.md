# faunawatch
A Flutter-based mobile application for FaunaWatch, an AI-assisted platform for wildlife reporting, species identification, and environmental monitoring.

## Configuration

The community map uses Mapbox. Provide its public access token at build time;
do not commit it to source control:

```bash
flutter run --dart-define=MAPBOX_PUBLIC_TOKEN=<your-public-token>
```

The existing VS Code launch configuration reads the same value from the
ignored `dart_defines.json` file.

## Map demo

The map starts in Cebu City with a synthetic incident pin, colored warning
zones, and a blue simulated-position marker. Dismiss the preview card with X
to select Approaching, Near, or Danger Zone. The info button reopens the
preview; the demo controls can also be collapsed and reopened.

The 900 m / 500 m / 180 m radii are demo presets only, not approved proximity
thresholds. This demo does not read GPS, query reports, send notifications,
or write sample data to Supabase. Replace it when live reporting is connected.

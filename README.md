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

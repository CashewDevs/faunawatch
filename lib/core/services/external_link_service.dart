import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens web links outside the app (in the browser or a matching app).
abstract interface class ExternalLinkService {
  /// Returns `false` when no app could open [uri].
  Future<bool> open(Uri uri);
}

final class UrlLauncherExternalLinkService implements ExternalLinkService {
  const UrlLauncherExternalLinkService();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

/// Riverpod provider exposing the [ExternalLinkService].
final externalLinkServiceProvider = Provider<ExternalLinkService>(
  (ref) => const UrlLauncherExternalLinkService(),
);

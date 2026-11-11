import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/auth/services/google_auth_service.dart';

class _MemoryPkceStorage extends GotrueAsyncStorage {
  final values = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => values[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late SupabaseGoogleAuthService service;
  String? displayName;
  bool failProfile = false;
  int profileRequests = 0;

  setUp(() {
    displayName = null;
    failProfile = false;
    profileRequests = 0;
    client = SupabaseClient(
      'https://example.test',
      'test-publishable-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: _MemoryPkceStorage(),
      ),
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            jsonEncode({
              'access_token': 'test-access-token',
              'refresh_token': 'test-refresh-token',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'user-123',
                'aud': 'authenticated',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-01-01T00:00:00Z',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        expect(request.url.path, '/rest/v1/profiles');
        expect(request.url.queryParameters['id'], 'eq.user-123');
        expect(request.url.queryParameters['select'], 'display_name');
        profileRequests++;
        return http.Response(
          jsonEncode(
            failProfile
                ? {'message': 'offline'}
                : {'display_name': displayName},
          ),
          failProfile ? 400 : 200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    service = SupabaseGoogleAuthService(client);
  });
  tearDown(() => client.dispose());

  Future<void> authenticate() async {
    await client.auth.signInWithPassword(
      email: 'user@example.test',
      password: 'test-password',
    );
  }

  test('signed-out restoration does not query profiles', () async {
    expect(await service.loadSessionProfile(), isNull);
    expect(profileRequests, 0);
  });

  test(
    'launches Google OAuth with the app redirect and account chooser',
    () async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      String? launchedUrl;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'launch') {
              launchedUrl = (call.arguments as Map)['url'] as String;
            }
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      expect(await service.launchSignIn(), isTrue);
      final uri = Uri.parse(launchedUrl!);
      expect(uri.path, '/auth/v1/authorize');
      expect(uri.queryParameters['provider'], 'google');
      expect(
        uri.queryParameters['redirect_to'],
        SupabaseGoogleAuthService.redirectUrl,
      );
      expect(uri.queryParameters['prompt'], 'select_account');
      expect(uri.queryParameters['code_challenge'], isNotEmpty);
      expect(uri.queryParameters['code_challenge_method'], 's256');
    },
  );

  test('sign-in event is emitted only after authentication', () async {
    final event = service.signedIn.first;
    await authenticate();
    await event;
  });

  for (final name in <String?>[null, '', '   ', 'Ranger']) {
    test('profile name $name determines setup destination', () async {
      await authenticate();
      displayName = name;
      final profile = await service.loadSessionProfile();
      expect(profile!.userId, 'user-123');
      expect(profile.displayName, name);
      expect(profile.hasDisplayName, name != null && name.trim().isNotEmpty);
    });
  }

  test(
    'profile errors propagate for a retry instead of skipping setup',
    () async {
      await authenticate();
      failProfile = true;
      await expectLater(
        service.loadSessionProfile(),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
}

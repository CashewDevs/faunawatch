import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';

void main() {
  group('SecureAiApiKeyStorageService', () {
    late _MemorySecureKeyValueStore storage;
    late SecureAiApiKeyStorageService service;
    const userId = 'user-abc-123';

    setUp(() {
      storage = _MemorySecureKeyValueStore();
      service = SecureAiApiKeyStorageService(storage: storage);
    });

    test(
      'stores each provider key independently and trims whitespace',
      () async {
        await service.saveKey(userId, AiProvider.gemini, '  gemini-secret  ');
        await service.saveKey(userId, AiProvider.groq, 'groq-secret');

        expect(
          await service.readKey(userId, AiProvider.gemini),
          'gemini-secret',
        );
        expect(await service.readKey(userId, AiProvider.groq), 'groq-secret');
        expect(await service.readKey(userId, AiProvider.openRouter), isNull);
      },
    );

    test(
      'uses storage key format faunawatch.ai_key.<userId>.<provider>',
      () async {
        await service.saveKey(userId, AiProvider.gemini, 'gemini-secret');

        expect(
          storage.values['faunawatch.ai_key.$userId.gemini'],
          'gemini-secret',
        );
      },
    );

    test('rejects an empty key', () async {
      // saveKey throws synchronously, so pass a closure for the matcher to call.
      await expectLater(
        () => service.saveKey(userId, AiProvider.gemini, '  '),
        throwsArgumentError,
      );
      expect(storage.values, isEmpty);
    });

    test('deletes only the selected provider key', () async {
      await service.saveKey(userId, AiProvider.gemini, 'gemini-secret');
      await service.saveKey(userId, AiProvider.groq, 'groq-secret');

      await service.deleteKey(userId, AiProvider.gemini);

      expect(await service.readKey(userId, AiProvider.gemini), isNull);
      expect(await service.readKey(userId, AiProvider.groq), 'groq-secret');
    });

    group('user isolation', () {
      const userA = 'user-aaa';
      const userB = 'user-bbb';

      test('keys for different users are stored independently', () async {
        await service.saveKey(userA, AiProvider.gemini, 'secret-a');
        await service.saveKey(userB, AiProvider.gemini, 'secret-b');

        expect(await service.readKey(userA, AiProvider.gemini), 'secret-a');
        expect(await service.readKey(userB, AiProvider.gemini), 'secret-b');
      });

      test('deleting a key for one user does not affect another', () async {
        await service.saveKey(userA, AiProvider.groq, 'groq-a');
        await service.saveKey(userB, AiProvider.groq, 'groq-b');

        await service.deleteKey(userA, AiProvider.groq);

        expect(await service.readKey(userA, AiProvider.groq), isNull);
        expect(await service.readKey(userB, AiProvider.groq), 'groq-b');
      });
    });

    group('deleteAllKeys', () {
      const userA = 'user-aaa';
      const userB = 'user-bbb';

      test('removes all keys for the specified user only', () async {
        await service.saveKey(userA, AiProvider.gemini, 'gem-a');
        await service.saveKey(userA, AiProvider.groq, 'groq-a');
        await service.saveKey(userA, AiProvider.openRouter, 'or-a');
        await service.saveKey(userB, AiProvider.gemini, 'gem-b');

        await service.deleteAllKeys(userA);

        for (final provider in AiProvider.values) {
          expect(await service.readKey(userA, provider), isNull);
        }
        expect(await service.readKey(userB, AiProvider.gemini), 'gem-b');
      });

      test('is safe to call when no keys exist', () async {
        await service.deleteAllKeys('nonexistent-user');
      });

      test('also removes that user\'s backup key', () async {
        final backup = SecureAiBackupKeyStorageService(storage: storage);
        await backup.save(userA, AiProvider.groq, 'backup-a');
        await backup.save(userB, AiProvider.groq, 'backup-b');

        await service.deleteAllKeys(userA);

        expect(await backup.readProvider(userA), isNull);
        expect(await backup.readKey(userA), isNull);
        expect(await backup.readKey(userB), 'backup-b');
      });
    });
  });

  group('SecureAiBackupKeyStorageService', () {
    late _MemorySecureKeyValueStore storage;
    late SecureAiBackupKeyStorageService backup;
    late SecureAiApiKeyStorageService main;
    const userId = 'user-abc-123';

    setUp(() {
      storage = _MemorySecureKeyValueStore();
      backup = SecureAiBackupKeyStorageService(storage: storage);
      main = SecureAiApiKeyStorageService(storage: storage);
    });

    test('has no backup until one is saved', () async {
      expect(await backup.readProvider(userId), isNull);
      expect(await backup.readKey(userId), isNull);
    });

    test('saves a trimmed key with its provider under its own name', () async {
      await backup.save(userId, AiProvider.openRouter, '  or-backup  ');

      expect(await backup.readProvider(userId), AiProvider.openRouter);
      expect(await backup.readKey(userId), 'or-backup');
      expect(storage.values['faunawatch.ai_key.$userId.backup'], 'or-backup');
      expect(
        storage.values['faunawatch.ai_key.$userId.backup_provider'],
        'openRouter',
      );
    });

    test('can be a second key for the same provider as a main key', () async {
      await main.saveKey(userId, AiProvider.gemini, 'main-gemini');
      await backup.save(userId, AiProvider.gemini, 'backup-gemini');

      expect(await main.readKey(userId, AiProvider.gemini), 'main-gemini');
      expect(await backup.readKey(userId), 'backup-gemini');
    });

    test(
      'a new backup replaces the old one, even for another provider',
      () async {
        await backup.save(userId, AiProvider.groq, 'groq-backup');
        await backup.save(userId, AiProvider.gemini, 'gemini-backup');

        expect(await backup.readProvider(userId), AiProvider.gemini);
        expect(await backup.readKey(userId), 'gemini-backup');
      },
    );

    test('rejects an empty key and keeps the old backup', () async {
      await backup.save(userId, AiProvider.groq, 'groq-backup');
      await expectLater(
        () => backup.save(userId, AiProvider.gemini, '   '),
        throwsArgumentError,
      );
      expect(await backup.readProvider(userId), AiProvider.groq);
    });

    test('delete removes the key and its provider', () async {
      await backup.save(userId, AiProvider.groq, 'groq-backup');
      await backup.delete(userId);

      expect(await backup.readProvider(userId), isNull);
      expect(storage.values, isEmpty);
    });

    test('a provider without a key counts as no backup', () async {
      storage.values['faunawatch.ai_key.$userId.backup_provider'] = 'groq';
      expect(await backup.readProvider(userId), isNull);
    });

    test('removing a main key leaves the backup alone', () async {
      await main.saveKey(userId, AiProvider.groq, 'main-groq');
      await backup.save(userId, AiProvider.groq, 'backup-groq');

      await main.deleteKey(userId, AiProvider.groq);

      expect(await backup.readKey(userId), 'backup-groq');
    });
  });
}

class _MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

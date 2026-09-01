import 'package:flutter_test/flutter_test.dart';
import 'package:tavolink/core/storage/secure_store.dart';
import 'package:tavolink/features/mcp/mcp_credentials.dart';

class _MemorySecureStore extends SecureStore {
  final values = <String, String>{};

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  final first = Uri.parse('https://one.example/mcp');
  final second = Uri.parse('https://two.example/mcp');

  test(
    'keeps blank input for same endpoint; does not leak to another',
    () async {
      final store = _MemorySecureStore();
      final credentials = McpCredentials(store: store);
      await credentials.saveToken(first, 'Bearer fixture-one');
      await credentials.saveToken(first, '');
      await credentials.saveToken(second, null);
      expect(await credentials.tokenFor(first), 'fixture-one');
      expect(await credentials.tokenFor(second), isNull);
      expect(await McpCredentials(store: store).tokenFor(first), 'fixture-one');
      await credentials.saveToken(first, 'fixture-two');
      expect(await credentials.tokenFor(first), 'fixture-two');
    },
  );

  test('isolates endpoint paths and clears only the selected token', () async {
    final credentials = McpCredentials(store: _MemorySecureStore());
    final otherPath = first.replace(path: '/another/mcp');
    await credentials.saveToken(first, 'fixture-one');
    await credentials.saveToken(otherPath, 'fixture-two');
    await credentials.deleteToken(first);
    expect(await credentials.tokenFor(first), isNull);
    expect(await credentials.tokenFor(otherPath), 'fixture-two');
  });

  test('migrates legacy token to the saved endpoint once', () async {
    final store = _MemorySecureStore();
    await store.write('mcp.token', 'Bearer legacy-fixture');
    final credentials = McpCredentials(store: store);
    await credentials.migrateLegacyToken(first);
    await credentials.migrateLegacyToken(second);
    expect(await credentials.tokenFor(first), 'legacy-fixture');
    expect(await credentials.tokenFor(second), isNull);
    expect(await store.read('mcp.token'), isNull);
  });

  test('does not overwrite existing scoped token during migration', () async {
    final store = _MemorySecureStore();
    final credentials = McpCredentials(store: store);
    await credentials.saveToken(first, 'new-fixture');
    await store.write('mcp.token', 'old-fixture');
    await credentials.migrateLegacyToken(first);
    expect(await credentials.tokenFor(first), 'new-fixture');
    expect(await store.read('mcp.token'), isNull);
  });

  test('headers use endpoint-scoped secure storage', () async {
    final credentials = McpCredentials(store: _MemorySecureStore());
    await credentials.saveHeaders(first, {'X-Api-Key': 'header-fixture'});
    expect(await credentials.headersFor(first), {
      'X-Api-Key': 'header-fixture',
    });
    expect(await credentials.headersFor(second), isNull);
  });

  test(
    'discards malformed secure headers without blocking config recovery',
    () async {
      final store = _MemorySecureStore();
      final credentials = McpCredentials(store: store);
      await credentials.saveHeaders(first, {'X-Good': 'fixture'});
      final headerKey = store.values.keys.singleWhere(
        (key) => key.contains('.headers.'),
      );
      store.values[headerKey] = '{broken';
      expect(await credentials.headersFor(first), isNull);
      expect(store.values.containsKey(headerKey), isFalse);
    },
  );

  test('normalizes Bearer prefix and rejects header injection', () {
    expect(McpCredentials.normalizeToken('  bearer fixture  '), 'fixture');
    expect(
      () => McpCredentials.normalizeToken('fixture\r\nX-Other: injected'),
      throwsFormatException,
    );
    expect(
      () =>
          McpCredentials.normalizeToken(List.filled(16 * 1024 + 1, 'x').join()),
      throwsFormatException,
    );
    expect(
      () => McpCredentials.normalizeHeaders({
        'X-Good': 'ok',
        'X-Bad': 'value\r\ninjected: yes',
      }),
      throwsFormatException,
    );
    expect(
      () => McpCredentials.normalizeHeaders({'Content-Length': '0'}),
      throwsFormatException,
    );
  });
}

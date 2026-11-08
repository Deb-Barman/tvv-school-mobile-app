import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tvv_mobile/core/api_client.dart';
import 'package:tvv_mobile/core/api_exception.dart';
import 'package:tvv_mobile/core/response_cache.dart';
import 'package:tvv_mobile/core/token_store.dart';

void main() {
  test('the last good answer is shown when the server cannot be reached, and is wiped on sign-out', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({'ok': true, 'n': 7}));
      await req.response.close();
    });
    final cache = MemoryResponseCache();
    final events = <bool>[];
    final api = ApiClient(
      baseUrl: 'http://127.0.0.1:${server.port}/api',
      tokens: MemoryTokenStore(),
      cache: cache,
      retryDelays: const [Duration(milliseconds: 5), Duration(milliseconds: 5)],
    )..onOfflineData = events.add;
    await api.setSession(access: 'a', refresh: 'r');

    final live = await api.getMap('/thing/');
    expect(live['n'], 7);
    await Future<void>.delayed(const Duration(milliseconds: 50)); // the copy is saved in the background
    expect(cache.length, 1);

    await server.close(force: true); // now the phone has "no signal"
    final saved = await api.getMap('/thing/');
    expect(saved['n'], 7);
    expect(events, [true]);

    await api.clearSession(); // signing out removes every saved copy
    expect(cache.length, 0);
    api.close();
  });

  test('a read that was never saved still fails clearly when offline', () async {
    final api = ApiClient(
      baseUrl: 'http://127.0.0.1:1/api',
      tokens: MemoryTokenStore(),
      cache: MemoryResponseCache(),
      retryDelays: const [],
    );
    await api.setSession(access: 'a', refresh: 'r');
    // Wait for the failed request to finish BEFORE closing the client (closing it mid-request is what broke this test before).
    await expectLater(api.getMap('/never-seen/'), throwsA(isA<ApiException>()));
    api.close();
  });
}

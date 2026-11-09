import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A newer build of the app that is waiting to be downloaded.
class UpdateInfo {
  const UpdateInfo({required this.build, required this.version, required this.downloadUrl, this.notes = ''});
  final int build;
  final String version;
  final String downloadUrl;
  final String notes;
}

/// Asks GitHub which build is on the "mobile-latest" release of [repo] (e.g. "owner/name") and tells the app when a
/// newer one exists. Works for public repositories; for a private one GitHub answers 404 and nothing is shown.
/// Every problem is swallowed on purpose: checking for updates must never disturb the app.
class UpdateChecker {
  UpdateChecker(this.repo, {this.tag = 'mobile-latest', HttpClient? client}) : _client = client ?? HttpClient();

  final String repo;
  final String tag;
  final HttpClient _client;

  Future<UpdateInfo?> latest() async {
    if (repo.isEmpty) return null;
    try {
      final req = await _client.getUrl(Uri.parse('https://api.github.com/repos/$repo/releases/tags/$tag')).timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      req.headers.set(HttpHeaders.userAgentHeader, 'TVV-Mobile');
      final res = await req.close().timeout(const Duration(seconds: 8));
      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      return parseRelease(jsonDecode(body));
    } catch (_) {
      return null;
    }
  }

  /// Reads the release JSON: the body carries `<!-- tvv-build:57 tvv-version:1.3.0 -->` and the APK is the first asset.
  static UpdateInfo? parseRelease(Object? json) {
    if (json is! Map) return null;
    final body = (json['body'] ?? '').toString();
    final build = RegExp(r'tvv-build:(\d+)').firstMatch(body)?.group(1);
    if (build == null) return null;
    final version = RegExp(r'tvv-version:([0-9A-Za-z.\-]+)').firstMatch(body)?.group(1) ?? '';
    String url = (json['html_url'] ?? '').toString();
    final assets = json['assets'];
    if (assets is List && assets.isNotEmpty && assets.first is Map) {
      final d = (assets.first as Map)['browser_download_url'];
      if (d is String && d.isNotEmpty) url = d;
    }
    if (url.isEmpty) return null;
    return UpdateInfo(build: int.parse(build), version: version, downloadUrl: url);
  }

  void close() => _client.close(force: true);
}

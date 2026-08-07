import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class LogoCacheService {
  LogoCacheService._();
  static final LogoCacheService instance = LogoCacheService._();

  static const String _logoFolder = 'printer_logos';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call this from Dashboard initState. Fetches and caches the logo silently.
  Future<void> preFetchLogo(String clientAlias) async {
    final url = _buildUrl(clientAlias);
    final cacheFile = await _getCacheFile(clientAlias);

    if (await cacheFile.exists()) {
      debugPrint('LogoCacheService: logo already cached for "$clientAlias"');
      return;
    }

    try {
      final bytes = await _fetchFromNetwork(url);
      if (bytes != null) {
        await cacheFile.create(recursive: true);
        await cacheFile.writeAsBytes(bytes);
        debugPrint('LogoCacheService: logo cached → ${cacheFile.path}');
      }
    } catch (e) {
      debugPrint('LogoCacheService: pre-fetch failed — $e');
    }
  }

  /// Returns cached bytes if available, otherwise tries network.
  /// Returns null if both fail (device is offline and no cache exists).
  Future<Uint8List?> getLogoBytes(String clientAlias) async {
    final cacheFile = await _getCacheFile(clientAlias);

    // 1. Serve from cache ────────────────────────────────────────────────────
    if (await cacheFile.exists()) {
      debugPrint('LogoCacheService: serving logo from cache');
      return await cacheFile.readAsBytes();
    }

    // 2. Try network (first-time online fallback) ────────────────────────────
    debugPrint('LogoCacheService: cache miss — fetching from network');
    try {
      final bytes = await _fetchFromNetwork(_buildUrl(clientAlias));
      if (bytes != null) {
        await cacheFile.create(recursive: true);
        await cacheFile.writeAsBytes(bytes);
      }
      return bytes;
    } catch (e) {
      debugPrint('LogoCacheService: network fetch also failed — $e');
      return null; // Offline and no cache; caller handles gracefully
    }
  }

  /// Clears cached logo for a specific client (e.g. after logout).
  Future<void> clearCache(String clientAlias) async {
    final cacheFile = await _getCacheFile(clientAlias);
    if (await cacheFile.exists()) {
      await cacheFile.delete();
      debugPrint('LogoCacheService: cache cleared for "$clientAlias"');
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  String _buildUrl(String clientAlias) =>
      'https://internal.infobraintechs.com/api/collector/logo?client_alias=$clientAlias';

  Future<File> _getCacheFile(String clientAlias) async {
    final cacheDir = await getApplicationCacheDirectory();
    // Sanitise alias so it's a safe filename
    final safeName = clientAlias.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return File('${cacheDir.path}/$_logoFolder/$safeName.png');
  }

  Future<Uint8List?> _fetchFromNetwork(String url) async {
    final dio = Dio();
    final response = await dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      ),
    );
    if (response.statusCode == 200 && response.data != null) {
      return Uint8List.fromList(response.data!);
    }
    return null;
  }
}
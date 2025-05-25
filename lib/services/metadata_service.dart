import 'package:metadata_fetch/metadata_fetch.dart';
import '../models/link_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MetadataService {
  static final Map<String, LinkModel> _cache = {};
  static const String _cacheKey = 'link_preview_cache';

  static Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = prefs.getString(_cacheKey);
    if (cacheData != null) {
      final Map<String, dynamic> decoded = jsonDecode(cacheData);
      _cache.addAll(decoded.map((key, value) => MapEntry(key, LinkModel.fromMap(Map<String, dynamic>.from(value)))));
    }
  }

  static Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = _cache.map((key, value) => MapEntry(key, value.toMap()));
    await prefs.setString(_cacheKey, jsonEncode(cacheData));
  }

  static Future<LinkModel?> extractMetadata(String url) async {
    await _loadCache(); // Load cache on first call
    if (_cache.containsKey(url)) {
      return _cache[url];
    }

    try {
      final uri = Uri.parse(url);
      final metadata = await MetadataFetch.extract(url);

      String domain = uri.host;
      String title = metadata?.title ?? 'Untitled';
      String description = metadata?.description ?? '';
      String imageUrl = metadata?.image ?? '';

      if (title.isEmpty) title = 'Untitled';
      if (description.isEmpty) description = 'No description available';

      final linkModel = LinkModel(
        url: url,
        title: title,
        description: description,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        domain: domain,
      );

      _cache[url] = linkModel;
      await _saveCache(); // Save to cache
      return linkModel;
    } catch (e) {
      print('Error extracting metadata: $e');
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final linkModel = LinkModel(
          url: url,
          title: uri.host,
          description: 'Unable to load preview',
          imageUrl: '',
          createdAt: DateTime.now(),
          domain: uri.host,
        );
        _cache[url] = linkModel;
        await _saveCache();
        return linkModel;
      }
      return null;
    }
  }

  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}
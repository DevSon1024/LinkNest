import 'package:metadata_fetch/metadata_fetch.dart';
import '../models/link_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
    await _loadCache();
    if (_cache.containsKey(url)) {
      return _cache[url];
    }

    try {
      final uri = Uri.parse(url);
      String domain = uri.host.replaceFirst('www.', '');
      String title = 'Untitled';
      String description = 'No description available';
      String imageUrl = '';

      // Attempt to fetch metadata using metadata_fetch
      final metadata = await MetadataFetch.extract(url);
      if (metadata != null) {
        title = metadata.title?.trim() ?? 'Untitled';
        description = metadata.description?.trim() ?? 'No description available';
        imageUrl = metadata.image?.trim() ?? '';
      }

      // Fallback: Fetch page and extract title if metadata is incomplete
      if (title == 'Untitled' || title.isEmpty) {
        try {
          final response = await http.get(uri);
          if (response.statusCode == 200) {
            final html = response.body;
            final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false).firstMatch(html);
            if (titleMatch != null && titleMatch.group(1)!.isNotEmpty) {
              title = titleMatch.group(1)!.trim();
            }
          }
        } catch (e) {
          print('Fallback title extraction failed: $e');
        }
      }

      // Ensure title is not empty
      if (title.isEmpty) title = domain;

      final linkModel = LinkModel(
        url: url,
        title: title,
        description: description,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        domain: domain,
        tags: [],
        notes: null,
      );

      _cache[url] = linkModel;
      await _saveCache();
      return linkModel;
    } catch (e) {
      print('Error extracting metadata: $e');
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final linkModel = LinkModel(
          url: url,
          title: uri.host.replaceFirst('www.', ''),
          description: 'Unable to load preview',
          imageUrl: '',
          createdAt: DateTime.now(),
          domain: uri.host.replaceFirst('www.', ''),
          tags: [],
          notes: null,
        );
        _cache[url] = linkModel;
        await _saveCache();
        return linkModel;
      }
      return null;
    }
  }

  static Future<void> clearCache() async {
    _cache.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
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
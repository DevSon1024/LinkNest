import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/link_model.dart';

class MetadataService {
  static final Map<String, LinkModel> _cache = {};
  static const String _cacheKey = 'link_preview_cache';
  static HeadlessInAppWebView? _headlessWebView;

  static Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = prefs.getString(_cacheKey);
    if (cacheData != null) {
      final Map<String, dynamic> decoded = jsonDecode(cacheData);
      _cache.addAll(decoded.map((key, value) =>
          MapEntry(key, LinkModel.fromMap(Map<String, dynamic>.from(value)))));
    }
  }

  static Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = _cache.map((key, value) => MapEntry(key, value.toMap()));
    await prefs.setString(_cacheKey, jsonEncode(cacheData));
  }

  /// Extracts metadata using a headless webview for reliability with JS-heavy sites.
  static Future<LinkModel?> _extractMetadataWithWebView(String url) async {
    final completer = Completer<LinkModel?>();

    _headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        // Mimic a common mobile browser to avoid being blocked
        userAgent:
        "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36",
        // Crucial for running JS to get the final rendered HTML
        javaScriptEnabled: true,
        // Tries to block ads and trackers that cause connection errors
        contentBlockers: [
          ContentBlocker(
              trigger: ContentBlockerTrigger(urlFilter: ".*googleads.*"),
              action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK)),
          ContentBlocker(
              trigger: ContentBlockerTrigger(urlFilter: ".*doubleclick.*"),
              action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK)),
          ContentBlocker(
              trigger: ContentBlockerTrigger(urlFilter: ".*ad-delivery.*"),
              action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK)),
        ],
      ),
      onLoadStop: (controller, uri) async {
        // Prevent the future from completing more than once
        if (completer.isCompleted) return;

        try {
          // Add a delay to ensure all dynamic content has loaded
          await Future.delayed(const Duration(milliseconds: 1500));

          final title = await controller.getTitle();

          // Advanced script to find the best possible image URL
          final String? imageUrl = await controller.evaluateJavascript(source: '''
            (function() {
              // Priority 1: Open Graph image
              let image = document.querySelector("meta[property='og:image']")?.getAttribute('content');
              if (image) return image;

              // Priority 2: Twitter card image
              image = document.querySelector("meta[name='twitter:image']")?.getAttribute('content');
              if (image) return image;

              // Priority 3: Find the largest image in the main content area
              let images = Array.from(document.querySelectorAll('img'));
              let largestImage = null;
              let maxArea = 0;
              for (const img of images) {
                if (img.naturalWidth > 300 && img.naturalHeight > 300) { // Filter for reasonably sized images
                  let area = img.naturalWidth * img.naturalHeight;
                  if (area > maxArea) {
                    maxArea = area;
                    largestImage = img.src;
                  }
                }
              }
              return largestImage;
            })();
          ''');

          final String? description = await controller.evaluateJavascript(source: '''
            document.querySelector("meta[name='description']")?.getAttribute('content') ||
            document.querySelector("meta[property='og:description']")?.getAttribute('content');
          ''');

          final domain = uri?.host.replaceFirst('www.', '') ?? Uri.parse(url).host.replaceFirst('www.', '');

          final linkModel = LinkModel(
            url: url,
            title: title?.trim().isNotEmpty == true ? title!.trim() : domain,
            description: description?.trim(),
            imageUrl: imageUrl?.trim(),
            createdAt: DateTime.now(),
            domain: domain,
            tags: [],
            notes: null,
            status: MetadataStatus.completed,
          );
          completer.complete(linkModel);
        } catch (e) {
          if (!completer.isCompleted) completer.complete(null);
        } finally {
          _headlessWebView?.dispose();
          _headlessWebView = null;
        }
      },
      onLoadError: (controller, url, code, message) {
        if (!completer.isCompleted) completer.complete(null);
        _headlessWebView?.dispose();
        _headlessWebView = null;
      },
    );

    // Run the webview and set a timeout
    try {
      await _headlessWebView?.run();
      return await completer.future.timeout(const Duration(seconds: 20));
    } catch (e) {
      if (!completer.isCompleted) completer.complete(null);
      _headlessWebView?.dispose();
      _headlessWebView = null;
      return null;
    }
  }

  static Future<LinkModel?> extractMetadata(String url) async {
    await _loadCache();
    if (_cache.containsKey(url)) {
      return _cache[url];
    }

    try {
      LinkModel? linkModel = await _extractMetadataWithWebView(url);

      if (linkModel == null) {
        final uri = Uri.parse(url);
        linkModel = LinkModel(
          url: url,
          title: uri.host.replaceFirst('www.', ''),
          description: 'Unable to load preview',
          imageUrl: '',
          createdAt: DateTime.now(),
          domain: uri.host.replaceFirst('www.', ''),
          tags: [],
          notes: null,
          status: MetadataStatus.failed,
        );
      }

      _cache[url] = linkModel;
      await _saveCache();
      return linkModel;

    } catch (e) {
      print('Fatal error extracting metadata: $e');
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

  static List<String> extractUrlsFromText(String text) {
    final urlRegex = RegExp(
        r'(?:(?:https|http):\/\/|www\.)(?:[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b)(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)');
    return urlRegex.allMatches(text).map((match) => match.group(0)!).toList();
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
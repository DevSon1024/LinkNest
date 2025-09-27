import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/link_model.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

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
        if (completer.isCompleted) return;

        try {
          await Future.delayed(const Duration(milliseconds: 1200)); // Reduced delay

          final title = await controller.getTitle();
          final String? imageUrl = await controller.evaluateJavascript(source: '''
          // ... (your existing JS for image extraction)
        ''');

          String? compressedImagePath;
          if (imageUrl != null && imageUrl.isNotEmpty) {
            compressedImagePath = await _compressImage(imageUrl);
          }

          final String? description = await controller.evaluateJavascript(source: '''
          // ... (your existing JS for description extraction)
        ''');

          final domain = uri?.host.replaceFirst('www.', '') ?? Uri.parse(url).host.replaceFirst('www.', '');

          final linkModel = LinkModel(
            url: url,
            title: title?.trim().isNotEmpty == true ? title!.trim() : domain,
            description: description?.trim(),
            imageUrl: compressedImagePath, // Use the compressed image path
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
      // First, try with metadata_fetch for a quick result
      final metadata = await MetadataFetch.extract(url);
      if (metadata != null && metadata.title != null) {
        final linkModel = LinkModel(
          url: url,
          title: metadata.title,
          description: metadata.description,
          imageUrl: metadata.image,
          createdAt: DateTime.now(),
          domain: Uri.parse(url).host.replaceFirst('www.', ''),
          status: MetadataStatus.completed,
        );
        _cache[url] = linkModel;
        await _saveCache();
        return linkModel;
      }
    } catch (e) {
      // Fallback to WebView if metadata_fetch fails
    }

    // Fallback to the more reliable WebView method
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
        status: MetadataStatus.failed,
      );
    }
    _cache[url] = linkModel;
    await _saveCache();
    return linkModel;
  }

  static Future<String?> _compressImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final originalFile = await _saveTemporaryFile(response.bodyBytes, 'original');
        final targetPath = (await getTemporaryDirectory()).path + '/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';

        final result = await FlutterImageCompress.compressAndGetFile(
          originalFile.absolute.path,
          targetPath,
          quality: 60, // Adjust quality as needed
        );

        await originalFile.delete(); // Clean up original file

        return result?.path;
      }
    } catch (e) {
      print('Image compression failed: $e');
      return null;
    }
    return null;
  }

  static Future<File> _saveTemporaryFile(Uint8List bytes, String name) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$name.jpg');
    await file.writeAsBytes(bytes);
    return file;
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
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';

class ShareService {
  static const platform = MethodChannel('com.devson.link_saver/share');
  static StreamController<String> _sharedLinkController = StreamController<String>.broadcast();
  static Stream<String> get sharedLinkStream => _sharedLinkController.stream;
  static final Set<String> _processedLinks = {}; // Cache for deduplication
  static const int _debounceDuration = 2000; // 2 seconds debounce window

  static void initialize() {
    // Listen for sharing intent when app is already running
    ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      for (var file in value) {
        if (file.type == SharedMediaType.text && file.path.isNotEmpty) {
          _processSharedLink(file.path);
        }
      }
    });

    // Get sharing intent when app is launched from sharing
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      for (var file in value) {
        if (file.type == SharedMediaType.text && file.path.isNotEmpty) {
          _processSharedLink(file.path);
        }
      }
    });

    // Also check for data from MainActivity
    _checkMainActivityData();
  }

  static void _processSharedLink(String link) {
    // Deduplicate based on link content and time
    if (_processedLinks.contains(link)) {
      return; // Skip if already processed
    }
    _processedLinks.add(link);
    _sharedLinkController.add(link);

    // Clear processed link after debounce duration
    Future.delayed(Duration(milliseconds: _debounceDuration), () {
      _processedLinks.remove(link);
    });
  }

  static Future<void> _checkMainActivityData() async {
    try {
      final String? sharedData = await platform.invokeMethod('getSharedData');
      if (sharedData != null && sharedData.isNotEmpty) {
        _processSharedLink(sharedData);
      }
    } catch (e) {
      print('Error getting shared data from MainActivity: $e');
    }
  }

  static String? extractUrlFromText(String text) {
    final urlPatterns = [
      RegExp(r'https?://[^\s]+'),
      RegExp(r'www\.[^\s]+'),
    ];

    for (final pattern in urlPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        String url = match.group(0)!;
        if (!url.startsWith('http')) {
          url = 'https://$url';
        }
        return url;
      }
    }

    if (text.contains('.') && !text.contains(' ')) {
      return text.startsWith('http') ? text : 'https://$text';
    }

    return null;
  }

  static void dispose() {
    _sharedLinkController.close();
    _processedLinks.clear();
  }
}
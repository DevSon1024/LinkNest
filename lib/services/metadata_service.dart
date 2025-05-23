import 'package:metadata_fetch/metadata_fetch.dart';
import '../models/link_model.dart';

class MetadataService {
  static Future<LinkModel?> extractMetadata(String url) async {
    try {
      final uri = Uri.parse(url);
      final metadata = await MetadataFetch.extract(url);

      String domain = uri.host;
      String title = metadata?.title ?? 'Untitled';
      String description = metadata?.description ?? '';
      String imageUrl = metadata?.image ?? '';

      // Clean up the data
      if (title.isEmpty) title = 'Untitled';
      if (description.isEmpty) description = 'No description available';

      return LinkModel(
        url: url,
        title: title,
        description: description,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        domain: domain,
      );
    } catch (e) {
      print('Error extracting metadata: $e');

      // Return basic link info if metadata extraction fails
      final uri = Uri.tryParse(url);
      if (uri != null) {
        return LinkModel(
          url: url,
          title: uri.host,
          description: 'Unable to load preview',
          imageUrl: '',
          createdAt: DateTime.now(),
          domain: uri.host,
        );
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
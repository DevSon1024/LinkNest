import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/metadata_service.dart';
import 'package:flutter/services.dart';

class InputPage extends StatefulWidget {
  final VoidCallback? onLinkAdded;

  const InputPage({super.key, this.onLinkAdded});

  @override
  InputPageState createState() => InputPageState();
}

class InputPageState extends State<InputPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _urlController = TextEditingController();
  List<String> _recentUrls = [];

  @override
  void initState() {
    super.initState();
    _loadRecentUrls();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentUrls() async {
    try {
      final links = await _dbHelper.getAllLinks();
      setState(() {
        _recentUrls = links.map((link) => link.url).take(10).toList();
      });
    } catch (e) {
      _showSnackBar('Error loading recent URLs: $e');
    }
  }

  Future<void> _addLink() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar('Please enter a URL');
      return;
    }

    if (await _dbHelper.linkExists(url)) {
      _showSnackBar('Link already exists');
      return;
    }

    try {
      final linkModel = await MetadataService.extractMetadata(url);
      if (linkModel != null) {
        await _dbHelper.insertLink(linkModel);
        widget.onLinkAdded?.call();
        _urlController.clear();
        await _loadRecentUrls();
        _showSnackBar('Link saved successfully');
      } else {
        _showSnackBar('Failed to extract link information');
      }
    } catch (e) {
      _showSnackBar('Error saving link: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _copyUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    _showSnackBar('URL copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'Add New Link',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'Enter URL (e.g., https://example.com)',
                border: OutlineInputBorder(),
                labelText: 'URL',
              ),
              keyboardType: TextInputType.url,
              onSubmitted: (_) => _addLink(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addLink,
              child: const Text('Add Link'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Recent URLs',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _recentUrls.isEmpty
                  ? const Center(child: Text('No recent URLs added yet'))
                  : ListView.builder(
                itemCount: _recentUrls.length,
                itemBuilder: (context, index) {
                  final url = _recentUrls[index];
                  return ListTile(
                    title: Text(
                      url,
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _copyUrl(url),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () => _copyUrl(url),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
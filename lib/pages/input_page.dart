import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/metadata_service.dart';
import 'package:flutter/services.dart';
import '../models/link_model.dart';

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
  bool _isLoading = false;

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
    setState(() => _isLoading = true);
    try {
      final links = await _dbHelper.getAllLinks();
      setState(() {
        _recentUrls = links.map((link) => link.url).take(10).toList();
      });
    } catch (e) {
      _showSnackBar('Error loading recent URLs: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addLink() async {
    final text = _urlController.text.trim();
    if (text.isEmpty) {
      _showSnackBar('Please enter a URL or text containing URLs');
      return;
    }

    final urls = MetadataService.extractUrlsFromText(text);

    if (urls.isEmpty) {
      _showSnackBar('No valid URLs found in the text');
      return;
    }

    setState(() => _isLoading = true);
    int savedCount = 0;
    for (final url in urls) {
      if (await _dbHelper.linkExists(url)) {
        // Optionally, show a message that the link already exists
        continue;
      }
      final domain = Uri.tryParse(url)?.host ?? '';
      final newLink = LinkModel(
        url: url,
        createdAt: DateTime.now(),
        domain: domain,
        status: MetadataStatus.pending,
      );
      await _dbHelper.insertLink(newLink);
      savedCount++;
    }

    setState(() => _isLoading = false);

    if (savedCount > 0) {
      widget.onLinkAdded?.call();
      _urlController.clear();
      await _loadRecentUrls();
      _showSnackBar('$savedCount link(s) saved successfully');
    } else {
      _showSnackBar('No new links were saved');
    }
  }

  Future<void> _pasteUrl() async {
    final clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData != null && clipboardData.text != null) {
      _urlController.text = clipboardData.text!.trim();
      setState(() {});
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _copyUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    _showSnackBar('URL copied to clipboard');
  }

  Widget _buildRecentUrlCard(String url) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _copyUrl(url),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                child: Icon(
                  Icons.link_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  url,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.copy_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: () => _copyUrl(url),
                tooltip: 'Copy URL',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add New Link',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
        elevation: 2,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: 'Enter URL (e.g., https://example.com)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelText: 'URL',
                    prefixIcon: const Icon(Icons.link_rounded),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.paste),
                          onPressed: _pasteUrl,
                          tooltip: 'Paste URL',
                        ),
                        if (_urlController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _urlController.clear();
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                  ),
                  keyboardType: TextInputType.url,
                  onSubmitted: (_) => _addLink(),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addLink,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    )
                        : const Text(
                      'Add Link',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Recent URLs',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _recentUrls.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.link_off_rounded,
                    size: 80,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recent URLs',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Add your first link to see recent URLs here',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadRecentUrls,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80, top: 0),
                itemCount: _recentUrls.length,
                itemBuilder: (context, index) {
                  return _buildRecentUrlCard(_recentUrls[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
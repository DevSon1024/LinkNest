import 'package:flutter/cupertino.dart';
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: const Icon(CupertinoIcons.link, size: 22),
        title: Text(
          url,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 20),
          onPressed: () => _copyUrl(url),
          tooltip: 'Copy URL',
        ),
        onTap: () => _copyUrl(url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Link'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: 'Enter or paste a URL',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                    labelText: 'URL',
                    prefixIcon: const Icon(CupertinoIcons.link),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(CupertinoIcons.doc_on_clipboard),
                          onPressed: _pasteUrl,
                          tooltip: 'Paste URL',
                        ),
                        if (_urlController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(CupertinoIcons.xmark_circle_fill),
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
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _addLink,
                    icon: _isLoading
                        ? Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2.0),
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.onPrimary,
                        strokeWidth: 3,
                      ),
                    )
                        : const Icon(CupertinoIcons.add),
                    label: const Text('Add Link'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Recently Added',
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
                    CupertinoIcons.link_circle,
                    size: 80,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recent URLs',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Your recently added links will appear here.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
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
                padding: const EdgeInsets.only(bottom: 80),
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
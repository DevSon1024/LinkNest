import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/link_model.dart';
import '../services/database_helper.dart';

class LinkDetailsPage extends StatefulWidget {
  final LinkModel link;

  const LinkDetailsPage({super.key, required this.link});

  @override
  _LinkDetailsPageState createState() => _LinkDetailsPageState();
}

class _LinkDetailsPageState extends State<LinkDetailsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late TextEditingController _notesController;
  late TextEditingController _tagController;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.link.notes);
    _tagController = TextEditingController();
    _tags = List.from(widget.link.tags);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final newTag = _tagController.text.trim();
    if (newTag.isNotEmpty && !_tags.contains(newTag)) {
      setState(() {
        _tags.add(newTag);
      });
    }
    _tagController.clear();
  }

  Future<void> _openLink(String url, {bool useDefaultBrowser = false}) async {
    try {
      final uri = Uri.parse(url);
      if (useDefaultBrowser) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.link.title ?? 'Link Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.link.imageUrl != null &&
                widget.link.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: CachedNetworkImage(
                  imageUrl: widget.link.imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      color: Colors.white,
                    ),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              widget.link.title ?? 'No Title',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              widget.link.description ?? 'No description available.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Domain: ${widget.link.domain}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            // Tags section
            Text('Tags', style: Theme.of(context).textTheme.titleLarge),
            Wrap(
              spacing: 8.0,
              children: _tags
                  .map((tag) => Chip(
                label: Text(tag),
                onDeleted: () {
                  setState(() {
                    _tags.remove(tag);
                  });
                },
              ))
                  .toList(),
            ),
            TextField(
              controller: _tagController,
              decoration: InputDecoration(
                labelText: 'Add a tag',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addTag,
                ),
              ),
              onSubmitted: (_) => _addTag(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final updatedLink = widget.link.copyWith(
                  notes: _notesController.text,
                  tags: _tags,
                );
                await _dbHelper.updateLink(updatedLink);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notes and tags saved!')),
                  );
                }
              },
              child: const Text('Save Notes and Tags'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _openLink(widget.link.url),
                child: const Text('Open Link Here'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () =>
                    _openLink(widget.link.url, useDefaultBrowser: true),
                child: const Text('Open in App'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
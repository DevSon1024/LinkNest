import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/link_model.dart';
import '../../core/services/database_helper.dart';
import '../widgets/enhanced_snackbar.dart';
import 'full_screen_image_page.dart';

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
  final FocusNode _tagFocusNode = FocusNode();
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.link.notes ?? '');
    _tagController = TextEditingController();
    _tags = List<String>.from(widget.link.tags);

    // Listen for changes
    _notesController.addListener(() {
      if (!_hasChanges) {
        setState(() => _hasChanges = true);
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _tagController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  void _addTag() {
    final newTag = _tagController.text.trim();
    if (newTag.isNotEmpty && !_tags.contains(newTag)) {
      setState(() {
        _tags.add(newTag);
        _hasChanges = true;
      });
      _tagController.clear();
      _showEnhancedSnackBar('Tag added: $newTag', type: SnackBarType.success);
    } else if (_tags.contains(newTag)) {
      _showEnhancedSnackBar('Tag already exists', type: SnackBarType.warning);
      _tagController.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _hasChanges = true;
    });
    _showEnhancedSnackBar('Tag removed: $tag', type: SnackBarType.info);
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
        _showEnhancedSnackBar('Error opening link: $e', type: SnackBarType.error);
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_hasChanges) {
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Save Changes?'),
          content: const Text('You have unsaved changes. Do you want to save them before leaving?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (shouldSave == true) {
        await _saveChanges();
      }
    }
    return true;
  }

  Future<void> _saveChanges() async {
    try {
      final updatedLink = widget.link.copyWith(
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        tags: _tags,
      );

      final result = await _dbHelper.updateLink(updatedLink);

      if (result > 0) {
        setState(() => _hasChanges = false);
        _showEnhancedSnackBar('Changes saved successfully!', type: SnackBarType.success);
      } else {
        _showEnhancedSnackBar('Failed to save changes', type: SnackBarType.error);
      }
    } catch (e) {
      _showEnhancedSnackBar('Error saving: $e', type: SnackBarType.error);
    }
  }

  void _showEnhancedSnackBar(String message, {SnackBarType type = SnackBarType.info}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      EnhancedSnackBar.create(
        context: context,
        message: message,
        type: type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 250.0,
              pinned: true,
              stretch: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              actions: [
                if (_hasChanges)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      onPressed: _saveChanges,
                      icon: const Icon(CupertinoIcons.checkmark_alt),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green.withOpacity(0.2),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: (widget.link.imageUrl != null && widget.link.imageUrl!.isNotEmpty)
                    ? GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullScreenImagePage(
                          imageUrl: widget.link.imageUrl!,
                        ),
                      ),
                    );
                  },
                  child: CachedNetworkImage(
                    imageUrl: widget.link.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: Icon(
                        CupertinoIcons.link,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 100,
                      ),
                    ),
                  ),
                )
                    : Container(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: Icon(
                    CupertinoIcons.link,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 100,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Link Information Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.link.title ?? 'No Title',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (widget.link.description != null && widget.link.description!.isNotEmpty) ...[
                                Text(
                                  widget.link.description!,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Row(
                                children: [
                                  Icon(CupertinoIcons.globe,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Domain: ${widget.link.domain}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Notes Section
                      Text(
                        'Notes',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: TextField(
                            controller: _notesController,
                            decoration: InputDecoration(
                              hintText: 'Add your notes here...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            maxLines: 5,
                            textInputAction: TextInputAction.newline,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Tags Section
                      Row(
                        children: [
                          Text(
                            'Tags',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_tags.length}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Tag Input
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: TextField(
                            controller: _tagController,
                            focusNode: _tagFocusNode,
                            decoration: InputDecoration(
                              hintText: 'Add a tag...',
                              suffixIcon: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.add, color: Colors.white),
                                  onPressed: _addTag,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            onSubmitted: (_) => _addTag(),
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Tags Display
                      if (_tags.isNotEmpty)
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: _tags.map((tag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tag,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => _removeTag(tag),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Save Button
                      if (_hasChanges)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saveChanges,
                            icon: const Icon(CupertinoIcons.checkmark_alt),
                            label: const Text('Save Changes'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),

                      // Bottom padding for navigation
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ]),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openLink(widget.link.url),
                  icon: const Icon(CupertinoIcons.link),
                  label: const Text('Open Here'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _openLink(widget.link.url, useDefaultBrowser: true),
                  icon: const Icon(CupertinoIcons.globe),
                  label: const Text('Open in App'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/link_model.dart';
import '../services/database_helper.dart';

class FolderLinksPage extends StatefulWidget {
  final String folderName;
  final List<LinkModel> links;

  const FolderLinksPage({
    super.key,
    required this.folderName,
    required this.links,
  });

  @override
  FolderLinksPageState createState() => FolderLinksPageState();
}

class FolderLinksPageState extends State<FolderLinksPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isGridView = false;

  Future<void> _deleteLink(LinkModel link, String folderName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Link'),
        content: const Text('Are you sure you want to delete this link?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirm == true && link.id != null) {
      final deletedLink = link;
      await _dbHelper.deleteLink(link.id!);
      setState(() {
        widget.links.removeWhere((l) => l.id == link.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Link deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await _dbHelper.insertLink(deletedLink);
              setState(() {
                widget.links.add(deletedLink);
                widget.links.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              });
            },
          ),
        ),
      );
    }
  }

  Future<void> _openLink(String url) async {
    try {
      String formattedUrl = url.trim();
      if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
        formattedUrl = 'https://$formattedUrl';
      }
      final uri = Uri.tryParse(formattedUrl);
      if (uri == null || !uri.hasScheme) {
        _showSnackBar('Invalid URL: $formattedUrl');
        return;
      }
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        _showSnackBar('No browser installed to open: $formattedUrl');
      }
    } catch (e) {
      _showSnackBar('Error opening URL: $e');
    }
  }

  void _copyUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    _showSnackBar('URL copied to clipboard');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _shareLink(String url, String title) async {
    try {
      await Share.share(
        '$title\n$url',
        subject: title.isNotEmpty ? title : 'Shared Link',
      );
    } catch (e) {
      _showSnackBar('Error sharing link: $e');
    }
  }

  Future<void> _showEditNotesDialog(BuildContext context, LinkModel link, String folderName) async {
    final TextEditingController notesController = TextEditingController(text: link.notes ?? '');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add/Edit Notes'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (link.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: link.imageUrl,
                    fit: BoxFit.cover,
                    height: 150,
                    width: double.infinity,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        height: 150,
                        color: Colors.grey[300],
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 150,
                      color: Colors.grey[200],
                      child: const Icon(Icons.link, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                link.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  if (link.description.isNotEmpty) link.description,
                  'Domain: ${link.domain}',
                  if (link.tags.isNotEmpty) 'Tags: ${link.tags.join(', ')}',
                ].join('\n'),
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                  hintText: 'Add your notes here...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedLink = link.copyWith(notes: notesController.text.isEmpty ? null : notesController.text);
              await _dbHelper.updateLink(updatedLink);
              setState(() {
                final index = widget.links.indexWhere((l) => l.id == link.id);
                if (index != -1) {
                  widget.links[index] = updatedLink;
                }
              });
              Navigator.pop(context);
              _showSnackBar('Notes saved');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLinkOptionsMenu(BuildContext context, LinkModel link, String folderName) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Open Link'),
                onTap: () {
                  Navigator.pop(context);
                  _openLink(link.url);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy URL'),
                onTap: () {
                  Navigator.pop(context);
                  _copyUrl(link.url);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  _shareLink(link.url, link.title);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Add Description', style: TextStyle(color: Colors.blue)),
                onTap: () {
                  Navigator.pop(context);
                  _showEditNotesDialog(context, link, folderName);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteLink(link, folderName);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLinkItem(LinkModel link, String folderName) {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openLink(link.url),
        onLongPress: () => _showLinkOptionsMenu(context, link, folderName),
        child: _isGridView ? _buildGridItem(link) : _buildListItem(link),
      ),
    );
  }

  Widget _buildGridItem(LinkModel link) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Container(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxWidth * 0.75,
                        maxHeight: constraints.maxWidth * 0.95,
                      ),
                      color: Colors.grey[200],
                      child: link.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                        imageUrl: link.imageUrl,
                        fit: BoxFit.cover,
                        width: constraints.maxWidth,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            color: Colors.grey[300],
                          ),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.link, size: 40, color: Colors.grey),
                        ),
                      )
                          : const Center(
                        child: Icon(Icons.link, size: 40, color: Colors.grey),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteLink(link, widget.folderName);
                          } else if (value == 'copy') {
                            _copyUrl(link.url);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'copy',
                            child: Row(
                              children: [
                                Icon(Icons.copy, size: 18),
                                SizedBox(width: 8),
                                Text('Copy URL'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        link.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      link.domain,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (link.notes != null && link.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        link.notes!,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListItem(LinkModel link) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 80,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: link.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: link.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    color: Colors.grey[300],
                  ),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.link, color: Colors.grey),
                ),
              )
                  : const Center(
                child: Icon(Icons.link, color: Colors.grey),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  link.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (link.description.isNotEmpty)
                  Text(
                    link.description,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Text(
                  link.domain,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                if (link.notes != null && link.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    link.notes!,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _deleteLink(link, widget.folderName),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            onPressed: () => setState(() => _isGridView = !_isGridView),
            tooltip: _isGridView ? 'List view' : 'Grid view',
          ),
        ],
      ),
      body: widget.links.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No links in this folder',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      )
          : _isGridView
          ? GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: widget.links.length,
        itemBuilder: (context, index) {
          return _buildLinkItem(widget.links[index], widget.folderName);
        },
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: widget.links.length,
        itemBuilder: (context, index) {
          return _buildLinkItem(widget.links[index], widget.folderName);
        },
      ),
    );
  }
}
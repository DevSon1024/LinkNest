import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/link_model.dart';
import '../services/database_helper.dart';
import '../services/metadata_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LinksPage extends StatefulWidget {
  final VoidCallback? onRefresh;

  const LinksPage({super.key, this.onRefresh});

  @override
  LinksPageState createState() => LinksPageState();
}

class LinksPageState extends State<LinksPage> with TickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<LinkModel> _links = [];
  final List<LinkModel> _selectedLinks = [];
  bool _isGridView = false;
  bool _isLoading = false;
  bool _isSelectionMode = false;
  bool _isRefreshing = false;
  late AnimationController _fabAnimationController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadViewPreference();
    loadLinks();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGridView = prefs.getBool('links_page_view') ?? false;
    });
  }

  Future<void> _saveViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('links_page_view', _isGridView);
  }

  Future<void> loadLinks({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;
    setState(() => _isLoading = true);
    try {
      final links = await _dbHelper.getAllLinks();
      print('Loaded links: ${links.map((link) => link.url).toList()}');
      setState(() => _links = links);
      if (forceRefresh) {
        widget.onRefresh?.call();
      }
    } catch (e) {
      _showSnackBar('Error loading links: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAllLinksMetadata() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      _showSnackBar('Refreshing links metadata...');

      List<LinkModel> updatedLinks = [];

      for (int i = 0; i < _links.length; i++) {
        final link = _links[i];

        try {
          final updatedMetadata = await MetadataService.extractMetadata(link.url);

          if (updatedMetadata != null) {
            final updatedLink = link.copyWith(
              title: updatedMetadata.title.isNotEmpty ? updatedMetadata.title : link.title,
              description: updatedMetadata.description.isNotEmpty ? updatedMetadata.description : link.description,
              imageUrl: updatedMetadata.imageUrl.isNotEmpty ? updatedMetadata.imageUrl : link.imageUrl,
              domain: updatedMetadata.domain.isNotEmpty ? updatedMetadata.domain : link.domain,
            );

            await _dbHelper.updateLink(updatedLink);
            updatedLinks.add(updatedLink);
          } else {
            updatedLinks.add(link);
          }
        } catch (e) {
          print('Error refreshing metadata for ${link.url}: $e');
          updatedLinks.add(link);
        }

        await Future.delayed(const Duration(milliseconds: 500));
      }

      setState(() => _links = updatedLinks);
      _showSnackBar('Links metadata refreshed successfully!');
      widget.onRefresh?.call();
    } catch (e) {
      _showSnackBar('Error refreshing links: $e');
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  String _getFaviconUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return 'https://www.google.com/s2/favicons?domain=${uri.host}&sz=64';
    } catch (e) {
      return 'https://www.google.com/s2/favicons?domain=example.com&sz=64';
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedLinks.clear();
      }
    });
    if (_isSelectionMode) {
      _fabAnimationController.forward();
    } else {
      _fabAnimationController.reverse();
    }
  }

  void _deselectAllLinks() {
    setState(() {
      _selectedLinks.clear();
      _isSelectionMode = false;
    });
    _fabAnimationController.reverse();
  }

  Future<void> _shareSelectedLinks() async {
    if (_selectedLinks.isEmpty) return;

    final linksText = _selectedLinks
        .map((link) => '${link.title}\n${link.url}')
        .join('\n\n');

    try {
      await Share.share(
        linksText,
        subject: 'Shared ${_selectedLinks.length} Links',
      );
    } catch (e) {
      _showSnackBar('Error sharing links: $e');
    }
  }

  void _toggleLinkSelection(LinkModel link) {
    setState(() {
      if (_selectedLinks.contains(link)) {
        _selectedLinks.remove(link);
      } else {
        _selectedLinks.add(link);
      }
      if (_selectedLinks.isEmpty && _isSelectionMode) {
        _toggleSelectionMode();
      }
    });
  }

  Future<void> _deleteSelectedLinks() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Links'),
        content: Text('Are you sure you want to delete ${_selectedLinks.length} link(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final link in _selectedLinks) {
        if (link.id != null) {
          await _dbHelper.deleteLink(link.id!);
        }
      }
      _selectedLinks.clear();
      _toggleSelectionMode();
      await loadLinks(forceRefresh: true);
      _showSnackBar('Links deleted successfully');
    }
  }

  Future<void> _deleteLink(LinkModel link) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Link'),
        content: const Text('Are you sure you want to delete this link?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && link.id != null) {
      final deletedLink = link;
      await _dbHelper.deleteLink(link.id!);
      await loadLinks(forceRefresh: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Link deleted'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.blue,
            onPressed: () async {
              await _dbHelper.insertLink(deletedLink);
              await loadLinks(forceRefresh: true);
            },
          ),
        ),
      );
    }
  }

  Future<void> _openLink(String url, {bool useDefaultBrowser = false}) async {
    try {
      print('Attempting to open URL: $url');
      String formattedUrl = url.trim();
      if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
        formattedUrl = 'https://$formattedUrl';
      }

      final uri = Uri.tryParse(formattedUrl);
      if (uri == null || !uri.hasScheme) {
        _showSnackBar('Invalid URL: $formattedUrl');
        return;
      }

      if (useDefaultBrowser) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showSnackBar('Cannot open link in default browser');
        }
      } else {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        } else {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            _showSnackBar('Cannot open link');
          }
        }
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
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
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

  Future<void> _showEditNotesDialog(BuildContext context, LinkModel link) async {
    final TextEditingController notesController = TextEditingController(text: link.notes ?? '');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      highlightColor: Theme.of(context).colorScheme.surfaceContainer,
                      child: Container(
                        height: 150,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 150,
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: Icon(Icons.link, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                link.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  if (link.description.isNotEmpty) link.description,
                  'Domain: ${link.domain}',
                  if (link.tags.isNotEmpty) 'Tags: ${link.tags.join(', ')}',
                ].join('\n'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
              await loadLinks(forceRefresh: true);
              Navigator.pop(context);
              _showSnackBar('Notes saved');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLinkOptionsMenu(BuildContext context, LinkModel link) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.open_in_new, color: Theme.of(context).colorScheme.onSurface),
                title: const Text('Open Link (In-App)'),
                onTap: () {
                  Navigator.pop(context);
                  _openLink(link.url, useDefaultBrowser: false);
                },
              ),
              ListTile(
                leading: Icon(Icons.open_in_browser, color: Theme.of(context).colorScheme.onSurface),
                title: const Text('Open in Default Browser'),
                onTap: () {
                  Navigator.pop(context);
                  _openLink(link.url, useDefaultBrowser: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Add/Edit Description', style: TextStyle(color: Colors.blue)),
                onTap: () {
                  Navigator.pop(context);
                  _showEditNotesDialog(context, link);
                },
              ),
              ListTile(
                leading: Icon(Icons.copy, color: Theme.of(context).colorScheme.onSurface),
                title: const Text('Copy URL'),
                onTap: () {
                  Navigator.pop(context);
                  _copyUrl(link.url);
                },
              ),
              ListTile(
                leading: Icon(Icons.share, color: Theme.of(context).colorScheme.onSurface),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  _shareLink(link.url, link.title);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteLink(link);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkImage(LinkModel link, {double? width, double? height, BoxFit? fit}) {
    final faviconUrl = _getFaviconUrl(link.url);

    if (link.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: link.imageUrl,
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          highlightColor: Theme.of(context).colorScheme.surfaceContainer,
          child: Container(
            width: width,
            height: height,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
        errorWidget: (context, url, error) => CachedNetworkImage(
          imageUrl: faviconUrl,
          width: width,
          height: height,
          fit: BoxFit.contain,
          placeholder: (context, url) => Container(
            width: width,
            height: height,
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Icon(Icons.link, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          errorWidget: (context, url, error) => Container(
            width: width,
            height: height,
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Icon(Icons.link, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    } else {
      return CachedNetworkImage(
        imageUrl: faviconUrl,
        width: width,
        height: height,
        fit: BoxFit.contain,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Icon(Icons.link, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Icon(Icons.link, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
  }

  Widget _buildLinkCard(LinkModel link) {
    final isSelected = _selectedLinks.contains(link);

    if (_isGridView) {
      return GestureDetector(
        onTap: () {
          if (_isSelectionMode) {
            _toggleLinkSelection(link);
          } else {
            _openLink(link.url, useDefaultBrowser: true);
          }
        },
        onLongPress: () {
          if (!_isSelectionMode) {
            _toggleSelectionMode();
          }
          _toggleLinkSelection(link);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          child: _buildLinkImage(link),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Theme.of(context).colorScheme.surface,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              link.title.isNotEmpty ? link.title : link.domain,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  ),
                                  child: Icon(
                                    Icons.language,
                                    size: 10,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    link.domain,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (link.notes != null && link.notes!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                link.notes!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
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
                ),
              ),
              if (_isSelectionMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: AnimatedScale(
                    scale: isSelected ? 1.0 : 0.8,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.onPrimary)
                          : null,
                    ),
                  ),
                ),
              if (!_isSelectionMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _showLinkOptionsMenu(context, link),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      child: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (_isSelectionMode) {
              _toggleLinkSelection(link);
            } else {
              _openLink(link.url, useDefaultBrowser: true);
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              _toggleSelectionMode();
            }
            _toggleLinkSelection(link);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: _buildLinkImage(link, width: 48, height: 48),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        link.title.isNotEmpty ? link.title : link.domain,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (link.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          link.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        link.domain,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (link.notes != null && link.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          link.notes!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (_isSelectionMode)
                  AnimatedScale(
                    scale: isSelected ? 1.0 : 0.8,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.onPrimary)
                          : null,
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => _showLinkOptionsMenu(context, link),
                    child: Icon(
                      Icons.more_vert,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No links saved yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Add links manually or share them from other apps to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => loadLinks(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Saved Links',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
        elevation: 2,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: Icon(
                Icons.clear,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: _deselectAllLinks,
              tooltip: 'Deselect All',
            )
          else ...[
            IconButton(
              icon: Icon(
                Icons.refresh,
                color: _isRefreshing
                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                    : Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: _isRefreshing ? null : _refreshAllLinksMetadata,
              tooltip: 'Refresh Metadata',
            ),
            IconButton(
              icon: Icon(
                _isGridView ? Icons.list_rounded : Icons.grid_view_rounded,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () {
                setState(() {
                  _isGridView = !_isGridView;
                  _saveViewPreference();
                });
              },
              tooltip: _isGridView ? 'List view' : 'Grid view',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _links.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _refreshAllLinksMetadata,
        child: _isGridView
            ? GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 80),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: _links.length,
          itemBuilder: (context, index) => _buildLinkCard(_links[index]),
        )
            : ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 100, top: 16),
          itemCount: _links.length,
          itemBuilder: (context, index) => _buildLinkCard(_links[index]),
        ),
      ),
      floatingActionButton: _isSelectionMode && _selectedLinks.isNotEmpty
          ? Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: FloatingActionButton(
                  onPressed: _shareSelectedLinks,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.share, color: Colors.white),
                ),
              ),
            ),
            AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 300),
              child: FloatingActionButton(
                onPressed: _deleteSelectedLinks,
                backgroundColor: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
            ),
          ],
        ),
      )
          : null,
    );
  }
}
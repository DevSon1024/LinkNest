import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/link_model.dart';
import '../services/database_helper.dart';
import '../services/metadata_service.dart';
import 'links_page_widgets/link_card.dart';
import 'links_page_widgets/empty_state.dart';
import 'links_page_widgets/link_options_menu.dart';
import 'links_page_widgets/edit_notes_dialog.dart';
import 'link_details_page.dart';

enum SortOrder { latest, oldest }

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

class FolderLinksPageState extends State<FolderLinksPage>
    with TickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final List<LinkModel> _selectedLinks = [];
  List<LinkModel> _filteredLinks = [];
  bool _isGridView = false;
  bool _isSelectionMode = false;
  late AnimationController _fabAnimationController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  SortOrder _sortOrder = SortOrder.latest;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadViewPreference();
    _filteredLinks = widget.links;
    _sortLinks();
    _searchController.addListener(() {
      _filterLinks();
    });
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGridView = prefs.getBool('folder_links_page_view') ?? false;
    });
  }

  Future<void> _saveViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('folder_links_page_view', _isGridView);
  }

  void _filterLinks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredLinks = widget.links.where((link) {
        final titleMatch = link.title?.toLowerCase().contains(query) ?? false;
        final urlMatch = link.url.toLowerCase().contains(query);
        final tagMatch =
        link.tags.any((tag) => tag.toLowerCase().contains(query));
        return titleMatch || urlMatch || tagMatch;
      }).toList();
    });
  }

  void _sortLinks() {
    setState(() {
      _filteredLinks.sort((a, b) => _sortOrder == SortOrder.latest
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt));
    });
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

  void _selectAllLinks() {
    setState(() {
      if (_selectedLinks.length == _filteredLinks.length) {
        _selectedLinks.clear();
      } else {
        _selectedLinks.clear();
        _selectedLinks.addAll(_filteredLinks);
        if (!_isSelectionMode) {
          _toggleSelectionMode();
        }
      }
    });
  }

  Future<void> _shareSelectedLinks() async {
    if (_selectedLinks.isEmpty) return;

    final linksText = _selectedLinks
        .map((link) => '${link.title ?? ""}\n${link.url}')
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
        content: Text(
            'Are you sure you want to delete ${_selectedLinks.length} link(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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
          widget.links.removeWhere((l) => l.id == link.id);
        }
      }
      _selectedLinks.clear();
      _toggleSelectionMode();
      setState(() {});
      _showSnackBar('Links deleted successfully');
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.folderName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              try {
                await MetadataService.clearCache();
                for (var link in widget.links) {
                  final updatedMetadata =
                  await MetadataService.extractMetadata(link.url);
                  if (updatedMetadata != null) {
                    final updatedLink = link.copyWith(
                      title: updatedMetadata.title,
                      description: updatedMetadata.description,
                      imageUrl: updatedMetadata.imageUrl,
                      domain: updatedMetadata.domain,
                      notes: link.notes,
                    );
                    await _dbHelper.updateLink(updatedLink);
                    setState(() {
                      final index =
                      widget.links.indexWhere((l) => l.id == link.id);
                      if (index != -1) {
                        widget.links[index] = updatedLink;
                      }
                      _sortLinks();
                    });
                  }
                }
              } catch (e) {
                _showSnackBar('Error refreshing: $e');
              }
            },
            tooltip: 'Refresh metadata',
          ),
          PopupMenuButton<SortOrder>(
            icon: Icon(
              Icons.sort,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onSelected: (SortOrder order) {
              setState(() {
                _sortOrder = order;
                _sortLinks();
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOrder>>[
              const PopupMenuItem<SortOrder>(
                value: SortOrder.latest,
                child: Text('Sort by Latest'),
              ),
              const PopupMenuItem<SortOrder>(
                value: SortOrder.oldest,
                child: Text('Sort by Oldest'),
              ),
            ],
            tooltip: 'Sort links',
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by title, URL, or tag...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _filteredLinks.isEmpty
          ? const EmptyState()
          : Column(
        children: [
          if (_isSelectionMode)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: Row(
                children: [
                  Checkbox(
                    value:
                    _selectedLinks.length == _filteredLinks.length,
                    onChanged: (value) => _selectAllLinks(),
                  ),
                  Text(
                    '${_selectedLinks.length} selected',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _toggleSelectionMode,
                  )
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _sortLinks();
                });
              },
              child: _isGridView
                  ? GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 80),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: _filteredLinks.length,
                itemBuilder: (context, index) => LinkCard(
                  link: _filteredLinks[index],
                  isGridView: _isGridView,
                  isSelectionMode: _isSelectionMode,
                  isSelected: _selectedLinks
                      .contains(_filteredLinks[index]),
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleLinkSelection(_filteredLinks[index]);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LinkDetailsPage(
                              link: _filteredLinks[index]),
                        ),
                      );
                    }
                  },
                  onLongPress: () {
                    if (!_isSelectionMode) {
                      _toggleSelectionMode();
                    }
                    _toggleLinkSelection(_filteredLinks[index]);
                  },
                  onOptionsTap: () => _showLinkOptionsMenu(
                      context, _filteredLinks[index]),
                ),
              )
                  : ListView.builder(
                controller: _scrollController,
                padding:
                const EdgeInsets.only(bottom: 100, top: 16),
                itemCount: _filteredLinks.length,
                itemBuilder: (context, index) => LinkCard(
                  link: _filteredLinks[index],
                  isGridView: _isGridView,
                  isSelectionMode: _isSelectionMode,
                  isSelected: _selectedLinks
                      .contains(_filteredLinks[index]),
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleLinkSelection(_filteredLinks[index]);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LinkDetailsPage(
                              link: _filteredLinks[index]),
                        ),
                      );
                    }
                  },
                  onLongPress: () {
                    if (!_isSelectionMode) {
                      _toggleSelectionMode();
                    }
                    _toggleLinkSelection(_filteredLinks[index]);
                  },
                  onOptionsTap: () => _showLinkOptionsMenu(
                      context, _filteredLinks[index]),
                ),
              ),
            ),
          ),
        ],
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

  Future<void> _openLink(String url, {bool useDefaultBrowser = false}) async {
    try {
      String formattedUrl = url.trim();
      if (!formattedUrl.startsWith('http://') &&
          !formattedUrl.startsWith('https://')) {
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
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
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

  void _showLinkOptionsMenu(BuildContext context, LinkModel link) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => LinkOptionsMenu(
        link: link,
        onOpenInApp: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LinkDetailsPage(link: link),
            ),
          );
        },
        onOpenInBrowser: () => _openLink(link.url, useDefaultBrowser: true),
        onEditNotes: () => _showEditNotesDialog(context, link),
        onCopyUrl: () {
          Clipboard.setData(ClipboardData(text: link.url));
          _showSnackBar('URL copied to clipboard');
        },
        onShare: () async {
          try {
            await Share.share(
              '${link.title ?? ""}\n${link.url}',
              subject: link.title != null && link.title!.isNotEmpty
                  ? link.title!
                  : 'Shared Link',
            );
          } catch (e) {
            _showSnackBar('Error sharing link: $e');
          }
        },
        onDelete: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Delete Link'),
              content:
              const Text('Are you sure you want to delete this link?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Delete',
                      style: TextStyle(color: Colors.white)),
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
                backgroundColor: Theme.of(context).colorScheme.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                action: SnackBarAction(
                  label: 'Undo',
                  textColor: Colors.blue,
                  onPressed: () async {
                    await _dbHelper.insertLink(deletedLink);
                    setState(() {
                      widget.links.add(deletedLink);
                      _sortLinks();
                    });
                  },
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _showEditNotesDialog(
      BuildContext context, LinkModel link) async {
    await showDialog(
      context: context,
      builder: (context) => EditNotesDialog(
        link: link,
        onSave: (updatedLink) async {
          await _dbHelper.updateLink(updatedLink);
          setState(() {
            final index = widget.links.indexWhere((l) => l.id == link.id);
            if (index != -1) {
              widget.links[index] = updatedLink;
            }
            _sortLinks();
          });
          _showSnackBar('Notes saved');
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/cupertino.dart';
import '../models/link_model.dart';
import '../services/database_helper.dart';
import '../services/metadata_service.dart';
import 'links_page_widgets/link_card.dart';
import 'links_page_widgets/empty_state.dart';
import 'links_page_widgets/link_options_menu.dart';
import 'links_page_widgets/edit_notes_dialog.dart';
import 'package:flutter/services.dart';
import 'link_details_page.dart';

enum SortOrder { latest, oldest }
enum ViewMode { list, grid }

class LinksPage extends StatefulWidget {
  final VoidCallback? onRefresh;

  const LinksPage({super.key, this.onRefresh});

  @override
  LinksPageState createState() => LinksPageState();
}

class LinksPageState extends State<LinksPage> with TickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<LinkModel> _links = [];
  List<LinkModel> _filteredLinks = [];
  final List<LinkModel> _selectedLinks = [];
  ViewMode _viewMode = ViewMode.list;
  bool _isLoading = false;
  bool _isSelectionMode = false;
  bool _isSearchVisible = false;
  late AnimationController _fabAnimationController;
  late AnimationController _searchAnimationController;
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
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadViewPreference();
    loadLinks();
    _searchController.addListener(() {
      _filterLinks();
    });
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _searchAnimationController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _viewMode = prefs.getBool('links_page_view') ?? false
          ? ViewMode.grid
          : ViewMode.list;
    });
  }

  Future<void> _saveViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('links_page_view', _viewMode == ViewMode.grid);
  }

  Future<void> loadLinks() async {
    setState(() => _isLoading = true);
    try {
      final links = await _dbHelper.getAllLinks();
      setState(() {
        _links = links;
        _filteredLinks = links;
        _sortLinks();
      });
    } catch (e) {
      _showSnackBar('Error loading links: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterLinks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredLinks = _links;
      } else {
        _filteredLinks = _links.where((link) {
          final titleMatch = link.title?.toLowerCase().contains(query) ?? false;
          final urlMatch = link.url.toLowerCase().contains(query);
          final domainMatch = link.domain?.toLowerCase().contains(query) ?? false;
          final tagMatch = link.tags.any((tag) => tag.toLowerCase().contains(query));
          return titleMatch || urlMatch || domainMatch || tagMatch;
        }).toList();
      }
      _sortLinks();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
        _filteredLinks = _links;
        _sortLinks();
        _searchAnimationController.reverse();
      } else {
        _searchAnimationController.forward();
      }
    });
  }

  void _sortLinks() {
    _filteredLinks.sort((a, b) => _sortOrder == SortOrder.latest
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));
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
        .map((link) => '${link.title ?? link.url}\n${link.url}')
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Links',
            style: TextStyle(fontWeight: FontWeight.w600)),
        content: Text(
            'Are you sure you want to delete ${_selectedLinks.length} link(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
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
      await loadLinks();
      _showSnackBar('Links deleted successfully');
    }
  }

  void _showSnackBar(String message, {bool persistent = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration:
        persistent ? const Duration(days: 1) : const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildLinkIcon(LinkModel link) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(CupertinoIcons.link,
          color: Theme.of(context).colorScheme.primary, size: 20),
    );
  }

  Widget _buildModernLinkTile(LinkModel link, int index) {
    final isSelected = _selectedLinks.contains(link);
    final domain = link.domain ?? Uri.parse(link.url).host;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_isSelectionMode) {
              _toggleLinkSelection(link);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LinkDetailsPage(link: link),
                ),
              );
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              _toggleSelectionMode();
            }
            _toggleLinkSelection(link);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (_isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) => _toggleLinkSelection(link),
                    shape: const CircleBorder(),
                  )
                else
                  _buildLinkIcon(link),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.title?.isNotEmpty == true ? link.title! : domain,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        domain,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${link.createdAt.day} ${_getMonthName(link.createdAt.month)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),

                if (!_isSelectionMode)
                  IconButton(
                    onPressed: () => _showLinkOptionsMenu(context, link),
                    icon: const Icon(CupertinoIcons.ellipsis, size: 18),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  List<Widget> _buildGroupedLinks() {
    if (_filteredLinks.isEmpty) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final threeDaysAgo = today.subtract(const Duration(days: 3));

    final todayLinks = <LinkModel>[];
    final threeDaysAgoLinks = <LinkModel>[];
    final olderLinks = <LinkModel>[];

    for (final link in _filteredLinks) {
      final linkDate = DateTime(
        link.createdAt.year,
        link.createdAt.month,
        link.createdAt.day,
      );

      if (linkDate == today) {
        todayLinks.add(link);
      } else if (linkDate.isAfter(threeDaysAgo)) {
        threeDaysAgoLinks.add(link);
      } else {
        olderLinks.add(link);
      }
    }

    final widgets = <Widget>[];

    if (todayLinks.isNotEmpty) {
      widgets.add(_buildSectionHeader('Today'));
      for (int i = 0; i < todayLinks.length; i++) {
        widgets.add(_buildModernLinkTile(todayLinks[i], i));
      }
    }

    if (threeDaysAgoLinks.isNotEmpty) {
      widgets.add(_buildSectionHeader('3 days ago'));
      for (int i = 0; i < threeDaysAgoLinks.length; i++) {
        widgets.add(_buildModernLinkTile(threeDaysAgoLinks[i], i));
      }
    }

    if (olderLinks.isNotEmpty) {
      // Group older links by date
      final dateGroups = <String, List<LinkModel>>{};
      for (final link in olderLinks) {
        final dateKey = '${link.createdAt.year}/${link.createdAt.month.toString().padLeft(2, '0')}/${link.createdAt.day.toString().padLeft(2, '0')}';
        dateGroups.putIfAbsent(dateKey, () => []).add(link);
      }

      final sortedDates = dateGroups.keys.toList()..sort((a, b) => b.compareTo(a));

      for (final dateKey in sortedDates) {
        widgets.add(_buildSectionHeader(dateKey));
        final linksForDate = dateGroups[dateKey]!;
        for (int i = 0; i < linksForDate.length; i++) {
          widgets.add(_buildModernLinkTile(linksForDate[i], i));
        }
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isSearchVisible
              ? TextField(
            key: const Key('search_field'),
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search by title, URL, domain, or tag...',
              border: InputBorder.none,
              hintStyle: TextStyle(fontSize: 16),
            ),
            style: const TextStyle(fontSize: 16),
          )
              : const Text(
            'Saved Links',
            key: Key('title_text'),
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _toggleSearch,
            icon: Icon(_isSearchVisible ? CupertinoIcons.xmark : CupertinoIcons.search),
          ),
          if (!_isSearchVisible) ...[
            IconButton(
              onPressed: () {
                setState(() {
                  _viewMode = _viewMode == ViewMode.list ? ViewMode.grid : ViewMode.list;
                  _saveViewPreference();
                });
              },
              icon: Icon(_viewMode == ViewMode.list
                  ? CupertinoIcons.square_grid_2x2
                  : CupertinoIcons.list_bullet),
            ),
            PopupMenuButton(
              icon: const Icon(CupertinoIcons.ellipsis),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Row(
                    children: [
                      Icon(CupertinoIcons.arrow_clockwise, size: 18),
                      SizedBox(width: 8),
                      Text('Refresh metadata'),
                    ],
                  ),
                  onTap: () async {
                    _showSnackBar('Fetching metadata...', persistent: true);
                    try {
                      await MetadataService.clearCache();
                      for (var link in _links) {
                        final updatedMetadata =
                        await MetadataService.extractMetadata(link.url);
                        if (updatedMetadata != null) {
                          final updatedLink = link.copyWith(
                            title: updatedMetadata.title,
                            description: updatedMetadata.description,
                            imageUrl: updatedMetadata.imageUrl,
                            domain: updatedMetadata.domain,
                            status: MetadataStatus.completed,
                          );
                          await _dbHelper.updateLink(updatedLink);
                        }
                      }
                      await loadLinks();
                      _showSnackBar('Metadata fetching complete!');
                    } catch (e) {
                      _showSnackBar('Error refreshing: $e');
                    }
                  },
                ),
                PopupMenuItem(
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.sort_down, size: 18),
                      const SizedBox(width: 8),
                      Text(_sortOrder == SortOrder.latest ? 'Sort by Oldest' : 'Sort by Latest'),
                    ],
                  ),
                  onTap: () {
                    setState(() {
                      _sortOrder = _sortOrder == SortOrder.latest
                          ? SortOrder.oldest
                          : SortOrder.latest;
                      _sortLinks();
                    });
                  },
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Items count
          if (!_isSearchVisible)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${_filteredLinks.length} items in total',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),

          // Search results info
          if (_isSearchVisible && _searchController.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Found ${_filteredLinks.length} results for "${_searchController.text}"',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),

          // Selection mode header
          if (_isSelectionMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: Row(
                children: [
                  Checkbox(
                    value: _selectedLinks.length == _filteredLinks.length,
                    onChanged: (value) => _selectAllLinks(),
                    shape: const CircleBorder(),
                  ),
                  Text(
                    '${_selectedLinks.length} selected',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark),
                    onPressed: _toggleSelectionMode,
                  )
                ],
              ),
            ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLinks.isEmpty
                ? _searchController.text.isNotEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.search,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No links found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try adjusting your search terms',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            )
                : const EmptyState()
                : RefreshIndicator(
              onRefresh: loadLinks,
              child: _viewMode == ViewMode.list
                  ? ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 100),
                children: _buildGroupedLinks(),
              )
                  : GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _filteredLinks.length,
                itemBuilder: (context, index) => LinkCard(
                  link: _filteredLinks[index],
                  isGridView: true,
                  isSelectionMode: _isSelectionMode,
                  isSelected: _selectedLinks.contains(_filteredLinks[index]),
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleLinkSelection(_filteredLinks[index]);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LinkDetailsPage(link: _filteredLinks[index]),
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
                  onOptionsTap: () => _showLinkOptionsMenu(context, _filteredLinks[index]),
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
            FloatingActionButton(
              onPressed: _shareSelectedLinks,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(CupertinoIcons.share),
            ),
            const SizedBox(width: 16),
            FloatingActionButton(
              onPressed: _deleteSelectedLinks,
              backgroundColor: Colors.red,
              child: const Icon(CupertinoIcons.trash),
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
              '${link.title ?? link.url}\n${link.url}',
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
            await loadLinks();
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
                    await loadLinks();
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
          await loadLinks();
          _showSnackBar('Notes saved');
        },
      ),
    );
  }
}
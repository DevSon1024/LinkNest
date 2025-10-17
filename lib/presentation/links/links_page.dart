import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/cupertino.dart';
import '../../data/models/link_model.dart';
import '../../core/services/database_helper.dart';
import '../../core/services/metadata_service.dart';
import '../widgets/link_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/enhanced_snackbar.dart';
import 'widgets/link_options_menu.dart';
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
  bool _isLoadingMetadata = false;
  late AnimationController _fabAnimationController;
  late AnimationController _searchAnimationController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  SortOrder _sortOrder = SortOrder.latest;

  // Lazy loading variables
  int _currentPage = 0;
  static const int _pageSize = 10;
  bool _isLazyLoading = false;

  // Refresh control variables
  DateTime? _lastRefreshTime;
  static const Duration _refreshCooldown = Duration(minutes: 5); // 5 minute cooldown

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
    _scrollController.addListener(_onScroll);
    _preloadMetadata();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _searchAnimationController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreLinks();
    }
  }

  Future<void> _loadMoreLinks() async {
    if (_isLazyLoading) return;

    setState(() => _isLazyLoading = true);

    // Simulate loading more metadata in background
    final startIndex = _currentPage * _pageSize;
    final endIndex = startIndex + _pageSize;

    if (startIndex < _links.length) {
      final batch = _links.skip(startIndex).take(_pageSize).toList();
      await _loadMetadataForBatch(batch);
      _currentPage++;
    }

    setState(() => _isLazyLoading = false);
  }

  Future<void> _loadMetadataForBatch(List<LinkModel> batch) async {
    for (final link in batch) {
      if (link.status == MetadataStatus.pending && !link.isMetadataLoaded) {
        try {
          final metadata = await MetadataService.extractMetadata(link.url);
          if (metadata != null && mounted) {
            final updatedLink = link.copyWith(
              title: metadata.title,
              description: metadata.description,
              imageUrl: metadata.imageUrl,
              domain: metadata.domain,
              status: MetadataStatus.completed,
              isMetadataLoaded: true,
            );
            await _dbHelper.updateLink(updatedLink);

            // Update in current lists
            final index = _links.indexWhere((l) => l.id == link.id);
            if (index != -1) {
              setState(() {
                _links[index] = updatedLink;
              });
            }
            _filterLinks();
          }
        } catch (e) {
          print('Error loading metadata for ${link.url}: $e');
        }
      }

      // Small delay to prevent overwhelming the system
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _preloadMetadata() async {
    // Load metadata for first batch in background
    await Future.delayed(const Duration(milliseconds: 500));
    _loadMoreLinks();
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
        _currentPage = 0;
        _sortLinks();
      });
    } catch (e) {
      _showEnhancedSnackBar('Error loading links: $e', type: SnackBarType.error);
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
          final domainMatch = link.domain.toLowerCase().contains(query);
          final tagMatch = link.tags.any((tag) => tag.toLowerCase().contains(query));
          return titleMatch || urlMatch || domainMatch || tagMatch;
        }).toList();
      }
      _sortLinks();
    });
  }

  void updateLink(LinkModel updatedLink) {
    if (!mounted) return;
    setState(() {
      final index = _links.indexWhere((link) => link.id == updatedLink.id);
      if (index != -1) {
        _links[index] = updatedLink;
      }

      final filteredIndex = _filteredLinks.indexWhere((link) => link.id == updatedLink.id);
      if (filteredIndex != -1) {
        _filteredLinks[filteredIndex] = updatedLink;
      }
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
      _showEnhancedSnackBar('Error sharing links: $e', type: SnackBarType.error);
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
      _showEnhancedSnackBar('Links deleted successfully', type: SnackBarType.success);
    }
  }

  void _showEnhancedSnackBar(String message, {SnackBarType type = SnackBarType.info, bool persistent = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      EnhancedSnackBar.create(
        context: context,
        message: message,
        type: type,
        persistent: persistent,
      ),
    );
  }

  // UPDATED: Smart refresh logic with cooldown and completion check
  Future<void> _refreshMetadata() async {
    // Check if we're already refreshing
    if (_isLoadingMetadata) {
      _showEnhancedSnackBar('Refresh already in progress...', type: SnackBarType.info);
      return;
    }

    // Check if we recently refreshed (within cooldown period)
    final now = DateTime.now();
    if (_lastRefreshTime != null &&
        now.difference(_lastRefreshTime!) < _refreshCooldown) {
      final remainingTime = _refreshCooldown - now.difference(_lastRefreshTime!);
      final remainingMinutes = remainingTime.inMinutes;
      final remainingSeconds = remainingTime.inSeconds % 60;

      _showEnhancedSnackBar(
          'Please wait ${remainingMinutes}m ${remainingSeconds}s before refreshing again',
          type: SnackBarType.info
      );
      return;
    }

    // Check if all links already have complete metadata
    final pendingLinks = _links.where((link) =>
    link.status == MetadataStatus.pending ||
        link.status == MetadataStatus.failed ||
        !link.isMetadataLoaded
    ).toList();

    if (pendingLinks.isEmpty && _links.isNotEmpty) {
      _showEnhancedSnackBar(
          'Database already refreshed! All metadata is up to date.',
          type: SnackBarType.success
      );
      return;
    }

    // Proceed with refresh
    setState(() => _isLoadingMetadata = true);

    try {
      await MetadataService.clearCache();

      // Only process links that need metadata updates
      final linksToUpdate = pendingLinks.isNotEmpty ? pendingLinks : _links;
      final totalLinks = linksToUpdate.length;

      if (totalLinks == 0) {
        _showEnhancedSnackBar('No links to refresh', type: SnackBarType.info);
        return;
      }

      _showEnhancedSnackBar(
          'Refreshing metadata for ${totalLinks} link(s)...',
          type: SnackBarType.info,
          persistent: true
      );

      // Process in smaller batches to show progress
      const batchSize = 3; // Reduced batch size for better progress tracking
      int processedCount = 0;
      int successCount = 0;

      for (int i = 0; i < linksToUpdate.length; i += batchSize) {
        final batch = linksToUpdate.skip(i).take(batchSize).toList();

        for (var link in batch) {
          try {
            final updatedMetadata = await MetadataService.extractMetadata(link.url);
            if (updatedMetadata != null) {
              final updatedLink = link.copyWith(
                title: updatedMetadata.title,
                description: updatedMetadata.description,
                imageUrl: updatedMetadata.imageUrl,
                domain: updatedMetadata.domain,
                status: MetadataStatus.completed,
                isMetadataLoaded: true,
              );
              await _dbHelper.updateLink(updatedLink);
              successCount++;
            } else {
              // Mark as failed if no metadata could be extracted
              final failedLink = link.copyWith(
                status: MetadataStatus.failed,
                isMetadataLoaded: true,
              );
              await _dbHelper.updateLink(failedLink);
            }
          } catch (e) {
            print('Error updating metadata for ${link.url}: $e');
            // Mark as failed on error
            final failedLink = link.copyWith(
              status: MetadataStatus.failed,
              isMetadataLoaded: true,
            );
            await _dbHelper.updateLink(failedLink);
          }

          processedCount++;

          // Update progress (ensure we don't exceed 100%)
          final progress = ((processedCount / totalLinks) * 100).clamp(0, 100).round();
          if (mounted && progress < 100) {
            _showEnhancedSnackBar(
                'Refreshing metadata... ${progress}%',
                type: SnackBarType.info,
                persistent: true
            );
          }
        }

        // Small delay between batches to prevent overwhelming the system
        if (i + batchSize < linksToUpdate.length) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      // Update the last refresh time
      _lastRefreshTime = DateTime.now();

      // Reload the links to reflect changes
      await loadLinks();

      // Show completion message
      final String completionMessage;
      if (successCount == totalLinks) {
        completionMessage = 'Metadata refresh complete! Updated $successCount link(s).';
      } else {
        final failedCount = totalLinks - successCount;
        completionMessage = 'Metadata refresh complete! Updated $successCount, failed $failedCount link(s).';
      }

      _showEnhancedSnackBar(completionMessage, type: SnackBarType.success);

    } catch (e) {
      _showEnhancedSnackBar('Error refreshing metadata: $e', type: SnackBarType.error);
    } finally {
      if (mounted) {
        setState(() => _isLoadingMetadata = false);
      }
    }
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
    final domain = link.domain.isNotEmpty ? link.domain : Uri.parse(link.url).host;

    return Dismissible(
      key: Key('link_${link.id}'),
      background: Container(
        color: Colors.yellow.shade700,
        child: const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 20),
            child: Icon(Icons.star, color: Colors.white),
          ),
        ),
      ),
      secondaryBackground: Container(
        color: Colors.red.shade700,
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 20),
            child: Icon(Icons.delete, color: Colors.white),
          ),
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (link.id != null) {
            await _dbHelper.toggleFavoriteStatus(link.id!, !link.isFavorite);
            await loadLinks();
            _showEnhancedSnackBar(
                link.isFavorite ? 'Removed from favorites' : 'Added to favorites',
                type: link.isFavorite ? SnackBarType.info : SnackBarType.success);
          }
          return false;
        } else {
          final bool? res = await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  content: Text("Are you sure you want to delete ${link.title ?? 'this link'}?"),
                  actions: <Widget>[
                    TextButton(
                      child: const Text("Cancel", style: TextStyle(color: Colors.black)),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    TextButton(
                      child: const Text("Delete", style: TextStyle(color: Colors.red)),
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                );
              });
          if (res == true) {
            if (link.id != null) {
              await _dbHelper.deleteLink(link.id!);
              await loadLinks();
              _showEnhancedSnackBar('Link deleted', type: SnackBarType.success);
            }
          }
          return res;
        }
      },
      child: Container(
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
                ).then((_) async => await loadLinks());
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
                        if (link.tags.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4.0,
                            runSpacing: 2.0,
                            children: link.tags.take(3).map((tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tag,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            )).toList(),
                          ),
                        ],
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
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        onPressed: () => _showLinkOptionsMenu(context, link),
                        icon: const Icon(CupertinoIcons.ellipsis, size: 18),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                ],
              ),
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

    // Add bottom padding for navigation bar
    widgets.add(const SizedBox(height: 120));

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
            style: IconButton.styleFrom(
              backgroundColor: _isSearchVisible
                  ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.3)
                  : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              padding: const EdgeInsets.all(12),
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
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
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                padding: const EdgeInsets.all(12),
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            PopupMenuButton(
              icon: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.ellipsis, size: 20),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: !_isLoadingMetadata, // Disable when already refreshing
                  child: Row(
                    children: [
                      Icon(
                        _isLoadingMetadata ? CupertinoIcons.refresh : CupertinoIcons.arrow_clockwise,
                        size: 18,
                        color: _isLoadingMetadata ? Theme.of(context).colorScheme.outline : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isLoadingMetadata ? 'Refreshing...' : 'Refresh metadata',
                        style: TextStyle(
                          color: _isLoadingMetadata ? Theme.of(context).colorScheme.outline : null,
                        ),
                      ),
                    ],
                  ),
                  onTap: _isLoadingMetadata ? null : _refreshMetadata,
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
      body: RefreshIndicator(
        onRefresh: _refreshMetadata, // This handles the pull-to-refresh
        child: Column(
          children: [
            // Items count with refresh indicator
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
                    if (_isLoadingMetadata) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                    if (_lastRefreshTime != null) ...[
                      const Spacer(),
                      Text(
                        'Last refreshed: ${_lastRefreshTime!.hour.toString().padLeft(2, '0')}:${_lastRefreshTime!.minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Rest of the existing UI code remains the same...
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
                  : _viewMode == ViewMode.list
                  ? ListView(
                controller: _scrollController,
                children: _buildGroupedLinks(),
              )
                  : GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), // Added bottom margin
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _filteredLinks.length + (_isLazyLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _filteredLinks.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  return LinkCard(
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
                        ).then((_) async => await loadLinks());
                      }
                    },
                    onLongPress: () {
                      if (!_isSelectionMode) {
                        _toggleSelectionMode();
                      }
                      _toggleLinkSelection(_filteredLinks[index]);
                    },
                    onOptionsTap: () => _showLinkOptionsMenu(context, _filteredLinks[index]),
                    onDelete: (link) async {
                      if (link.id != null) {
                        await _dbHelper.deleteLink(link.id!);
                        await loadLinks();
                        _showEnhancedSnackBar('Link deleted', type: SnackBarType.success);
                      }
                    },
                    onFavoriteToggle: (link) async {
                      if (link.id != null) {
                        await _dbHelper.toggleFavoriteStatus(link.id!, !link.isFavorite);
                        await loadLinks();
                        _showEnhancedSnackBar(
                            link.isFavorite ? 'Removed from favorites' : 'Added to favorites',
                            type: link.isFavorite ? SnackBarType.info : SnackBarType.success);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isSelectionMode && _selectedLinks.isNotEmpty
          ? Padding(
        padding: const EdgeInsets.only(bottom: 100.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'share_links_page',
              onPressed: _shareSelectedLinks,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(CupertinoIcons.share),
            ),
            const SizedBox(width: 16),
            FloatingActionButton(
              heroTag: 'delete_links_page',
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

  // Rest of the methods remain the same...
  Future<void> _openLink(String url, {bool useDefaultBrowser = false}) async {
    try {
      String formattedUrl = url.trim();
      if (!formattedUrl.startsWith('http://') &&
          !formattedUrl.startsWith('https://')) {
        formattedUrl = 'https://$formattedUrl';
      }

      final uri = Uri.tryParse(formattedUrl);
      if (uri == null || !uri.hasScheme) {
        _showEnhancedSnackBar('Invalid URL: $formattedUrl', type: SnackBarType.error);
        return;
      }

      if (useDefaultBrowser) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showEnhancedSnackBar('Cannot open link in default browser', type: SnackBarType.error);
        }
      } else {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
        } else {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            _showEnhancedSnackBar('Cannot open link', type: SnackBarType.error);
          }
        }
      }
    } catch (e) {
      _showEnhancedSnackBar('Error opening URL: $e', type: SnackBarType.error);
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
        onCopyUrl: () {
          Clipboard.setData(ClipboardData(text: link.url));
          _showEnhancedSnackBar('URL copied to clipboard', type: SnackBarType.success);
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
            _showEnhancedSnackBar('Error sharing link: $e', type: SnackBarType.error);
          }
        },
        onDelete: () async {
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
            await loadLinks();
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
}
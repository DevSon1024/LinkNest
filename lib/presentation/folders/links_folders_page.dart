import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'folder_links_page.dart';
import '../../data/models/link_model.dart';
import '../../core/services/database_helper.dart';
import '../../core/services/metadata_service.dart';

class LinksFoldersPage extends StatefulWidget {
  final VoidCallback? onRefresh;

  const LinksFoldersPage({super.key, this.onRefresh});

  @override
  LinksFoldersPageState createState() => LinksFoldersPageState();
}

class LinksFoldersPageState extends State<LinksFoldersPage>
    with TickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, List<LinkModel>> _folders = {};
  List<LinkModel> _allLinks = [];
  Map<String, List<LinkModel>> _filteredFolders = {};
  final List<String> _selectedFolders = [];
  bool _isGridView = false;
  bool _isLoading = false;
  bool _isSelectionMode = false;
  bool _isSearchVisible = false;
  late AnimationController _fabAnimationController;
  late AnimationController _searchAnimationController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

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
    loadFolders();
    _searchController.addListener(() {
      _filterFolders();
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
      _isGridView = prefs.getBool('links_folders_page_view') ?? false;
    });
  }

  Future<void> _saveViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('links_folders_page_view', _isGridView);
  }

  Future<void> loadFolders() async {
    setState(() => _isLoading = true);
    try {
      final links = await _dbHelper.getAllLinks();
      final folders = <String, List<LinkModel>>{};
      for (var link in links) {
        final domain = link.domain.toLowerCase();
        final folderName = _getFolderName(domain);
        folders.putIfAbsent(folderName, () => []).add(link);
      }
      folders.forEach((key, value) {
        value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
      setState(() {
        _allLinks = links;
        _folders = folders;
        _filteredFolders = folders;
      });
    } catch (e) {
      _showSnackBar('Error loading folders: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterFolders() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFolders = _folders;
      } else {
        _filteredFolders = {};
        _folders.forEach((folderName, links) {
          if (folderName.toLowerCase().contains(query)) {
            _filteredFolders[folderName] = links;
          }
        });
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
        _filterFolders();
        _searchAnimationController.reverse();
      } else {
        _searchAnimationController.forward();
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedFolders.clear();
      }
    });
    if (_isSelectionMode) {
      _fabAnimationController.forward();
    } else {
      _fabAnimationController.reverse();
    }
  }

  void _toggleFolderSelection(String folderName) {
    setState(() {
      if (_selectedFolders.contains(folderName)) {
        _selectedFolders.remove(folderName);
      } else {
        _selectedFolders.add(folderName);
      }
      if (_selectedFolders.isEmpty && _isSelectionMode) {
        _toggleSelectionMode();
      }
    });
  }

  String _getFolderName(String domain) {
    String normalizedDomain = domain.replaceFirst(RegExp(r'^www\.'), '');
    final domainMap = {
      'google.com': 'Google',
      'youtube.com': 'YouTube',
      'instagram.com': 'Instagram',
      'animepahe.com': 'Animepahe',
      'reddit.com': 'Reddit',
      'twitter.com': 'Twitter',
      'x.com': 'X (Twitter)',
      'facebook.com': 'Facebook',
      'linkedin.com': 'LinkedIn',
      'github.com': 'GitHub',
      'stackoverflow.com': 'Stack Overflow',
      'medium.com': 'Medium',
      'dev.to': 'Dev.to',
      'netflix.com': 'Netflix',
      'amazon.com': 'Amazon',
      'tiktok.com': 'TikTok',
      'pinterest.com': 'Pinterest',
      'discord.com': 'Discord',
      'telegram.org': 'Telegram',
      'whatsapp.com': 'WhatsApp',
    };
    if (domainMap.containsKey(normalizedDomain)) {
      return domainMap[normalizedDomain]!;
    }
    final parts = normalizedDomain.split('.');
    if (parts.length >= 2) {
      return parts[parts.length - 2].capitalize();
    }
    return parts.first.capitalize();
  }

  String _getFaviconUrl(String domain) {
    String normalizedDomain = domain.replaceFirst(RegExp(r'^www\.'), '');
    return 'https://www.google.com/s2/favicons?domain=$normalizedDomain&sz=64';
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

  void _showFolderOptionsMenu(BuildContext context, String folderName) {
    final links = _folders[folderName]!;
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(CupertinoIcons.folder_open,
                    color: Theme.of(context).colorScheme.onSurface),
                title: const Text('Open Folder'),
                subtitle:
                Text('${links.length} link${links.length == 1 ? '' : 's'}'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FolderLinksPage(
                        folderName: folderName,
                        links: links,
                      ),
                    ),
                  ).then((_) => loadFolders());
                },
              ),
              ListTile(
                leading: Icon(CupertinoIcons.info,
                    color: Theme.of(context).colorScheme.onSurface),
                title: const Text('Folder Info'),
                onTap: () {
                  Navigator.pop(context);
                  _showFolderInfo(context, folderName);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showFolderInfo(BuildContext context, String folderName) {
    final links = _folders[folderName]!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              child: CachedNetworkImage(
                imageUrl: _getFaviconUrl(links.first.domain),
                placeholder: (context, url) => Icon(
                  CupertinoIcons.folder_fill,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                errorWidget: (context, url, error) => Icon(
                  CupertinoIcons.folder_fill,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                folderName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Links: ${links.length}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Domain: ${links.first.domain}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Latest Link: ${links.first.createdAt.toString().split(' ')[0]}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FolderLinksPage(
                    folderName: folderName,
                    links: links,
                  ),
                ),
              ).then((_) => loadFolders());
            },
            child: const Text('Open Folder'),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderCard(String folderName) {
    final links = _filteredFolders[folderName]!;
    final isSelected = _selectedFolders.contains(folderName);

    if (_isGridView) {
      return GestureDetector(
        onTap: () {
          if (_isSelectionMode) {
            _toggleFolderSelection(folderName);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FolderLinksPage(
                  folderName: folderName,
                  links: links,
                ),
              ),
            ).then((_) => loadFolders());
          }
        },
        onLongPress: () {
          if (!_isSelectionMode) {
            _toggleSelectionMode();
          }
          _toggleFolderSelection(folderName);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: isSelected
                ? Border.all(
                color: Theme.of(context).colorScheme.primary, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      child: CachedNetworkImage(
                        imageUrl: _getFaviconUrl(links.first.domain),
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          highlightColor:
                          Theme.of(context).colorScheme.surfaceContainer,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          CupertinoIcons.folder_fill,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 32,
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folderName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.link,
                          size: 12,
                          color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${links.length} link${links.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check,
                          size: 16,
                          color: Theme.of(context).colorScheme.onPrimary)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (_isSelectionMode) {
              _toggleFolderSelection(folderName);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FolderLinksPage(
                    folderName: folderName,
                    links: links,
                  ),
                ),
              ).then((_) => loadFolders());
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              _toggleSelectionMode();
            }
            _toggleFolderSelection(folderName);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surface,
              border: isSelected
                  ? Border.all(
                  color: Theme.of(context).colorScheme.primary, width: 1)
                  : Border.all(
                  color: Theme.of(context).dividerColor, width: 0.5),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainer,
                  child: CachedNetworkImage(
                    imageUrl: _getFaviconUrl(links.first.domain),
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      highlightColor:
                      Theme.of(context).colorScheme.surfaceContainer,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Icon(
                      CupertinoIcons.folder_fill,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        folderName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${links.length} link${links.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Domain: ${links.first.domain}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check,
                          size: 16,
                          color: Theme.of(context).colorScheme.onPrimary)
                          : null,
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => _showFolderOptionsMenu(context, folderName),
                    child: Icon(
                      CupertinoIcons.ellipsis,
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
            CupertinoIcons.folder_open,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No folders yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'When you save links, they will be automatically organized into folders here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: loadFolders,
            icon: const Icon(CupertinoIcons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isSearchVisible
              ? TextField(
            key: const Key('search_field'),
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search folders...',
              border: InputBorder.none,
              hintStyle: TextStyle(fontSize: 16),
            ),
            style: const TextStyle(fontSize: 16),
          )
              : const Text(
            'Folders',
            key: Key('title_text'),
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _toggleSearch,
            icon: Icon(
                _isSearchVisible ? CupertinoIcons.xmark : CupertinoIcons.search),
          ),
          if (!_isSearchVisible) ...[
            IconButton(
              onPressed: () {
                setState(() {
                  _isGridView = !_isGridView;
                  _saveViewPreference();
                });
              },
              icon: Icon(_isGridView
                  ? CupertinoIcons.list_bullet
                  : CupertinoIcons.square_grid_2x2),
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.refresh),
              onPressed: () async {
                _showSnackBar('Refreshing metadata...');
                try {
                  await MetadataService.clearCache();
                  for (var link in _allLinks) {
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
                  await loadFolders();
                  _showSnackBar('Metadata refreshed!');
                } catch (e) {
                  _showSnackBar('Error refreshing: $e');
                }
              },
              tooltip: 'Refresh metadata',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredFolders.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: loadFolders,
        child: _isGridView
            ? GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 80),
          gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _filteredFolders.keys.length,
          itemBuilder: (context, index) {
            final folderName =
            _filteredFolders.keys.elementAt(index);
            return _buildFolderCard(folderName);
          },
        )
            : ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 100, top: 10),
          itemCount: _filteredFolders.keys.length,
          itemBuilder: (context, index) {
            final folderName =
            _filteredFolders.keys.elementAt(index);
            return _buildFolderCard(folderName);
          },
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/database_helper.dart';
import '../../data/models/link_model.dart';
import '../widgets/enhanced_snackbar.dart';
import '../links/links_page.dart';
import '../links/link_details_page.dart';
class TagsPage extends StatefulWidget {
  const TagsPage({super.key});

  @override
  _TagsPageState createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> with TickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, TagInfo> _tags = {};
  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedTags = <String>{};
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredTags = [];
  TagSortType _sortType = TagSortType.alphabetical;

  late AnimationController _fabAnimationController;
  late AnimationController _searchAnimationController;
  bool _isSearchVisible = false;

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
    _loadTags();
    _searchController.addListener(_filterTags);
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _searchAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    setState(() => _isLoading = true);
    try {
      final links = await _dbHelper.getAllLinks();
      final tagInfo = <String, TagInfo>{};

      for (var link in links) {
        for (var tag in link.tags) {
          if (tagInfo.containsKey(tag)) {
            tagInfo[tag] = tagInfo[tag]!.copyWith(
              count: tagInfo[tag]!.count + 1,
              lastUsed: link.createdAt.isAfter(tagInfo[tag]!.lastUsed)
                  ? link.createdAt
                  : tagInfo[tag]!.lastUsed,
            );
          } else {
            tagInfo[tag] = TagInfo(
              name: tag,
              count: 1,
              lastUsed: link.createdAt,
              color: _generateTagColor(tag),
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _tags = tagInfo;
          _isLoading = false;
          _filterTags();
        });
      }
    } catch (e) {
      _showEnhancedSnackBar('Error loading tags: $e', type: SnackBarType.error);
      setState(() => _isLoading = false);
    }
  }

  void _filterTags() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredTags = _tags.keys.toList();
      } else {
        _filteredTags = _tags.keys
            .where((tag) => tag.toLowerCase().contains(query))
            .toList();
      }
      _sortTags();
    });
  }

  void _sortTags() {
    switch (_sortType) {
      case TagSortType.alphabetical:
        _filteredTags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        break;
      case TagSortType.count:
        _filteredTags.sort((a, b) => _tags[b]!.count.compareTo(_tags[a]!.count));
        break;
      case TagSortType.recent:
        _filteredTags.sort((a, b) => _tags[b]!.lastUsed.compareTo(_tags[a]!.lastUsed));
        break;
    }
  }

  Color _generateTagColor(String tag) {
    final colors = [
      Colors.blue[600]!,
      Colors.green[600]!,
      Colors.orange[600]!,
      Colors.purple[600]!,
      Colors.red[600]!,
      Colors.teal[600]!,
      Colors.indigo[600]!,
      Colors.pink[600]!,
      Colors.amber[600]!,
      Colors.cyan[600]!,
    ];
    return colors[tag.hashCode % colors.length];
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedTags.clear();
      }
    });

    if (_isSelectionMode) {
      _fabAnimationController.forward();
    } else {
      _fabAnimationController.reverse();
    }
  }

  void _toggleTagSelection(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }

      if (_selectedTags.isEmpty && _isSelectionMode) {
        _toggleSelectionMode();
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
        _searchAnimationController.reverse();
      } else {
        _searchAnimationController.forward();
      }
    });
  }

  Future<void> _renameTag(String oldTag, String newTag) async {
    if (newTag.isEmpty || oldTag == newTag || _tags.containsKey(newTag)) {
      if (_tags.containsKey(newTag)) {
        _showEnhancedSnackBar('Tag "$newTag" already exists', type: SnackBarType.warning);
      }
      return;
    }

    try {
      final links = await _dbHelper.getAllLinks();
      int updatedLinks = 0;

      for (var link in links) {
        if (link.tags.contains(oldTag)) {
          final newTags = link.tags.map((t) => t == oldTag ? newTag : t).toList();
          await _dbHelper.updateLink(link.copyWith(tags: newTags));
          updatedLinks++;
        }
      }

      await _loadTags();
      _showEnhancedSnackBar(
          'Renamed "$oldTag" to "$newTag" in $updatedLinks link(s)',
          type: SnackBarType.success
      );
    } catch (e) {
      _showEnhancedSnackBar('Error renaming tag: $e', type: SnackBarType.error);
    }
  }

  Future<void> _deleteTag(String tag) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle,
                color: Colors.red, size: 24),
            const SizedBox(width: 12),
            const Text('Delete Tag'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete the tag "$tag"?'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.info_circle, color: Colors.red.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will remove it from ${_tags[tag]?.count ?? 0} link(s)',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final links = await _dbHelper.getAllLinks();
        int updatedLinks = 0;

        for (var link in links) {
          if (link.tags.contains(tag)) {
            final newTags = List<String>.from(link.tags)..remove(tag);
            await _dbHelper.updateLink(link.copyWith(tags: newTags));
            updatedLinks++;
          }
        }

        await _loadTags();
        _showEnhancedSnackBar(
            'Deleted "$tag" from $updatedLinks link(s)',
            type: SnackBarType.success
        );
      } catch (e) {
        _showEnhancedSnackBar('Error deleting tag: $e', type: SnackBarType.error);
      }
    }
  }

  Future<void> _deleteTags(Set<String> tags) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle,
                color: Colors.red, size: 24),
            const SizedBox(width: 12),
            Text('Delete ${tags.length} Tag(s)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete ${tags.length} selected tag(s)?'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.info_circle, color: Colors.red.shade700, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'This action cannot be undone',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: tags.take(3).map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )).toList()
                      ..addAll(tags.length > 3 ? [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(
                            '... and ${tags.length - 3} more',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      ] : []),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final links = await _dbHelper.getAllLinks();
        int updatedLinks = 0;

        for (var link in links) {
          bool hasAnyTag = tags.any((tag) => link.tags.contains(tag));
          if (hasAnyTag) {
            final newTags = link.tags.where((tag) => !tags.contains(tag)).toList();
            await _dbHelper.updateLink(link.copyWith(tags: newTags));
            updatedLinks++;
          }
        }

        _selectedTags.clear();
        _toggleSelectionMode();
        await _loadTags();
        _showEnhancedSnackBar(
            'Deleted ${tags.length} tag(s) from $updatedLinks link(s)',
            type: SnackBarType.success
        );
      } catch (e) {
        _showEnhancedSnackBar('Error deleting tags: $e', type: SnackBarType.error);
      }
    }
  }

  void _showRenameDialog(String oldTag) {
    final controller = TextEditingController(text: oldTag);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  CupertinoIcons.pencil,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Rename Tag')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Tag name',
                  hintText: 'Enter new tag name',
                  prefixIcon: const Icon(CupertinoIcons.tag),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    _renameTag(oldTag, value.trim());
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.info_circle,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will update the tag in all ${_tags[oldTag]?.count ?? 0} associated link(s)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  _renameTag(oldTag, newName);
                  Navigator.pop(context);
                }
              },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
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

  Future<void> _viewTagLinks(String tagName) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TagLinksPage(tagName: tagName),
      ),
    );
  }

  Widget _buildTagListItem(String tagName, TagInfo tagInfo) {
    final isSelected = _selectedTags.contains(tagName);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleTagSelection(tagName);
        } else {
          _viewTagLinks(tagName);
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelectionMode();
        }
        _toggleTagSelection(tagName);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : null,
        ),
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Selection checkbox or tag icon
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
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surface,
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check,
                          size: 14,
                          color: theme.colorScheme.onPrimary)
                          : null,
                    ),
                  )
                else
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tagInfo.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      CupertinoIcons.tag_fill,
                      color: tagInfo.color,
                      size: 20,
                    ),
                  ),

                const SizedBox(width: 16),

                // Tag info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tagName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${tagInfo.count} link${tagInfo.count == 1 ? '' : 's'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Text(' • '),
                          Text(
                            _formatDate(tagInfo.lastUsed),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Menu button (when not in selection mode)
                if (!_isSelectionMode)
                  PopupMenuButton<String>(
                    icon: Icon(
                      CupertinoIcons.ellipsis,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.eye, size: 18),
                            const SizedBox(width: 8),
                            const Text('View Links'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.pencil, size: 18),
                            const SizedBox(width: 8),
                            const Text('Rename'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.trash, size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'view':
                          _viewTagLinks(tagName);
                          break;
                        case 'rename':
                          _showRenameDialog(tagName);
                          break;
                        case 'delete':
                          _deleteTag(tagName);
                          break;
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      return 'Today';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}m ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isSearchVisible
              ? TextField(
            key: const Key('search_field'),
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search tags...',
              border: InputBorder.none,
              hintStyle: TextStyle(fontSize: 16),
            ),
            style: const TextStyle(fontSize: 16),
          )
              : Text(
            _isSelectionMode
                ? '${_selectedTags.length} selected'
                : 'Manage Tags',
            key: const Key('title_text'),
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
          icon: const Icon(CupertinoIcons.xmark),
          onPressed: _toggleSelectionMode,
        )
            : null,
        actions: [
          if (!_isSelectionMode) ...[
            IconButton(
              onPressed: _toggleSearch,
              icon: Icon(_isSearchVisible ? CupertinoIcons.xmark : CupertinoIcons.search),
              style: IconButton.styleFrom(
                backgroundColor: _isSearchVisible
                    ? theme.colorScheme.errorContainer.withOpacity(0.3)
                    : theme.colorScheme.primaryContainer.withOpacity(0.3),
                padding: const EdgeInsets.all(12),
                minimumSize: const Size(44, 44),
              ),
            ),
            PopupMenuButton<TagSortType>(
              icon: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.sort_down, size: 20),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: TagSortType.alphabetical,
                  child: Row(
                    children: [
                      Icon(_sortType == TagSortType.alphabetical
                          ? CupertinoIcons.checkmark_alt
                          : CupertinoIcons.textformat_abc, size: 18),
                      const SizedBox(width: 8),
                      const Text('Alphabetical'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: TagSortType.count,
                  child: Row(
                    children: [
                      Icon(_sortType == TagSortType.count
                          ? CupertinoIcons.checkmark_alt
                          : CupertinoIcons.number, size: 18),
                      const SizedBox(width: 8),
                      const Text('By Count'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: TagSortType.recent,
                  child: Row(
                    children: [
                      Icon(_sortType == TagSortType.recent
                          ? CupertinoIcons.checkmark_alt
                          : CupertinoIcons.clock, size: 18),
                      const SizedBox(width: 8),
                      const Text('Recently Used'),
                    ],
                  ),
                ),
              ],
              onSelected: (sortType) {
                setState(() {
                  _sortType = sortType;
                  _sortTags();
                });
              },
            ),
          ],
          if (_isSelectionMode) ...[
            IconButton(
              onPressed: _selectedTags.isEmpty ? null : () {
                setState(() {
                  if (_selectedTags.length == _filteredTags.length) {
                    _selectedTags.clear();
                  } else {
                    _selectedTags.clear();
                    _selectedTags.addAll(_filteredTags);
                  }
                });
              },
              icon: Icon(_selectedTags.length == _filteredTags.length
                  ? CupertinoIcons.checkmark_square_fill
                  : CupertinoIcons.square),
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTags,
        child: Column(
          children: [
            // Statistics and info bar
            if (!_isSearchVisible && !_isSelectionMode)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.tag_fill,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_tags.length} Tag${_tags.length == 1 ? '' : 's'} Total',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _filteredTags.length != _tags.length
                                ? 'Showing ${_filteredTags.length} filtered'
                                : 'Tap a tag to view its links',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_tags.isNotEmpty)
                      IconButton(
                        onPressed: _toggleSelectionMode,
                        icon: const Icon(CupertinoIcons.selection_pin_in_out),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                          foregroundColor: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _tags.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.tags,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Tags Found',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add tags to your links to see them here.\nTags help organize and find your links easily.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : _filteredTags.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.search,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Tags Found',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try adjusting your search terms',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                itemCount: _filteredTags.length,
                itemBuilder: (context, index) {
                  final tagName = _filteredTags[index];
                  final tagInfo = _tags[tagName]!;
                  return _buildTagListItem(tagName, tagInfo);
                },
              )
            ),
          ],
        ),
      ),
      floatingActionButton: _isSelectionMode && _selectedTags.isNotEmpty
          ? Padding(
        padding: const EdgeInsets.only(bottom: 100.0),
        child: FloatingActionButton.extended(
          heroTag: 'delete_tags',
          onPressed: () => _deleteTags(_selectedTags),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          icon: const Icon(CupertinoIcons.trash),
          label: Text('Delete ${_selectedTags.length}'),
        ),
      )
          : null,
    );
  }
}

// Supporting classes and enums
class TagInfo {
  final String name;
  final int count;
  final DateTime lastUsed;
  final Color color;

  TagInfo({
    required this.name,
    required this.count,
    required this.lastUsed,
    required this.color,
  });

  TagInfo copyWith({
    String? name,
    int? count,
    DateTime? lastUsed,
    Color? color,
  }) {
    return TagInfo(
      name: name ?? this.name,
      count: count ?? this.count,
      lastUsed: lastUsed ?? this.lastUsed,
      color: color ?? this.color,
    );
  }
}

enum TagSortType {
  alphabetical,
  count,
  recent,
}

// Tag Links Page to show all links with a specific tag
class TagLinksPage extends StatefulWidget {
  final String tagName;

  const TagLinksPage({super.key, required this.tagName});

  @override
  _TagLinksPageState createState() => _TagLinksPageState();
}

class _TagLinksPageState extends State<TagLinksPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<LinkModel> _links = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    setState(() => _isLoading = true);
    try {
      final allLinks = await _dbHelper.getAllLinks();
      final tagLinks = allLinks.where((link) => link.tags.contains(widget.tagName)).toList();

      if (mounted) {
        setState(() {
          _links = tagLinks;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.tagName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '${_links.length} link${_links.length == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _links.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.link,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Links Found',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'No links found with the tag "${widget.tagName}"',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _links.length,
        itemBuilder: (context, index) {
          final link = _links[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  CupertinoIcons.link,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                link.title ?? link.domain,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    link.domain,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (link.tags.length > 1) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: link.tags
                          .where((tag) => tag != widget.tagName)
                          .take(3)
                          .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ))
                          .toList(),
                    ),
                  ],
                ],
              ),
              trailing: const Icon(CupertinoIcons.chevron_forward),
              onTap: () {
                // Navigate to link details or open link
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LinkDetailsPage(link: link),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'folder_links_page.dart';
import '../models/link_model.dart';
import '../services/database_helper.dart';

class LinksFoldersPage extends StatefulWidget {
  final VoidCallback? onRefresh;

  const LinksFoldersPage({super.key, this.onRefresh});

  @override
  LinksFoldersPageState createState() => LinksFoldersPageState();
}

class LinksFoldersPageState extends State<LinksFoldersPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, List<LinkModel>> _folders = {};
  bool _isGridView = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    loadFolders();
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
      setState(() => _folders = folders);
      print('Loaded folders: ${folders.keys.toList()}');
    } catch (e) {
      _showSnackBar('Error loading folders: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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
      'facebook.com': 'Facebook',
      'linkedin.com': 'LinkedIn',
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
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildFolderCard(String folderName) {
    final links = _folders[folderName]!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FolderLinksPage(
                folderName: folderName,
                links: links,
              ),
            ),
          ).then((_) {
            // Reload folders when returning to ensure updates (e.g., deletions) are reflected
            loadFolders();
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: CachedNetworkImage(
                  imageUrl: _getFaviconUrl(links.first.domain),
                  placeholder: (context, url) => const Icon(Icons.folder, color: Colors.grey),
                  errorWidget: (context, url, error) => const Icon(Icons.folder, color: Colors.grey),
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folderName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${links.length} link${links.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Link Folders',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                  tooltip: _isGridView ? 'List view' : 'Grid view',
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _folders.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_off, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No folders found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Add links to organize them by domain',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: loadFolders,
              child: _isGridView
                  ? GridView.builder(
                padding: const EdgeInsets.only(bottom: 80.0, top: 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _folders.keys.length,
                itemBuilder: (context, index) {
                  final folderName = _folders.keys.elementAt(index);
                  return _buildFolderCard(folderName);
                },
              )
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 80.0, top: 8),
                itemCount: _folders.keys.length,
                itemBuilder: (context, index) {
                  final folderName = _folders.keys.elementAt(index);
                  return _buildFolderCard(folderName);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
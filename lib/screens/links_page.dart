import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for clipboard
import 'package:url_launcher/url_launcher.dart';
import '../models/link_model.dart';
import '../services/database_helper.dart';
import 'package:share_plus/share_plus.dart';

class LinksPage extends StatefulWidget {
  final VoidCallback? onRefresh;

  const LinksPage({super.key, this.onRefresh});

  @override
  LinksPageState createState() => LinksPageState();
}

class LinksPageState extends State<LinksPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<LinkModel> _links = [];
  bool _isGridView = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    loadLinks();
  }

  Future<void> loadLinks() async {
    setState(() => _isLoading = true);
    try {
      final links = await _dbHelper.getAllLinks();
      print('Loaded links: ${links.map((link) => link.url).toList()}'); // Debug log
      setState(() => _links = links);
    } catch (e) {
      _showSnackBar('Error loading links: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteLink(LinkModel link) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Link'),
        content: Text('Are you sure you want to delete this link?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirm == true && link.id != null) {
      final deletedLink = link; // Store link for undo
      await _dbHelper.deleteLink(link.id!);
      await loadLinks();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await _dbHelper.insertLink(deletedLink);
              await loadLinks();
            },
          ),
        ),
      );
    }
  }

  Future<void> _openLink(String url) async {
    try {
      print('Attempting to open URL: $url'); // Debug log
      String formattedUrl = url.trim();
      if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
        formattedUrl = 'https://$formattedUrl';
      }

      final uri = Uri.tryParse(formattedUrl);
      if (uri == null || !uri.hasScheme) {
        _showSnackBar('Invalid URL: $formattedUrl');
        print('Invalid URL parsed: $formattedUrl'); // Debug log
        return;
      }

      print('Parsed URI: $uri'); // Debug log
      // Attempt to open in default browser
      if (await canLaunchUrl(uri)) {
        print('Launching URL in default browser: $uri'); // Debug log
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        print('Cannot launch URL in browser, trying fallback: $uri'); // Debug log
        // Fallback: Try opening with a generic intent
        final fallbackUri = Uri.parse('https://www.google.com');
        if (await canLaunchUrl(fallbackUri)) {
          print('Launching fallback URL: $fallbackUri'); // Debug log
          await launchUrl(fallbackUri, mode: LaunchMode.platformDefault);
          _showSnackBar('No browser found for $formattedUrl, opened fallback');
        } else {
          _showSnackBar('No browser installed to open: $formattedUrl');
          print('No browser available for URL: $uri'); // Debug log
        }
      }
    } catch (e) {
      _showSnackBar('Error opening URL: $e');
      print('Error opening URL: $e'); // Debug log
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

  void _showLinkOptionsMenu(BuildContext context, LinkModel link) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.open_in_new),
                title: Text('Open Link'),
                onTap: () {
                  Navigator.pop(context);
                  _openLink(link.url);
                },
              ),
              ListTile(
                leading: Icon(Icons.copy),
                title: Text('Copy URL'),
                onTap: () {
                  Navigator.pop(context);
                  _copyUrl(link.url);
                },
              ),
              ListTile(
                leading: Icon(Icons.share),
                title: Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  _shareLink(link.url, link.title);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteLink(link);
                },
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildLinkItem(LinkModel link) {
    return Card(
      margin: EdgeInsets.all(8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openLink(link.url),
        onLongPress: () {
          _showLinkOptionsMenu(context, link);
        },
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
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min, // Allow dynamic sizing
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    child: Container(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxWidth * 0.75, // Minimum height for consistency
                        maxHeight: constraints.maxWidth * 0.95, // Allow taller images
                      ),
                      color: Colors.grey[200],
                      child: link.imageUrl.isNotEmpty
                          ? Image.network(
                        link.imageUrl,
                        fit: BoxFit.cover, // Use cover to crop landscape images
                        width: constraints.maxWidth,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(Icons.link, size: 40, color: Colors.grey[600]),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      )
                          : Center(
                        child: Icon(Icons.link, size: 40, color: Colors.grey[600]),
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
                        icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[800]),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteLink(link);
                          } else if (value == 'copy') {
                            _copyUrl(link.url);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
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
                padding: EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        link.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      link.domain,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 80,
            margin: EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: link.imageUrl.isNotEmpty
                  ? Image.network(
                link.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(Icons.link, color: Colors.grey[600]),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              )
                  : Center(
                child: Icon(Icons.link, color: Colors.grey[600]),
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                if (link.description.isNotEmpty)
                  Text(
                    link.description,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                SizedBox(height: 4),
                Text(
                  link.domain,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _deleteLink(link),
          ),
        ],
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
                  'Saved Links',
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
                ? Center(child: CircularProgressIndicator())
                : _links.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_off, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No links saved yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Add links manually or share them from other apps',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: loadLinks,
              child: _isGridView
                  ? Padding(
                padding: EdgeInsets.all(8),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _links.length,
                  itemBuilder: (context, index) => _buildLinkItem(_links[index]),
                ),
              )
                  : ListView.builder(
                padding: EdgeInsets.only(bottom: 80.0, top: 8),
                itemCount: _links.length,
                itemBuilder: (context, index) => _buildLinkItem(_links[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
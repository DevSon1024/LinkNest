import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/link_model.dart';

class TagsPage extends StatefulWidget {
  const TagsPage({super.key});

  @override
  _TagsPageState createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, int> _tags = {};

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final links = await _dbHelper.getAllLinks();
    final tagCounts = <String, int>{};
    for (var link in links) {
      for (var tag in link.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    setState(() {
      _tags = tagCounts;
    });
  }

  Future<void> _renameTag(String oldTag, String newTag) async {
    if (newTag.isEmpty || oldTag == newTag) return;

    final links = await _dbHelper.getAllLinks();
    for (var link in links) {
      if (link.tags.contains(oldTag)) {
        final newTags = link.tags.map((t) => t == oldTag ? newTag : t).toList();
        await _dbHelper.updateLink(link.copyWith(tags: newTags));
      }
    }
    _loadTags();
  }

  Future<void> _deleteTag(String tag) async {
    final links = await _dbHelper.getAllLinks();
    for (var link in links) {
      if (link.tags.contains(tag)) {
        final newTags = link.tags..remove(tag);
        await _dbHelper.updateLink(link.copyWith(tags: newTags));
      }
    }
    _loadTags();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Tags'),
      ),
      body: ListView.builder(
        itemCount: _tags.length,
        itemBuilder: (context, index) {
          final tagName = _tags.keys.elementAt(index);
          final count = _tags[tagName];
          return ListTile(
            title: Text(tagName),
            subtitle: Text('$count links'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showRenameDialog(tagName),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteTag(tagName),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showRenameDialog(String oldTag) {
    final controller = TextEditingController(text: oldTag);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Tag'),
          content: TextField(controller: controller),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _renameTag(oldTag, controller.text);
                Navigator.pop(context);
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }
}
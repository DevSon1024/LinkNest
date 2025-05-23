import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/metadata_service.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onLinkAdded;

  const HomeScreen({super.key, this.onLinkAdded});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // In home_screen.dart, ensure the method is accessible from outside:

  void showAddLinkDialog(BuildContext context) {
    _urlController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Link'),
        content: TextField(
          controller: _urlController,
          decoration: InputDecoration(
            hintText: 'Enter URL',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (_urlController.text.isNotEmpty) {
                addLinkFromUrl(_urlController.text);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> addLinkFromUrl(String url) async {
    if (await _dbHelper.linkExists(url)) {
      _showSnackBar('Link already exists');
      return;
    }

    try {
      final linkModel = await MetadataService.extractMetadata(url);
      if (linkModel != null) {
        await _dbHelper.insertLink(linkModel);
        widget.onLinkAdded?.call();
        _showSnackBar('Link saved successfully');
      } else {
        _showSnackBar('Failed to extract link information');
      }
    } catch (e) {
      _showSnackBar('Error saving link: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Welcome to the Link Saver',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
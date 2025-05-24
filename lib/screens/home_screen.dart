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

  Future<void> addLinkFromUrl(String url) async {
    if (await _dbHelper.linkExists(url)) {
      if (mounted) _showSnackBar('Link already exists');
      return;
    }

    try {
      final linkModel = await MetadataService.extractMetadata(url);
      if (linkModel != null) {
        await _dbHelper.insertLink(linkModel);
        widget.onLinkAdded?.call();
        if (mounted) _showSnackBar('Link saved successfully');
      } else {
        if (mounted) _showSnackBar('Failed to extract link information');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error saving link: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
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
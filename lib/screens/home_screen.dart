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

  Future<bool> addLinkFromUrl(String url) async {
    print('HomeScreen: Adding link from URL: $url'); // Debug log

    if (await _dbHelper.linkExists(url)) {
      print('HomeScreen: Link already exists: $url'); // Debug log
      // Don't show snackbar here - let the caller decide
      return false; // Return false to indicate link already exists
    }

    try {
      print('HomeScreen: Extracting metadata for: $url'); // Debug log
      final linkModel = await MetadataService.extractMetadata(url);

      if (linkModel != null) {
        print('HomeScreen: Metadata extracted, inserting link: ${linkModel.title}'); // Debug log
        await _dbHelper.insertLink(linkModel);
        widget.onLinkAdded?.call();
        // Don't show snackbar here - let the caller handle success message
        return true;
      } else {
        print('HomeScreen: Failed to extract metadata for: $url'); // Debug log
        // Don't show snackbar here - let the caller handle error
        return false;
      }
    } catch (e) {
      print('HomeScreen: Error saving link: $e'); // Debug log
      // Don't show snackbar here - let the caller handle error
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link,
              size: 80,
              color: Theme.of(context).primaryColor.withOpacity(0.7),
            ),
            SizedBox(height: 20),
            Text(
              'Welcome to LinkNest',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Share links from your browser or other apps to save them here',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Links will be automatically saved when shared to LinkNest',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 30),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 40),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap the + button below to add links manually',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
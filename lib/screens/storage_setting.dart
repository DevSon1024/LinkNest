import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/database_helper.dart';
import '../services/metadata_service.dart';
import 'permission_page.dart';

class StorageSetting extends StatefulWidget {
  const StorageSetting({super.key});

  @override
  StorageSettingState createState() => StorageSettingState();
}

class StorageSettingState extends State<StorageSetting> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _hasStoragePermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    final status = await Permission.storage.status;
    final manageStatus = await Permission.manageExternalStorage.status;
    setState(() {
      _hasStoragePermission = status.isGranted || manageStatus.isGranted;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _exportData() async {
    if (!_hasStoragePermission) {
      final granted = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PermissionPage(action: 'export'),
        ),
      );
      if (granted != true) {
        _showSnackBar('Permission denied for export');
        return;
      }
      await _checkPermissionStatus();
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Fetch links from database
      final links = await _dbHelper.getAllLinks();
      if (links.isEmpty) {
        Navigator.of(context).pop(); // Close loading dialog
        _showSnackBar('No links to export');
        return;
      }

      // Create JSON data with proper structure
      final exportData = {
        'version': '1.0',
        'exported_at': DateTime.now().toIso8601String(),
        'links': links.map((link) => {
          'url': link.url,
          'notes': link.notes ?? '',
          'title': link.title ?? '',
          'description': link.description ?? '',
          'imageUrl': link.imageUrl ?? '',
          'created_at': link.createdAt?.toIso8601String(),
        }).toList(),
      };

      final jsonString = jsonEncode(exportData);

      // Debug: Print JSON length to verify content
      print('JSON data length: ${jsonString.length}');
      print('Number of links: ${links.length}');

      // Get user-selected output directory
      final outputDir = await FilePicker.platform.getDirectoryPath();
      if (outputDir == null) {
        Navigator.of(context).pop(); // Close loading dialog
        _showSnackBar('No directory selected');
        return;
      }

      // Create temporary directory for files
      final tempDir = await getTemporaryDirectory();
      final tempJsonFile = File('${tempDir.path}/links_backup.json');

      // Write JSON to temporary file
      await tempJsonFile.writeAsString(jsonString, flush: true);

      // Verify the JSON file was created and has content
      if (!await tempJsonFile.exists()) {
        Navigator.of(context).pop();
        _showSnackBar('Failed to create temporary JSON file');
        return;
      }

      final fileSize = await tempJsonFile.length();
      print('Temporary JSON file size: $fileSize bytes');

      if (fileSize == 0) {
        Navigator.of(context).pop();
        _showSnackBar('JSON file is empty');
        await tempJsonFile.delete();
        return;
      }

      // Create ZIP file using Archive library
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final zipFilePath = '$outputDir/links_backup_$timestamp.zip';

      // Read the JSON file content
      final jsonBytes = await tempJsonFile.readAsBytes();

      // Create archive and add the JSON file
      final archive = Archive();
      final archiveFile = ArchiveFile('links_backup.json', jsonBytes.length, jsonBytes);
      archive.addFile(archiveFile);

      // Encode archive to ZIP
      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) {
        Navigator.of(context).pop();
        _showSnackBar('Failed to create ZIP archive');
        await tempJsonFile.delete();
        return;
      }

      // Write ZIP file
      final zipFile = File(zipFilePath);
      await zipFile.writeAsBytes(zipData);

      // Verify ZIP file was created
      if (!await zipFile.exists()) {
        Navigator.of(context).pop();
        _showSnackBar('Failed to create ZIP file');
        await tempJsonFile.delete();
        return;
      }

      final zipSize = await zipFile.length();
      print('ZIP file size: $zipSize bytes');

      // Clean up temporary file
      await tempJsonFile.delete();

      Navigator.of(context).pop(); // Close loading dialog
      _showSnackBar('Data exported successfully to $zipFilePath');

    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog if still open
      print('Export error: $e');
      _showSnackBar('Error exporting data: $e');
    }
  }

  Future<void> _importData() async {
    if (!_hasStoragePermission) {
      final granted = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PermissionPage(action: 'import'),
        ),
      );
      if (granted != true) {
        _showSnackBar('Permission denied for import');
        return;
      }
      await _checkPermissionStatus();
    }

    try {
      // Show file picker
      final result = await FilePicker.platform.pickFiles(
        allowedExtensions: ['zip'],
        type: FileType.custom,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        _showSnackBar('No file selected');
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final zipFile = File(result.files.single.path!);
      if (!await zipFile.exists()) {
        Navigator.of(context).pop();
        _showSnackBar('Selected file does not exist');
        return;
      }

      // Read and decode ZIP file
      final bytes = await zipFile.readAsBytes();
      print('ZIP file size: ${bytes.length} bytes');

      final archive = ZipDecoder().decodeBytes(bytes);
      print('Archive files: ${archive.files.map((f) => f.name).toList()}');

      // Find the JSON file in the archive
      final jsonArchiveFile = archive.findFile('links_backup.json');
      if (jsonArchiveFile == null) {
        Navigator.of(context).pop();
        _showSnackBar('Invalid backup file: No links_backup.json found');
        return;
      }

      // Extract JSON content
      final jsonContent = jsonArchiveFile.content;
      if (jsonContent == null || jsonContent.isEmpty) {
        Navigator.of(context).pop();
        _showSnackBar('JSON file in backup is empty');
        return;
      }

      final jsonString = utf8.decode(jsonContent as List<int>);
      print('JSON content length: ${jsonString.length}');

      if (jsonString.trim().isEmpty) {
        Navigator.of(context).pop();
        _showSnackBar('JSON file contains no data');
        return;
      }

      // Parse JSON data
      final Map<String, dynamic> backupData = jsonDecode(jsonString);
      final List<dynamic> linksData = backupData['links'] ?? [];

      if (linksData.isEmpty) {
        Navigator.of(context).pop();
        _showSnackBar('No links found in backup file');
        return;
      }

      // Import links
      int importedCount = 0;
      int updatedCount = 0;

      for (var linkData in linksData) {
        try {
          final map = Map<String, dynamic>.from(linkData);
          final url = map['url'] as String?;

          if (url == null || url.isEmpty) {
            continue;
          }

          final notes = map['notes'] as String?;
          final title = map['title'] as String?;
          final description = map['description'] as String?;
          final imageUrl = map['imageUrl'] as String?;

          // Check if link already exists
          if (await _dbHelper.linkExists(url)) {
            // Update existing link if it has notes or other data
            final existingLinks = await _dbHelper.getAllLinks();
            final existingLink = existingLinks.firstWhere((link) => link.url == url);

            if ((notes != null && notes.isNotEmpty) ||
                (title != null && title.isNotEmpty) ||
                (description != null && description.isNotEmpty) ||
                (imageUrl != null && imageUrl.isNotEmpty)) {
              await _dbHelper.updateLink(existingLink.copyWith(
                notes: notes,
                title: title ?? existingLink.title,
                description: description ?? existingLink.description,
                imageUrl: imageUrl ?? existingLink.imageUrl,
              ));
              updatedCount++;
            }
          } else {
            // Create new link
            try {
              final metadata = await MetadataService.extractMetadata(url);
              if (metadata != null) {
                await _dbHelper.insertLink(metadata.copyWith(
                  notes: notes,
                  title: title ?? metadata.title,
                  description: description ?? metadata.description,
                  imageUrl: imageUrl ?? metadata.imageUrl,
                ));
                importedCount++;
              }
            } catch (metadataError) {
              print('Error extracting metadata for $url: $metadataError');
              // Continue with next link
            }
          }
        } catch (linkError) {
          print('Error processing link: $linkError');
          // Continue with next link
        }
      }

      Navigator.of(context).pop(); // Close loading dialog
      _showSnackBar('Import completed: $importedCount new links, $updatedCount updated');

    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog if still open
      print('Import error: $e');
      _showSnackBar('Error importing data: $e');
    }
  }

  Future<void> _clearCache() async {
    try {
      await DefaultCacheManager().emptyCache();
      imageCache.clear();
      imageCache.clearLiveImages();

      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        await tempDir.create(recursive: true);
      }

      _showSnackBar('Cache cleared successfully');
    } catch (e) {
      _showSnackBar('Error clearing cache: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Storage Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              _hasStoragePermission ? Icons.check_circle : Icons.warning,
              color: _hasStoragePermission ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backup & Restore',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _exportData,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Export Data'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _importData,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Import Data'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearCache,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear Cache'),
            ),
          ],
        ),
      ),
    );
  }
}
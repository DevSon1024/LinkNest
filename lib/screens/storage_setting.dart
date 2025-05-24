import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import '../services/database_helper.dart';
import '../models/link_model.dart';
import 'permission_page.dart';

class StorageSetting extends StatefulWidget {
  const StorageSetting({super.key});

  @override
  StorageSettingState createState() => StorageSettingState();
}

class StorageSettingState extends State<StorageSetting> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _exportData() async {
    // Request permission
    final hasPermission = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PermissionPage(action: 'export'),
      ),
    );

    if (hasPermission != true) {
      _showSnackBar('Permission denied for export');
      return;
    }

    try {
      // Get all links from database
      final links = await _dbHelper.getAllLinks();
      final linksJson = jsonEncode(links.map((link) => link.toMap()).toList());

      // Create temporary JSON file
      final tempDir = await getTemporaryDirectory();
      final jsonFile = File('${tempDir.path}/links_backup.json');
      await jsonFile.writeAsString(linksJson);

      // Create ZIP archive
      final archive = Archive();
      archive.addFile(ArchiveFile(
        'links_backup.json',
        jsonFile.lengthSync(),
        await jsonFile.readAsBytes(),
      ));

      // Pick directory for saving ZIP
      final outputDir = await FilePicker.platform.getDirectoryPath();
      if (outputDir == null) {
        _showSnackBar('No directory selected');
        await jsonFile.delete();
        return;
      }

      final zipFile = File('$outputDir/links_backup_${DateTime.now().millisecondsSinceEpoch}.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFile(jsonFile);
      encoder.close();

      // Clean up
      await jsonFile.delete();
      _showSnackBar('Data exported successfully to $outputDir');
    } catch (e) {
      _showSnackBar('Error exporting data: $e');
    }
  }

  Future<void> _importData() async {
    // Request permission
    final hasPermission = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PermissionPage(action: 'import'),
      ),
    );

    if (hasPermission != true) {
      _showSnackBar('Permission denied for import');
      return;
    }

    try {
      // Pick ZIP file
      final result = await FilePicker.platform.pickFiles(
        allowedExtensions: ['zip'],
        type: FileType.custom,
      );
      if (result == null || result.files.isEmpty) {
        _showSnackBar('No file selected');
        return;
      }

      final zipFile = File(result.files.single.path!);
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Extract JSON file from ZIP
      final jsonFile = archive.findFile('links_backup.json');
      if (jsonFile == null) {
        _showSnackBar('Invalid ZIP file: No links_backup.json found');
        return;
      }

      // Parse JSON and import to database
      final jsonData = utf8.decode(jsonFile.content as List<int>);
      final List<dynamic> linksData = jsonDecode(jsonData);
      for (var linkData in linksData) {
        final link = LinkModel.fromMap(Map<String, dynamic>.from(linkData));
        await _dbHelper.insertLink(link.copyWith(id: null)); // Avoid ID conflicts
      }

      _showSnackBar('Data imported successfully');
    } catch (e) {
      _showSnackBar('Error importing data: $e');
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
          ],
        ),
      ),
    );
  }
}
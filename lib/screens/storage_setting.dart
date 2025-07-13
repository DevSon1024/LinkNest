import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // Added for Uint8List
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';
import 'permission_page.dart';
import '../models/link_model.dart';

class StorageSetting extends StatefulWidget {
  const StorageSetting({super.key});

  @override
  StorageSettingState createState() => StorageSettingState();
}

class StorageSettingState extends State<StorageSetting> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _hasStoragePermission = true; // Default to true for Android 13+

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    // Only check for Android 12 (API 32) and below
    if (Platform.isAndroid && await _getAndroidVersion() <= 32) {
      final status = await Permission.storage.status;
      setState(() {
        _hasStoragePermission = status.isGranted;
      });
    } else {
      setState(() {
        _hasStoragePermission = true; // No permission needed for Android 13+
      });
    }
  }

  Future<int> _getAndroidVersion() async {
    // Placeholder: Use device_info_plus in production
    return 33; // Assume Android 13+ for simplicity
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
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
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final links = await _dbHelper.getAllLinks();
      if (links.isEmpty) {
        Navigator.of(context).pop();
        _showSnackBar('No links to export');
        return;
      }

      final exportData = {
        'version': '1.0',
        'exported_at': DateTime.now().toIso8601String(),
        'links': links.map((link) => {
          'url': link.url,
          'notes': link.notes,
          'title': link.title,
          'description': link.description,
          'imageUrl': link.imageUrl,
          'created_at': link.createdAt.toIso8601String(),
        }).toList(),
      };

      final jsonString = jsonEncode(exportData);
      print('JSON data length: ${jsonString.length}');
      print('Number of links: ${links.length}');

      // Create temporary JSON file
      final tempDir = await getTemporaryDirectory();
      final tempJsonFile = File('${tempDir.path}/links_backup.json');
      await tempJsonFile.writeAsString(jsonString, flush: true);

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

      // Create ZIP archive
      final jsonBytes = await tempJsonFile.readAsBytes();
      final archive = Archive();
      final archiveFile = ArchiveFile('links_backup.json', jsonBytes.length, jsonBytes);
      archive.addFile(archiveFile);

      final zipData = ZipEncoder().encode(archive);
      await tempJsonFile.delete();

      // Use SAF to save the ZIP file
      final fileName = 'links_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup File',
        fileName: fileName,
        bytes: Uint8List.fromList(zipData), // Convert List<int> to Uint8List
        allowedExtensions: ['zip'],
        type: FileType.custom,
      );

      if (result == null) {
        Navigator.of(context).pop();
        _showSnackBar('No file location selected');
        return;
      }

      // For verification, check if the file was created
      final zipFile = File(result);
      if (!await zipFile.exists()) {
        Navigator.of(context).pop();
        _showSnackBar('Failed to verify ZIP file creation');
        return;
      }

      final zipSize = await zipFile.length();
      print('ZIP file size: $zipSize bytes');

      Navigator.of(context).pop();
      _showSnackBar('Data exported successfully to $result');
    } catch (e) {
      Navigator.of(context).pop();
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
      final result = await FilePicker.platform.pickFiles(
        allowedExtensions: ['zip'],
        type: FileType.custom,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        _showSnackBar('No file selected');
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final zipFilePath = result.files.single.path!;
      final zipFile = File(zipFilePath);
      if (!await zipFile.exists()) {
        Navigator.of(context).pop();
        _showSnackBar('Selected file does not exist');
        return;
      }

      final bytes = await zipFile.readAsBytes();
      print('ZIP file size: ${bytes.length} bytes');

      final archive = ZipDecoder().decodeBytes(bytes);
      print('Archive files: ${archive.files.map((f) => f.name).toList()}');

      final jsonArchiveFile = archive.findFile('links_backup.json');
      if (jsonArchiveFile == null) {
        Navigator.of(context).pop();
        _showSnackBar('Invalid backup file: No links_backup.json found');
        return;
      }

      final jsonContent = jsonArchiveFile.content;
      if (jsonContent.isEmpty) {
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

      final Map<String, dynamic> backupData = jsonDecode(jsonString);
      final List<dynamic> linksData = backupData['links'] ?? [];

      if (linksData.isEmpty) {
        Navigator.of(context).pop();
        _showSnackBar('No links found in backup file');
        return;
      }

      final db = await _dbHelper.database;
      final batch = db.batch();
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
          final title = map['title'] as String? ?? 'Untitled';
          final description = map['description'] as String? ?? '';
          final imageUrl = map['imageUrl'] as String? ?? '';
          final createdAt = map['created_at'] != null
              ? DateTime.parse(map['created_at'])
              : DateTime.now();

          final uri = Uri.tryParse(url);
          final domain = uri?.host ?? '';

          final linkModel = LinkModel(
            url: url,
            title: title,
            description: description,
            imageUrl: imageUrl,
            createdAt: createdAt,
            domain: domain,
            tags: [],
            notes: notes,
          );

          if (await _dbHelper.linkExists(url)) {
            final existingLinks = await _dbHelper.getAllLinks();
            final existingLink = existingLinks.firstWhere((link) => link.url == url);
            if ((notes != null && notes.isNotEmpty) ||
                (title.isNotEmpty && title != 'Untitled') ||
                (imageUrl.isNotEmpty)) {
              batch.update(
                'links',
                linkModel.toMap(),
                where: 'id = ?',
                whereArgs: [existingLink.id],
              );
              updatedCount++;
            }
          } else {
            batch.insert('links', linkModel.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
            importedCount++;
          }
        } catch (linkError) {
          print('Error processing link: $linkError');
        }
      }

      await batch.commit(noResult: true);
      Navigator.of(context).pop();
      _showSnackBar('Import completed: $importedCount new links, $updatedCount updated');
    } catch (e) {
      Navigator.of(context).pop();
      print('Import error: $e');
      _showSnackBar('Error exporting data: $e');
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

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color backgroundColor,
    Color? iconColor,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: backgroundColor.withOpacity(0.1),
                child: Icon(
                  icon,
                  color: iconColor ?? backgroundColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      appBar: AppBar(
        title: const Text(
          'Storage Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
        elevation: 2,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              _hasStoragePermission ? Icons.check_circle_rounded : Icons.warning_rounded,
              color: _hasStoragePermission
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (!_hasStoragePermission)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Storage permission required for backup/restore operations on older Android versions',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_hasStoragePermission) const SizedBox(height: 16),
            _buildActionCard(
              icon: Icons.backup_rounded,
              title: 'Export Data',
              subtitle: 'Create a backup of all your saved links',
              onTap: _exportData,
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              icon: Icons.restore_rounded,
              title: 'Import Data',
              subtitle: 'Restore links from a backup file',
              onTap: _importData,
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              icon: Icons.cleaning_services_rounded,
              title: 'Clear Cache',
              subtitle: 'Free up storage space by clearing cached data',
              onTap: _clearCache,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }
}
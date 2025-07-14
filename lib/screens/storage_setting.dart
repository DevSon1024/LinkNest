import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:device_info_plus/device_info_plus.dart';
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
  bool _hasStoragePermission = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    try {
      // Check Android version using device_info_plus
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final sdkInt = androidInfo.version.sdkInt;

        // Only check storage permission for Android 12 (API 31) and below
        if (sdkInt <= 31) {
          final status = await Permission.storage.status;
          setState(() {
            _hasStoragePermission = status.isGranted;
          });
        } else {
          // Android 13+ doesn't need storage permission for SAF
          setState(() {
            _hasStoragePermission = true;
          });
        }
      } else {
        setState(() {
          _hasStoragePermission = true;
        });
      }
    } catch (e) {
      print('Error checking permission status: $e');
      // Default to true if we can't determine the version
      setState(() {
        _hasStoragePermission = true;
      });
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _exportData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Check permissions if needed
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

      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Exporting data...'),
              ],
            ),
          ),
        );
      }

      // Get all links from database
      final links = await _dbHelper.getAllLinks();
      if (links.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        _showSnackBar('No links to export');
        return;
      }

      // Create export data structure
      final exportData = {
        'version': '1.0',
        'exported_at': DateTime.now().toIso8601String(),
        'app_name': 'LinkNest',
        'total_links': links.length,
        'links': links.map((link) => {
          'url': link.url,
          'title': link.title,
          'description': link.description,
          'imageUrl': link.imageUrl,
          'domain': link.domain,
          'tags': link.tags,
          'notes': link.notes,
          'created_at': link.createdAt.toIso8601String(),
        }).toList(),
      };

      // Convert to JSON string
      final jsonString = jsonEncode(exportData);
      print('Export data prepared - Links: ${links.length}, JSON size: ${jsonString.length} bytes');

      // Create temporary directory and file
      final tempDir = await getTemporaryDirectory();
      final tempJsonFile = File('${tempDir.path}/links_backup_${DateTime.now().millisecondsSinceEpoch}.json');

      // Write JSON to temporary file
      await tempJsonFile.writeAsString(jsonString, flush: true);

      // Verify file was created
      if (!await tempJsonFile.exists()) {
        if (mounted) Navigator.of(context).pop();
        _showSnackBar('Failed to create backup file');
        return;
      }

      final fileSize = await tempJsonFile.length();
      if (fileSize == 0) {
        if (mounted) Navigator.of(context).pop();
        _showSnackBar('Backup file is empty');
        await tempJsonFile.delete();
        return;
      }

      // Create ZIP archive
      final jsonBytes = await tempJsonFile.readAsBytes();
      final archive = Archive();

      // Add JSON file to archive
      final archiveFile = ArchiveFile(
        'links_backup.json',
        jsonBytes.length,
        jsonBytes,
      );
      archive.addFile(archiveFile);

      // Encode archive to ZIP
      final zipData = ZipEncoder().encode(archive);

      // Clean up temporary file
      await tempJsonFile.delete();

      if (zipData == null || zipData.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        _showSnackBar('Failed to create ZIP archive');
        return;
      }

      // Generate filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'linknest_backup_$timestamp.zip';

      // Use Storage Access Framework to save file
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save LinkNest Backup',
        fileName: fileName,
        bytes: Uint8List.fromList(zipData),
        allowedExtensions: ['zip'],
        type: FileType.custom,
      );

      if (mounted) Navigator.of(context).pop();

      if (result == null) {
        _showSnackBar('Export cancelled');
        return;
      }

      // Show success message
      _showSnackBar('Backup exported successfully!\nFile: $fileName');
      print('Export completed successfully: $result');

    } catch (e, stackTrace) {
      if (mounted) Navigator.of(context).pop();
      print('Export error: $e');
      print('Stack trace: $stackTrace');
      _showSnackBar('Export failed: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _importData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Check permissions if needed
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

      // Pick file
      final result = await FilePicker.platform.pickFiles(
        allowedExtensions: ['zip'],
        type: FileType.custom,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        _showSnackBar('No file selected');
        return;
      }

      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Importing data...'),
              ],
            ),
          ),
        );
      }

      final pickedFile = result.files.single;
      List<int> bytes;

      // Read file bytes
      if (pickedFile.bytes != null) {
        bytes = pickedFile.bytes!;
      } else if (pickedFile.path != null) {
        final file = File(pickedFile.path!);
        if (!await file.exists()) {
          if (mounted) Navigator.of(context).pop();
          _showSnackBar('Selected file does not exist');
          return;
        }
        bytes = await file.readAsBytes();
      } else {
        if (mounted) Navigator.of(context).pop();
        _showSnackBar('Unable to read selected file');
        return;
      }

      print('Reading ZIP file: ${bytes.length} bytes');

      // Decode ZIP archive
      final archive = ZipDecoder().decodeBytes(bytes);
      print('Archive contains ${archive.files.length} files');

      // Find the JSON backup file
      final jsonFile = archive.files.firstWhere(
            (file) => file.name == 'links_backup.json',
        orElse: () => throw Exception('links_backup.json not found in archive'),
      );

      if (jsonFile.content == null || jsonFile.content.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        _showSnackBar('Backup file is empty');
        return;
      }

      // Decode JSON content
      final jsonString = utf8.decode(jsonFile.content as List<int>);
      print('JSON content length: ${jsonString.length}');

      if (jsonString.trim().isEmpty) {
        if (mounted) Navigator.of(context).pop();
        _showSnackBar('Backup contains no data');
        return;
      }

      // Parse JSON
      final Map<String, dynamic> backupData = jsonDecode(jsonString);
      final List<dynamic> linksData = backupData['links'] ?? [];

      if (linksData.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        _showSnackBar('No links found in backup');
        return;
      }

      // Import links to database
      final db = await _dbHelper.database;
      final batch = db.batch();
      int importedCount = 0;
      int updatedCount = 0;
      int skippedCount = 0;

      for (var linkData in linksData) {
        try {
          final map = Map<String, dynamic>.from(linkData);
          final url = map['url'] as String?;

          if (url == null || url.isEmpty) {
            skippedCount++;
            continue;
          }

          // Extract link data
          final title = map['title'] as String? ?? 'Untitled';
          final description = map['description'] as String? ?? '';
          final imageUrl = map['imageUrl'] as String? ?? '';
          final domain = map['domain'] as String? ?? '';
          final notes = map['notes'] as String?;
          final tags = (map['tags'] as List<dynamic>?)?.cast<String>() ?? <String>[];

          DateTime createdAt;
          try {
            createdAt = map['created_at'] != null
                ? DateTime.parse(map['created_at'])
                : DateTime.now();
          } catch (e) {
            createdAt = DateTime.now();
          }

          // Create LinkModel
          final linkModel = LinkModel(
            url: url,
            title: title,
            description: description,
            imageUrl: imageUrl,
            domain: domain.isEmpty ? Uri.tryParse(url)?.host ?? '' : domain,
            tags: tags,
            notes: notes,
            createdAt: createdAt,
          );

          // Check if link already exists
          final exists = await _dbHelper.linkExists(url);
          if (exists) {
            // Update existing link
            final existingLinks = await _dbHelper.getAllLinks();
            final existingLink = existingLinks.firstWhere(
                  (link) => link.url == url,
              orElse: () => linkModel,
            );

            if (existingLink.id != null) {
              batch.update(
                'links',
                linkModel.toMap(),
                where: 'id = ?',
                whereArgs: [existingLink.id],
              );
              updatedCount++;
            }
          } else {
            // Insert new link
            batch.insert(
              'links',
              linkModel.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            importedCount++;
          }
        } catch (linkError) {
          print('Error processing link: $linkError');
          skippedCount++;
        }
      }

      // Commit batch operations
      await batch.commit(noResult: true);

      if (mounted) Navigator.of(context).pop();

      // Show import results
      final totalProcessed = importedCount + updatedCount;
      String message = 'Import completed!\n';
      if (importedCount > 0) message += '$importedCount new links added\n';
      if (updatedCount > 0) message += '$updatedCount links updated\n';
      if (skippedCount > 0) message += '$skippedCount links skipped';

      _showSnackBar(message.trim());
      print('Import completed: $importedCount new, $updatedCount updated, $skippedCount skipped');

    } catch (e, stackTrace) {
      if (mounted) Navigator.of(context).pop();
      print('Import error: $e');
      print('Stack trace: $stackTrace');
      _showSnackBar('Import failed: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Clearing cache...'),
              ],
            ),
          ),
        );
      }

      // Clear different types of cache
      await DefaultCacheManager().emptyCache();

      // Clear Flutter image cache
      imageCache.clear();
      imageCache.clearLiveImages();

      // Clear temporary directory
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        await tempDir.create(recursive: true);
      }

      // Clear metadata cache if available
      try {
        // This assumes MetadataService has a clearCache method
        // You might need to import and call it here
        print('Cache cleared successfully');
      } catch (e) {
        print('Error clearing metadata cache: $e');
      }

      if (mounted) Navigator.of(context).pop();
      _showSnackBar('Cache cleared successfully');

    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      print('Cache clear error: $e');
      _showSnackBar('Error clearing cache: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color backgroundColor,
    Color? iconColor,
    bool isLoading = false,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isLoading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: backgroundColor.withOpacity(0.1),
                child: isLoading
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      iconColor ?? backgroundColor,
                    ),
                  ),
                )
                    : Icon(
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
                        color: isLoading
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : null,
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
              if (!isLoading)
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
            // Permission warning card
            if (!_hasStoragePermission)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.1),
                  ),
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

            // Export Data Card
            _buildActionCard(
              icon: Icons.backup_rounded,
              title: 'Export Data',
              subtitle: 'Create a backup of all your saved links',
              onTap: _exportData,
              backgroundColor: Theme.of(context).colorScheme.primary,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 16),

            // Import Data Card
            _buildActionCard(
              icon: Icons.restore_rounded,
              title: 'Import Data',
              subtitle: 'Restore links from a backup file',
              onTap: _importData,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 16),

            // Clear Cache Card
            _buildActionCard(
              icon: Icons.cleaning_services_rounded,
              title: 'Clear Cache',
              subtitle: 'Free up storage space by clearing cached data',
              onTap: _clearCache,
              backgroundColor: Theme.of(context).colorScheme.error,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
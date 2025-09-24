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
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final sdkInt = androidInfo.version.sdkInt;

        if (sdkInt <= 31) {
          final status = await Permission.storage.status;
          setState(() {
            _hasStoragePermission = status.isGranted;
          });
        } else {
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

      final links = await _dbHelper.getAllLinks();
      if (links.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        _showSnackBar('No links to export');
        return;
      }

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

      final jsonString = jsonEncode(exportData);
      print('Export data prepared - Links: ${links.length}, JSON size: ${jsonString.length} bytes');

      final tempDir = await getTemporaryDirectory();
      final tempJsonFile = File('${tempDir.path}/links_backup_${DateTime.now().millisecondsSinceEpoch}.json');

      await tempJsonFile.writeAsString(jsonString, flush: true);

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

      final jsonBytes = await tempJsonFile.readAsBytes();
      final archive = Archive();

      final archiveFile = ArchiveFile(
        'links_backup.json',
        jsonBytes.length,
        jsonBytes,
      );
      archive.addFile(archiveFile);

      final zipData = ZipEncoder().encode(archive);

      await tempJsonFile.delete();

      if (zipData == null || zipData.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        _showSnackBar('Failed to create ZIP archive');
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'linknest_backup_$timestamp.zip';

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

      final result = await FilePicker.platform.pickFiles(
        allowedExtensions: ['zip'],
        type: FileType.custom,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        _showSnackBar('No file selected');
        return;
      }

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

      if (pickedFile.bytes != null) {
        bytes = pickedFile.bytes!;
      } else {
        final file = File(pickedFile.path!);
        if (!await file.exists()) {
          if (mounted) Navigator.of(context).pop();
          _showSnackBar('Selected file does not exist');
          return;
        }
        bytes = await file.readAsBytes();
      }

      print('Reading ZIP file: ${bytes.length} bytes');

      final archive = ZipDecoder().decodeBytes(bytes);
      print('Archive contains ${archive.files.length} files');

      final jsonFile = archive.files.firstWhere(
            (file) => file.name == 'links_backup.json',
        orElse: () => throw Exception('links_backup.json not found in archive'),
      );

      if (jsonFile.content == null || (jsonFile.content as List).isEmpty) {
        if (mounted) Navigator.of(context).pop();
        _showSnackBar('Backup file is empty');
        return;
      }

      final jsonString = utf8.decode(jsonFile.content as List<int>);
      print('JSON content length: ${jsonString.length}');

      if (jsonString.trim().isEmpty) {
        if (mounted) Navigator.of(context).pop();
        _showSnackBar('Backup contains no data');
        return;
      }

      final Map<String, dynamic> backupData = jsonDecode(jsonString);
      final List<dynamic> linksData = backupData['links'] ?? [];

      if (linksData.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        _showSnackBar('No links found in backup');
        return;
      }

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

          final exists = await _dbHelper.linkExists(url);
          if (exists) {
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

      await batch.commit(noResult: true);

      if (mounted) Navigator.of(context).pop();

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

      await DefaultCacheManager().emptyCache();
      imageCache.clear();
      imageCache.clearLiveImages();

      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        await tempDir.create(recursive: true);
      }

      try {
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
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      surfaceTintColor: theme.colorScheme.surfaceTint,
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isLoading
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
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
                  color: theme.colorScheme.onSurfaceVariant,
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
              Container(
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
            if (!_hasStoragePermission) const SizedBox(height: 16),
            _buildActionCard(
              icon: Icons.backup_rounded,
              title: 'Export Data',
              subtitle: 'Create a backup of all your saved links',
              onTap: _exportData,
              backgroundColor: Theme.of(context).colorScheme.primary,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              icon: Icons.restore_rounded,
              title: 'Import Data',
              subtitle: 'Restore links from a backup file',
              onTap: _importData,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 16),
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
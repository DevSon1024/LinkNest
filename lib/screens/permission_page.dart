import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class PermissionPage extends StatefulWidget {
  final String action; // 'import' or 'export'

  const PermissionPage({super.key, required this.action});

  @override
  _PermissionPageState createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> {
  bool _isRequesting = true;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _requestStoragePermission();
  }

  Future<void> _requestStoragePermission() async {
    bool granted = true;

    // Only request READ_EXTERNAL_STORAGE for Android 12 (API 32) and below
    if (Platform.isAndroid && await _getAndroidVersion() <= 32) {
      final status = await Permission.storage.request();
      granted = status.isGranted;

      if (!granted && status.isPermanentlyDenied) {
        setState(() {
          _isRequesting = false;
          _permissionDenied = true;
        });
        return;
      }
    }

    setState(() {
      _isRequesting = false;
    });

    if (mounted) {
      Navigator.pop(context, granted);
    }
  }

  Future<int> _getAndroidVersion() async {
    // Placeholder: In a real app, use device_info_plus to get SDK version
    return 33; // Assume Android 13+ for simplicity
  }

  void _openAppSettings() async {
    await openAppSettings();
    final status = await Permission.storage.status;
    final granted = status.isGranted;

    if (mounted) {
      Navigator.pop(context, granted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.action.capitalize()} Permission'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
        elevation: 2,
      ),
      body: Center(
        child: _isRequesting
            ? const CircularProgressIndicator()
            : _permissionDenied
            ? Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_rounded,
                size: 80,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Storage Permission Denied',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please grant storage permission in app settings to ${widget.action} data.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _openAppSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        )
            : const SizedBox(),
      ),
    );
  }
}

// Extension to capitalize string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
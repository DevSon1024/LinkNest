import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionPage extends StatefulWidget {
  final String action; // 'import' or 'export'

  const PermissionPage({super.key, required this.action});

  @override
  _PermissionPageState createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> {
  @override
  void initState() {
    super.initState();
    _requestStoragePermission();
  }

  Future<void> _requestStoragePermission() async {
    // Request storage permission
    final status = await Permission.storage.request();
    bool granted = status.isGranted;

    if (!granted) {
      // For Android 13+, also request manageExternalStorage for broader access
      final manageStatus = await Permission.manageExternalStorage.request();
      granted = manageStatus.isGranted;
    }

    // Check permission status after returning from settings
    final finalStatus = await Permission.storage.status;
    final finalManageStatus = await Permission.manageExternalStorage.status;
    granted = finalStatus.isGranted || finalManageStatus.isGranted;

    // Return the result to the previous screen
    if (mounted) {
      Navigator.pop(context, granted);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while redirecting to settings
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
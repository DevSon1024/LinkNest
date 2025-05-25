import 'package:flutter/material.dart';
import 'storage_setting.dart';
import 'version_page.dart'; // Import the new VersionPage

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Menu',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Storage Settings'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StorageSetting()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version & Updates'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VersionPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
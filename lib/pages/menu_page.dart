import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/storage_setting.dart';
import '../screens/version_page.dart';
import '../screens/display_setting.dart';
import '../screens/tags_page.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  Future<void> _launchPrivacyPolicy() async {
    const url = 'https://sites.google.com/view/linknest-privacy-policy/home';
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildMenuItem(
            context,
            icon: CupertinoIcons.paintbrush,
            title: 'Display Settings',
            subtitle: 'Theme and appearance options',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DisplaySetting()),
            ),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            icon: CupertinoIcons.folder,
            title: 'Storage Settings',
            subtitle: 'Backup, restore & cache management',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const StorageSetting()),
            ),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            icon: CupertinoIcons.shield_lefthalf_fill,
            title: 'Privacy Policy',
            subtitle: 'View app privacy policy and terms',
            onTap: _launchPrivacyPolicy,
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            icon: CupertinoIcons.info_circle,
            title: 'Version & Updates',
            subtitle: 'App version and changelog',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const VersionPage()),
            ),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            icon: CupertinoIcons.tag,
            title: 'Manage Tags',
            subtitle: 'View, rename, and delete your tags',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TagsPage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Icon(icon, size: 24, color: theme.colorScheme.primary),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(CupertinoIcons.chevron_forward, size: 20),
        onTap: onTap,
      ),
    );
  }
}
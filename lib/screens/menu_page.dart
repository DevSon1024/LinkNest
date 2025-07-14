import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'storage_setting.dart';
import 'version_page.dart';
import 'display_setting.dart';

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
        title: const Text(
          'Menu',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildMenuItem(
              context,
              icon: Icons.palette_rounded,
              title: 'Display Settings',
              subtitle: 'Theme and appearance options',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DisplaySetting()),
              ),
            ),
            const SizedBox(height: 16),
            _buildMenuItem(
              context,
              icon: Icons.storage_rounded,
              title: 'Storage Settings',
              subtitle: 'Backup, restore & cache management',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StorageSetting()),
              ),
            ),
            const SizedBox(height: 16),
            _buildMenuItem(
              context,
              icon: Icons.privacy_tip_rounded,
              title: 'Privacy Policy',
              subtitle: 'View app privacy policy and terms',
              onTap: _launchPrivacyPolicy,
            ),
            const SizedBox(height: 16),
            _buildMenuItem(
              context,
              icon: Icons.info_rounded,
              title: 'Version & Updates',
              subtitle: 'App version and changelog',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VersionPage()),
              ),
            ),
          ],
        ),
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
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
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
}
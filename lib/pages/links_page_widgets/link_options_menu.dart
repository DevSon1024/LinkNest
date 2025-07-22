import 'package:flutter/material.dart';
import '../../models/link_model.dart';

class LinkOptionsMenu extends StatelessWidget {
  final LinkModel link;
  final VoidCallback onOpenInApp;
  final VoidCallback onOpenInBrowser;
  final VoidCallback onEditNotes;
  final VoidCallback onCopyUrl;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const LinkOptionsMenu({
    super.key,
    required this.link,
    required this.onOpenInApp,
    required this.onOpenInBrowser,
    required this.onEditNotes,
    required this.onCopyUrl,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.open_in_new, color: Theme.of(context).colorScheme.onSurface),
              title: const Text('Open Link (In-App)'),
              onTap: () {
                Navigator.pop(context);
                onOpenInApp();
              },
            ),
            ListTile(
              leading: Icon(Icons.open_in_browser, color: Theme.of(context).colorScheme.onSurface),
              title: const Text('Open in Default Browser'),
              onTap: () {
                Navigator.pop(context);
                onOpenInBrowser();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Add/Edit Description', style: TextStyle(color: Colors.blue)),
              onTap: () {
                Navigator.pop(context);
                onEditNotes();
              },
            ),
            ListTile(
              leading: Icon(Icons.copy, color: Theme.of(context).colorScheme.onSurface),
              title: const Text('Copy URL'),
              onTap: () {
                Navigator.pop(context);
                onCopyUrl();
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: Theme.of(context).colorScheme.onSurface),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                onShare();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
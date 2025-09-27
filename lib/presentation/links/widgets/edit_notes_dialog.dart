import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../data/models/link_model.dart';

class EditNotesDialog extends StatefulWidget {
  final LinkModel link;
  final Function(LinkModel) onSave;

  const EditNotesDialog({
    super.key,
    required this.link,
    required this.onSave,
  });

  @override
  EditNotesDialogState createState() => EditNotesDialogState();
}

class EditNotesDialogState extends State<EditNotesDialog> {
  late TextEditingController _notesController;
  late TextEditingController _tagController;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.link.notes ?? '');
    _tagController = TextEditingController();
    _tags = List.from(widget.link.tags);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final newTag = _tagController.text.trim();
    if (newTag.isNotEmpty && !_tags.contains(newTag)) {
      setState(() {
        _tags.add(newTag);
      });
    }
    _tagController.clear();
  }

  Future<bool?> _confirmDeleteNotes() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Notes'),
        content: const Text(
            'Are you sure you want to delete the notes for this link?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasNotes = widget.link.notes != null && widget.link.notes!.isNotEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add/Edit Notes and Tags'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.link.imageUrl != null &&
                widget.link.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: widget.link.imageUrl!,
                  fit: BoxFit.cover,
                  height: 150,
                  width: double.infinity,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                    highlightColor:
                    Theme.of(context).colorScheme.surfaceContainer,
                    child: Container(
                      height: 150,
                      color:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 150,
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: Icon(Icons.link,
                        size: 40,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              widget.link.title ?? 'No Title',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              [
                if (widget.link.description != null &&
                    widget.link.description!.isNotEmpty)
                  widget.link.description!,
                'Domain: ${widget.link.domain}',
                if (widget.link.tags.isNotEmpty)
                  'Tags: ${widget.link.tags.join(', ')}',
              ].join('\n'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Notes',
                border: const OutlineInputBorder(),
                hintText: 'Add your notes here...',
                filled: true,
                fillColor:
                Theme.of(context).colorScheme.surfaceContainerLowest,
              ),
            ),
            const SizedBox(height: 16),
            Text('Tags', style: Theme.of(context).textTheme.titleLarge),
            Wrap(
              spacing: 8.0,
              children: _tags
                  .map((tag) => Chip(
                label: Text(tag),
                onDeleted: () {
                  setState(() {
                    _tags.remove(tag);
                  });
                },
              ))
                  .toList(),
            ),
            TextField(
              controller: _tagController,
              decoration: InputDecoration(
                labelText: 'Add a tag',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addTag,
                ),
              ),
              onSubmitted: (_) => _addTag(),
            ),
          ],
        ),
      ),
      actions: [
        if (hasNotes)
          TextButton(
            onPressed: () async {
              final confirm = await _confirmDeleteNotes();
              if (confirm == true) {
                final updatedLink = widget.link.copyWith(clearNotes: true);
                widget.onSave(updatedLink);
                Navigator.pop(context);
              }
            },
            child: const Text(
              'Delete Notes',
              style: TextStyle(color: Colors.red),
            ),
          ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final noteText = _notesController.text.trim();
            final updatedLink = widget.link.copyWith(
              notes: noteText.isEmpty ? null : noteText,
              clearNotes: noteText.isEmpty,
              tags: _tags,
            );
            widget.onSave(updatedLink);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(hasNotes ? 'Update' : 'Save'),
        ),
      ],
    );
  }
}
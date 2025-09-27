import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../data/models/link_model.dart';
import '../../core/services/database_helper.dart';

class LinkCard extends StatelessWidget {
  final LinkModel link;
  final bool isGridView;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onOptionsTap;
  final Function(LinkModel) onDelete;
  final Function(LinkModel) onFavoriteToggle;

  const LinkCard({
    super.key,
    required this.link,
    required this.isGridView,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onOptionsTap,
    required this.onDelete,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMetadataReady =
        link.status == MetadataStatus.completed &&
            link.title != null &&
            link.title!.isNotEmpty;

    final cardContent = isGridView
        ? _buildGridCard(context, isMetadataReady)
        : _buildListCard(context, isMetadataReady);

    return Dismissible(
      key: Key('link_${link.id}'),
      background: _buildDismissibleBackground(context, true),
      secondaryBackground: _buildDismissibleBackground(context, false),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onFavoriteToggle(link);
          return false;
        } else {
          final bool? confirmed = await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("Confirm"),
                content: const Text("Are you sure you wish to delete this item?"),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text("CANCEL"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text("DELETE"),
                  ),
                ],
              );
            },
          );
          if (confirmed == true) {
            onDelete(link);
          }
          return confirmed;
        }
      },
      child: cardContent,
    );
  }

  Widget _buildDismissibleBackground(BuildContext context, bool isPrimary) {
    return Container(
      color: isPrimary ? Colors.yellow : Colors.red,
      child: Align(
        alignment: isPrimary ? Alignment.centerLeft : Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPrimary) ...[
                const Icon(Icons.star, color: Colors.white),
                const SizedBox(width: 8),
                const Text("Favorite", style: TextStyle(color: Colors.white)),
              ],
              if (!isPrimary) ...[
                const Text("Delete", style: TextStyle(color: Colors.white)),
                const SizedBox(width: 8),
                const Icon(Icons.delete, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, bool isMetadataReady) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? Border.all(
                    color: Theme.of(context).colorScheme.primary, width: 2.5)
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: isMetadataReady &&
                            link.imageUrl != null &&
                            link.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                          imageUrl: link.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Shimmer.fromColors(
                                baseColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                highlightColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainer,
                                child: Container(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest),
                              ),
                          errorWidget: (context, url, error) =>
                              _buildPlaceholderIcon(context),
                        )
                            : _buildPlaceholderIcon(context),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Theme.of(context).colorScheme.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMetadataReady ? link.title! : link.domain,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                ),
                                child: Icon(
                                  Icons.language,
                                  size: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  link.domain,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (link.isFavorite)
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isSelectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: AnimatedScale(
                  scale: isSelected ? 1.0 : 0.8,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Icon(Icons.check,
                        size: 16,
                        color: Theme.of(context).colorScheme.onPrimary)
                        : null,
                  ),
                ),
              ),
            if (!isSelectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onOptionsTap,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                    child: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(BuildContext context, bool isMetadataReady) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: isMetadataReady &&
                      link.imageUrl != null &&
                      link.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                    imageUrl: link.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) =>
                        _buildPlaceholderFavicon(context),
                  )
                      : _buildPlaceholderFavicon(context),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isMetadataReady ? link.title! : link.url,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isMetadataReady
                          ? (link.description ?? link.domain)
                          : link.domain,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (link.isFavorite)
                      const Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
              if (isSelectionMode)
                AnimatedScale(
                  scale: isSelected ? 1.0 : 0.8,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Icon(Icons.check,
                        size: 16,
                        color: Theme.of(context).colorScheme.onPrimary)
                        : null,
                  ),
                )
              else
                GestureDetector(
                  onTap: onOptionsTap,
                  child: Icon(
                    Icons.more_vert,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Center(
        child: Icon(
          Icons.link,
          size: 40,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildPlaceholderFavicon(BuildContext context) {
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      child: CachedNetworkImage(
        imageUrl:
        'https://www.google.com/s2/favicons?sz=64&domain_url=${link.domain}',
        errorWidget: (context, url, error) => const Icon(Icons.public),
      ),
    );
  }
}
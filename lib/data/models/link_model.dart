import 'dart:convert';

enum MetadataStatus { pending, completed, failed }

class LinkModel {
  final int? id;
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final DateTime createdAt;
  final String domain;
  final List<String> tags;
  final String? notes;
  final MetadataStatus status;
  final bool isFavorite;
  final bool isMetadataLoaded;

  LinkModel({
    this.id,
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    required this.createdAt,
    required this.domain,
    this.tags = const [],
    this.notes,
    this.status = MetadataStatus.pending,
    this.isFavorite = false,
    this.isMetadataLoaded = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'domain': domain,
      'tags': json.encode(tags),
      'notes': notes,
      'status': status.name,
      'isFavorite': isFavorite ? 1 : 0,
      'isMetadataLoaded': isMetadataLoaded ? 1 : 0,
    };
  }

  factory LinkModel.fromMap(Map<String, dynamic> map) {
    List<String> tagsList = [];
    if (map['tags'] != null && map['tags'].toString().isNotEmpty) {
      try {
        final decoded = json.decode(map['tags']);
        if (decoded is List) {
          tagsList = decoded.cast<String>();
        }
      } catch (e) {
        // If JSON decode fails, treat as empty list
        tagsList = [];
      }
    }

    return LinkModel(
      id: map['id'],
      url: map['url'] ?? '',
      title: map['title'],
      description: map['description'],
      imageUrl: map['imageUrl'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      domain: map['domain'] ?? '',
      tags: tagsList,
      notes: map['notes'],
      status: MetadataStatus.values.firstWhere(
            (e) => e.name == map['status'],
        orElse: () => MetadataStatus.pending,
      ),
      isFavorite: map['isFavorite'] == 1,
      isMetadataLoaded: map['isMetadataLoaded'] == 1,
    );
  }

  LinkModel copyWith({
    int? id,
    String? url,
    String? title,
    String? description,
    String? imageUrl,
    DateTime? createdAt,
    String? domain,
    List<String>? tags,
    String? notes,
    bool clearNotes = false,
    MetadataStatus? status,
    bool? isFavorite,
    bool? isMetadataLoaded,
  }) {
    return LinkModel(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      domain: domain ?? this.domain,
      tags: tags ?? List<String>.from(this.tags), // Create new list to avoid reference issues
      notes: clearNotes ? null : (notes ?? this.notes),
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
      isMetadataLoaded: isMetadataLoaded ?? this.isMetadataLoaded,
    );
  }
}

import 'dart:convert';

enum MetadataStatus { pending, completed, failed }

class LinkModel {
  final int? id;
  final String url;
  final String? title; // Now nullable
  final String? description; // Now nullable
  final String? imageUrl; // Now nullable
  final DateTime createdAt;
  final String domain;
  final List<String> tags;
  final String? notes;
  final MetadataStatus status; // New field

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
      'status': status.name, // Store status as a string
    };
  }

  factory LinkModel.fromMap(Map<String, dynamic> map) {
    return LinkModel(
      id: map['id'],
      url: map['url'] ?? '',
      title: map['title'],
      description: map['description'],
      imageUrl: map['imageUrl'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      domain: map['domain'] ?? '',
      tags: map['tags'] != null ? List<String>.from(json.decode(map['tags'])) : <String>[],
      notes: map['notes'],
      status: MetadataStatus.values.firstWhere(
            (e) => e.name == map['status'],
        orElse: () => MetadataStatus.pending,
      ),
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
  }) {
    return LinkModel(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      domain: domain ?? this.domain,
      tags: tags ?? this.tags,
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }
}

import 'dart:convert';

class LinkModel {
  final int? id;
  final String url;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime createdAt;
  final String domain;
  final List<String> tags;
  final String? notes;

  LinkModel({
    this.id,
    required this.url,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.createdAt,
    required this.domain,
    required this.tags,
    this.notes,
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
    };
  }

  factory LinkModel.fromMap(Map<String, dynamic> map) {
    return LinkModel(
      id: map['id'],
      url: map['url'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      domain: map['domain'] ?? '',
      tags: map['tags'] != null ? List<String>.from(json.decode(map['tags'])) : <String>[],
      notes: map['notes'],
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

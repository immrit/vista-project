import 'dart:convert';

class Note {
  final dynamic id;
  final String title;
  final String content;
  final DateTime createdAt;
  final bool isPinned; // اضافه کردن فیلد isPinned

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.isPinned = false, // مقدار پیش‌فرض برای isPinned
  });

  // اضافه کردن متد copyWith
  Note copyWith({
    String? title,
    String? content,
    bool? isPinned,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      isPinned: isPinned ?? this.isPinned, // به‌روزرسانی وضعیت isPinned
    );
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      isPinned: map['is_pinned'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'is_pinned': isPinned,
    };
  }

  String toJson() => json.encode(toMap());

  factory Note.fromJson(String source) => Note.fromMap(json.decode(source));

  @override
  String toString() =>
      'Note(id: $id, title: $title, content: $content, isPinned: $isPinned)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Note &&
        other.id == id &&
        other.title == title &&
        other.content == content &&
        other.isPinned == isPinned;
  }

  @override
  int get hashCode => title.hashCode ^ content.hashCode ^ isPinned.hashCode;
}

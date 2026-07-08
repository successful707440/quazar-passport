class ChatMessage {
  final String id;
  final String citizenId;
  final String citizenName;
  final String content;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.citizenId,
    required this.citizenName,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      citizenId: json['citizen_id'] as String? ?? '',
      citizenName: json['citizen_name'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

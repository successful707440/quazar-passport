class Event {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final String type;
  final Map<String, dynamic>? data;
  final String? initiator;
  final bool confirmed;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.type,
    this.data,
    this.initiator,
    this.confirmed = false,
  });

  factory Event.fromJson(Map<String, dynamic> json, {bool confirmed = false}) {
    // Поддержка разных форматов
    final id = json['event_id'] ?? json['id'] ?? '';
    final title = json['title'] ?? 'Без названия';
    final description = json['description'] ?? '';
    final type = json['event_type'] ?? json['type'] ?? 'info';
    final initiator = json['initiator'] ?? '';
    final data = json['data'] as Map<String, dynamic>?;
    
    // Парсим timestamp (может быть в секундах или миллисекундах)
    DateTime timestamp;
    if (json['timestamp'] is int) {
      final ts = json['timestamp'] as int;
      if (ts < 10000000000) {
        timestamp = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      } else {
        timestamp = DateTime.fromMillisecondsSinceEpoch(ts);
      }
    } else if (json['timestamp'] is String) {
      timestamp = DateTime.tryParse(json['timestamp']) ?? DateTime.now();
    } else {
      timestamp = DateTime.now();
    }
    
    return Event(
      id: id,
      title: title,
      description: description,
      timestamp: timestamp,
      type: type,
      data: data,
      initiator: initiator,
      confirmed: confirmed,
    );
  }
}

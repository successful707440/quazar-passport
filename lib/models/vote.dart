class Vote {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String status;

  static const List<Map<String, String>> choices = [
    {'value': 'yes', 'label': 'За'},
    {'value': 'no', 'label': 'Против'},
    {'value': 'abstain', 'label': 'Воздержался'},
  ];

  Vote({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  bool get isActive => status == 'active' && DateTime.now().isBefore(endTime);

  factory Vote.fromJson(Map<String, dynamic> json) {
    return Vote(
      id: json['vote_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      startTime: _parseDateTime(json['start_time']),
      endTime: _parseDateTime(json['end_time']),
      status: json['status'] as String? ?? 'closed',
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

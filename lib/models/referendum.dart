class Referendum {
  final String id;
  final String title;
  final String description;
  final String targetDecision;
  final String status;
  final String announcerId;
  final String announcerName;
  final int votesFor;
  final int votesAgainst;
  final int votesAbstain;
  final DateTime createdAt;
  final DateTime? completedAt;

  Referendum({
    required this.id,
    required this.title,
    required this.description,
    required this.targetDecision,
    required this.status,
    required this.announcerId,
    required this.announcerName,
    required this.votesFor,
    required this.votesAgainst,
    required this.votesAbstain,
    required this.createdAt,
    this.completedAt,
  });

  bool get isActive => status == 'Active';
  bool get isCompleted => status == 'Completed';

  static const List<Map<String, String>> voteChoices = [
    {'value': 'For', 'label': 'За отмену'},
    {'value': 'Against', 'label': 'Против отмены'},
    {'value': 'Abstain', 'label': 'Воздержался'},
  ];

  static const Map<String, String> statusLabels = {
    'Active': 'Активен',
    'Completed': 'Завершён',
    'Cancelled': 'Отменён',
  };

  String get statusLabel => statusLabels[status] ?? status;

  factory Referendum.fromJson(Map<String, dynamic> json) {
    return Referendum(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      targetDecision: json['target_decision'] as String? ?? '',
      status: json['status'] as String? ?? '',
      announcerId: json['announcer_id'] as String? ?? '',
      announcerName: json['announcer_name'] as String? ?? '',
      votesFor: json['votes_for'] as int? ?? 0,
      votesAgainst: json['votes_against'] as int? ?? 0,
      votesAbstain: json['votes_abstain'] as int? ?? 0,
      createdAt: _parseDateTime(json['created_at']),
      completedAt: _parseOptionalDateTime(json['completed_at']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static DateTime? _parseOptionalDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class Initiative {
  final String id;
  final String title;
  final String description;
  final String status;
  final String proposerId;
  final String proposerName;
  final int votesFor;
  final int votesAgainst;
  final int votesAbstain;
  final int threshold;
  final DateTime createdAt;
  final DateTime? passedAt;

  Initiative({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.proposerId,
    required this.proposerName,
    required this.votesFor,
    required this.votesAgainst,
    required this.votesAbstain,
    required this.threshold,
    required this.createdAt,
    this.passedAt,
  });

  bool get isProposed => status == 'Proposed';
  bool get isPassed => status == 'Passed';

  static const List<Map<String, String>> voteChoices = [
    {'value': 'For', 'label': 'За'},
    {'value': 'Against', 'label': 'Против'},
    {'value': 'Abstain', 'label': 'Воздержался'},
  ];

  static const Map<String, String> statusLabels = {
    'Proposed': 'На голосовании',
    'Passed': 'Принята',
    'Rejected': 'Отклонена',
  };

  String get statusLabel => statusLabels[status] ?? status;

  factory Initiative.fromJson(Map<String, dynamic> json) {
    return Initiative(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? '',
      proposerId: json['proposer_id'] as String? ?? '',
      proposerName: json['proposer_name'] as String? ?? '',
      votesFor: json['votes_for'] as int? ?? 0,
      votesAgainst: json['votes_against'] as int? ?? 0,
      votesAbstain: json['votes_abstain'] as int? ?? 0,
      threshold: json['threshold'] as int? ?? 1,
      createdAt: _parseDateTime(json['created_at']),
      passedAt: _parseOptionalDateTime(json['passed_at']),
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

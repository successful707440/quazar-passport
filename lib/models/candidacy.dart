class Candidacy {
  final String id;
  final String citizenId;
  final String citizenName;
  final String targetRole;
  final String status;
  final int votesFor;
  final int votesAgainst;
  final int votesAbstain;
  final int threshold;
  final String nominatorId;
  final String nominatorName;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? appointedAt;

  Candidacy({
    required this.id,
    required this.citizenId,
    required this.citizenName,
    required this.targetRole,
    required this.status,
    required this.votesFor,
    required this.votesAgainst,
    required this.votesAbstain,
    required this.threshold,
    required this.nominatorId,
    required this.nominatorName,
    required this.createdAt,
    this.approvedAt,
    this.appointedAt,
  });

  bool get isActive => status == 'Active';
  bool get isApproved => status == 'Approved';
  bool get isAppointed => status == 'Appointed';

  static const List<Map<String, String>> voteChoices = [
    {'value': 'For', 'label': 'За'},
    {'value': 'Against', 'label': 'Против'},
    {'value': 'Abstain', 'label': 'Воздержался'},
  ];

  static const Map<String, String> roleLabels = {
    'Guardian': 'Охранник',
    'Judge': 'Судья',
    'Aiya': 'Айя',
  };

  static const Map<String, String> statusLabels = {
    'Active': 'Активна',
    'Approved': 'Утверждена',
    'Appointed': 'Назначена',
    'Rejected': 'Отклонена',
  };

  String get roleLabel => roleLabels[targetRole] ?? targetRole;
  String get statusLabel => statusLabels[status] ?? status;

  factory Candidacy.fromJson(Map<String, dynamic> json) {
    return Candidacy(
      id: json['id'] as String? ?? '',
      citizenId: json['citizen_id'] as String? ?? '',
      citizenName: json['citizen_name'] as String? ?? '',
      targetRole: json['target_role'] as String? ?? '',
      status: json['status'] as String? ?? '',
      votesFor: json['votes_for'] as int? ?? 0,
      votesAgainst: json['votes_against'] as int? ?? 0,
      votesAbstain: json['votes_abstain'] as int? ?? 0,
      threshold: json['threshold'] as int? ?? 1,
      nominatorId: json['nominator_id'] as String? ?? '',
      nominatorName: json['nominator_name'] as String? ?? '',
      createdAt: _parseDateTime(json['created_at']),
      approvedAt: _parseOptionalDateTime(json['approved_at']),
      appointedAt: _parseOptionalDateTime(json['appointed_at']),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/candidacy_provider.dart';
import '../screens/candidacies_screen.dart';
import '../screens/initiatives_screen.dart';
import '../screens/referendums_screen.dart';
import '../widgets/create_vote_dialog.dart';
import '../widgets/nominate_candidate_dialog.dart';
import '../widgets/assign_role_dialog.dart';
import '../widgets/initiate_referendum_dialog.dart';
import '../widgets/propose_initiative_dialog.dart';

class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).refreshCitizenProfile();
    });
  }

  int _roleLevel(String? role) {
    switch (role) {
      case 'Aiya':
        return 4;
      case 'Guardian':
        return 3;
      case 'Judge':
        return 2;
      case 'Citizen':
        return 1;
      default:
        return 0;
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'Aiya':
        return '👑 Айя';
      case 'Guardian':
        return '🛡️ Охранник';
      case 'Judge':
        return '⚖️ Судья';
      case 'Citizen':
        return '👤 Гражданин';
      default:
        return '❓ Роль не назначена';
    }
  }

  void _scanPassport(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔍 Сканирование паспорта...')),
    );
  }

  void _verifyPassportGuardian(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🛡️ Проверка паспорта (охранник)...')),
    );
  }

  void _renderVerdict(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⚖️ Вынесение решения...')),
    );
  }

  void _viewCases(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📜 Просмотр дел...')),
    );
  }

  void _blockCitizen(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔒 Блокировка граждан...')),
    );
  }

  void _createVote(BuildContext context) {
    CreateVoteDialog.show(context);
  }

  void _assignRole(BuildContext context) {
    AssignRoleDialog.show(context);
  }

  void _manageNodes(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⚙️ Управление узлами...')),
    );
  }

  void _requestRole(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('❓ Запрос роли отправлен...')),
    );
  }

  void _proposeInitiative(BuildContext context) {
    ProposeInitiativeDialog.show(context);
  }

  void _viewInitiatives(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InitiativesScreen()),
    );
  }

  void _announceVote(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📢 Объявление голосования...')),
    );
  }

  void _initiateReferendum(BuildContext context) {
    InitiateReferendumDialog.show(context);
  }

  void _viewReferendums(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReferendumsScreen()),
    );
  }

  void _nominateCandidate(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final blocked = CandidacyProvider.participationBlockedReason(auth);
    if (blocked != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blocked)),
      );
      return;
    }
    NominateCandidateDialog.show(context);
  }

  void _viewCandidacies(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CandidaciesScreen()),
    );
  }

  void _vetoDecision(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⛔ Вето наложено...')),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Text(
        '━━━ $title ━━━',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _actionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color backgroundColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRoleActions(BuildContext context, String? role) {
    if (role == null) {
      return [
        _actionButton(
          onPressed: () => _requestRole(context),
          icon: Icons.help_outline,
          label: '❓ Запросить роль',
          backgroundColor: Colors.orange.shade700,
        ),
      ];
    }

    final level = _roleLevel(role);
    final actions = <Widget>[];

    if (level >= 4) {
      actions.addAll([
        _actionButton(
          onPressed: () => _createVote(context),
          icon: Icons.campaign,
          label: '📢 Создать голосование',
          backgroundColor: Colors.deepPurple.shade700,
        ),
        _actionButton(
          onPressed: () => _assignRole(context),
          icon: Icons.military_tech,
          label: '👑 Назначить роль',
          backgroundColor: Colors.deepPurple.shade600,
        ),
        _actionButton(
          onPressed: () => _manageNodes(context),
          icon: Icons.settings,
          label: '⚙️ Управление узлами',
          backgroundColor: Colors.deepPurple.shade500,
        ),
      ]);
    }

    if (level >= 3) {
      actions.addAll([
        _actionButton(
          onPressed: () => _verifyPassportGuardian(context),
          icon: Icons.shield,
          label: '🛡️ Проверить паспорт',
          backgroundColor: Colors.teal.shade700,
        ),
        _actionButton(
          onPressed: () => _blockCitizen(context),
          icon: Icons.lock,
          label: '🔒 Блокировка граждан',
          backgroundColor: Colors.teal.shade600,
        ),
      ]);
    }

    if (level >= 2) {
      actions.addAll([
        _actionButton(
          onPressed: () => _renderVerdict(context),
          icon: Icons.gavel,
          label: '⚖️ Вынести решение',
          backgroundColor: Colors.indigo.shade700,
        ),
        _actionButton(
          onPressed: () => _viewCases(context),
          icon: Icons.folder_open,
          label: '📜 Просмотр дел',
          backgroundColor: Colors.indigo.shade600,
        ),
      ]);
    }

    if (level == 1) {
      actions.add(
        _actionButton(
          onPressed: () => _scanPassport(context),
          icon: Icons.qr_code_scanner,
          label: '🔍 Проверить паспорт',
          backgroundColor: Colors.blue.shade700,
        ),
      );
    }

    return actions;
  }

  List<Widget> _buildCouncilActions(BuildContext context, String? role) {
    final level = _roleLevel(role);
    final actions = <Widget>[
      _actionButton(
        onPressed: () => _proposeInitiative(context),
        icon: Icons.how_to_vote,
        label: '🗳️ Выдвинуть инициативу',
        backgroundColor: Colors.green.shade700,
      ),
      _actionButton(
        onPressed: () => _viewInitiatives(context),
        icon: Icons.list_alt,
        label: '📋 Список инициатив',
        backgroundColor: Colors.green.shade600,
      ),
      _actionButton(
        onPressed: () => _nominateCandidate(context),
        icon: Icons.person_add,
        label: '🎯 Выдвинуть кандидатуру',
        backgroundColor: Colors.green.shade800,
      ),
      _actionButton(
        onPressed: () => _viewCandidacies(context),
        icon: Icons.badge_outlined,
        label: '📋 Кандидатуры',
        backgroundColor: Colors.green.shade900,
      ),
    ];

    if (level >= 3) {
      actions.add(
        _actionButton(
          onPressed: () => _announceVote(context),
          icon: Icons.campaign_outlined,
          label: '📢 Объявить голосование',
          backgroundColor: Colors.green.shade800,
        ),
      );
    }

    return actions;
  }

  List<Widget> _buildVetoActions(
    BuildContext context, {
    required bool canVeto,
  }) {
    final actions = <Widget>[
      _actionButton(
        onPressed: () => _initiateReferendum(context),
        icon: Icons.ballot,
        label: '🗳️ Инициировать референдум',
        backgroundColor: Colors.red.shade700,
      ),
      _actionButton(
        onPressed: () => _viewReferendums(context),
        icon: Icons.fact_check,
        label: '📋 Активные референдумы',
        backgroundColor: Colors.red.shade600,
      ),
    ];

    if (canVeto) {
      actions.add(
        _actionButton(
          onPressed: () => _vetoDecision(context),
          icon: Icons.block,
          label: '⛔ Наложить вето',
          backgroundColor: Colors.red.shade900,
        ),
      );
    }

    return actions;
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Активен';
      case 'suspended':
        return 'Приостановлен';
      case 'revoked':
        return 'Лишён гражданства';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'suspended':
        return Colors.orange;
      case 'revoked':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.check_circle;
      case 'suspended':
        return Icons.pause_circle;
      case 'revoked':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final citizenId = auth.citizenId ?? 'unknown';
    final citizenName = auth.citizenName ?? 'unknown';
    final publicKey = auth.publicKey ?? '';
    final role = auth.role;
    final status = auth.status;
    final qrData = '$citizenId|$publicKey';
    final roleActions = _buildRoleActions(context, role);
    final councilActions = _buildCouncilActions(context, role);
    final vetoActions = _buildVetoActions(context, canVeto: auth.canVeto);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              auth.passportIssued ? Icons.verified_user : Icons.assignment_ind,
              size: 64,
              color: auth.passportIssued ? Colors.green : Colors.deepPurple,
            ),
            const SizedBox(height: 16),
            const Text(
              '📇 ПАСПОРТ КВАЗАРА',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              citizenName,
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              citizenId,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                Chip(
                  avatar: Icon(
                    status.toLowerCase() == 'active' && role != null
                        ? Icons.military_tech
                        : _statusIcon(status),
                    size: 18,
                    color: status.toLowerCase() == 'active' && role != null
                        ? Colors.deepPurple
                        : _statusColor(status),
                  ),
                  label: Text(
                    status.toLowerCase() == 'active' && role != null
                        ? _roleLabel(role)
                        : 'Статус: ${_statusLabel(status)}',
                  ),
                ),
                Chip(
                  avatar: Icon(
                    auth.passportIssued ? Icons.check_circle : Icons.pending,
                    size: 18,
                    color: auth.passportIssued ? Colors.green : Colors.orange,
                  ),
                  label: Text(
                    auth.passportIssued ? 'Паспорт выдан' : 'Паспорт не выдан',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (publicKey.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 250,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                publicKey,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Colors.grey.shade700,
                ),
              ),
            ] else
              Card(
                color: Colors.orange.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Публичный ключ не загружен с сервера',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (roleActions.isNotEmpty) ...[
              _sectionHeader('Доступные действия'),
              ...roleActions,
            ],
            _sectionHeader('Совет граждан'),
            ...councilActions,
            _sectionHeader('Гражданское вето'),
            ...vetoActions,
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: publicKey.isEmpty
                      ? null
                      : () {
                          Share.share(
                            'Цифровой паспорт Квазара\n'
                            'Имя: $citizenName\n'
                            'ID: $citizenId\n'
                            'Публичный ключ: $publicKey',
                            subject: 'Мой паспорт Квазара',
                          );
                        },
                  icon: const Icon(Icons.share),
                  label: const Text('Поделиться'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: publicKey.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: qrData));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('QR-данные скопированы'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.copy),
                  label: const Text('Копировать'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(height: 8),
                    Text(
                      'Данные загружаются с сервера Квазара (GET /citizen/:id). '
                      'QR-код содержит UUID гражданина и его публичный ключ из реестра.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

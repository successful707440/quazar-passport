import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/candidacy.dart';
import '../providers/auth_provider.dart';
import '../providers/candidacy_provider.dart';
import '../services/api_service.dart';
import '../widgets/nominate_candidate_dialog.dart';

class CandidaciesScreen extends StatefulWidget {
  const CandidaciesScreen({super.key});

  @override
  State<CandidaciesScreen> createState() => _CandidaciesScreenState();
}

class _CandidaciesScreenState extends State<CandidaciesScreen> {
  String? _statusFilter = 'Active';
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await Provider.of<CandidacyProvider>(context, listen: false).loadCandidacies(
      status: _statusFilter,
      targetRole: _roleFilter,
    );
  }

  Future<void> _nominate() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final blocked = CandidacyProvider.participationBlockedReason(auth);
    if (blocked != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blocked)),
      );
      return;
    }

    await NominateCandidateDialog.show(context);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final canParticipate = CandidacyProvider.canParticipate(auth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Кандидатуры'),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: canParticipate
          ? FloatingActionButton.extended(
              onPressed: _nominate,
              icon: const Icon(Icons.person_add),
              label: const Text('Выдвинуть'),
            )
          : null,
      body: Column(
        children: [
          _FilterBar(
            statusFilter: _statusFilter,
            roleFilter: _roleFilter,
            onStatusChanged: (value) {
              setState(() => _statusFilter = value);
              _load();
            },
            onRoleChanged: (value) {
              setState(() => _roleFilter = value);
              _load();
            },
          ),
          Expanded(
            child: Consumer<CandidacyProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.candidacies.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null && provider.candidacies.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            provider.error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _load,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (provider.candidacies.isEmpty) {
                  return const Center(
                    child: Text('Нет кандидатур по выбранным фильтрам'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.candidacies.length,
                    itemBuilder: (context, index) {
                      return _CandidacyCard(
                        candidacy: provider.candidacies[index],
                        onChanged: _load,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String? statusFilter;
  final String? roleFilter;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onRoleChanged;

  const _FilterBar({
    required this.statusFilter,
    required this.roleFilter,
    required this.onStatusChanged,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                value: statusFilter,
                decoration: const InputDecoration(
                  labelText: 'Статус',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Все')),
                  DropdownMenuItem(value: 'Active', child: Text('Активные')),
                  DropdownMenuItem(
                    value: 'Approved',
                    child: Text('Утверждённые'),
                  ),
                  DropdownMenuItem(
                    value: 'Appointed',
                    child: Text('Назначенные'),
                  ),
                ],
                onChanged: onStatusChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String?>(
                value: roleFilter,
                decoration: const InputDecoration(
                  labelText: 'Роль',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Все')),
                  DropdownMenuItem(value: 'Guardian', child: Text('Охранник')),
                  DropdownMenuItem(value: 'Judge', child: Text('Судья')),
                  DropdownMenuItem(value: 'Aiya', child: Text('Айя')),
                ],
                onChanged: onRoleChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidacyCard extends StatefulWidget {
  final Candidacy candidacy;
  final VoidCallback onChanged;

  const _CandidacyCard({
    required this.candidacy,
    required this.onChanged,
  });

  @override
  State<_CandidacyCard> createState() => _CandidacyCardState();
}

class _CandidacyCardState extends State<_CandidacyCard> {
  String? _selectedVote;
  bool _submitting = false;

  Future<void> _vote(String vote) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final provider = Provider.of<CandidacyProvider>(context, listen: false);
    final blocked = CandidacyProvider.participationBlockedReason(auth);
    if (blocked != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blocked)),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final updated = await provider.vote(auth, widget.candidacy.id, vote);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _selectedVote = null;
      });
      final message = updated?.isApproved == true
          ? 'Голос учтён. Кандидатура утверждена!'
          : 'Голос учтён: ${_voteLabel(vote)}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      widget.onChanged();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось проголосовать: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _appoint() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!CandidacyProvider.canAppoint(auth)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Назначение доступно только Айе')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Назначить на роль'),
        content: Text(
          'Назначить ${widget.candidacy.citizenName} '
          'на роль ${widget.candidacy.roleLabel}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Назначить'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _submitting = true);
    final provider = Provider.of<CandidacyProvider>(context, listen: false);

    try {
      await provider.appoint(auth, widget.candidacy.id);
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.candidacy.citizenName} назначен(а) '
            'на роль ${widget.candidacy.roleLabel}',
          ),
          backgroundColor: Colors.green,
        ),
      );
      widget.onChanged();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось назначить: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _voteLabel(String vote) {
    switch (vote) {
      case 'For':
        return 'За';
      case 'Against':
        return 'Против';
      case 'Abstain':
        return 'Воздержался';
      default:
        return vote;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.orange;
      case 'Approved':
        return Colors.green;
      case 'Appointed':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final c = widget.candidacy;
    final canVote = c.isActive && CandidacyProvider.canParticipate(auth);
    final canAppoint = c.isApproved && CandidacyProvider.canAppoint(auth);
    final progress = c.threshold > 0 ? c.votesFor / c.threshold : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(c.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    c.statusLabel,
                    style: TextStyle(
                      color: _statusColor(c.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(c.roleLabel),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              c.citizenName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Выдвинул(а): ${c.nominatorName}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            Text(
              'Создана: ${_formatDate(c.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Text(
              'Голоса «За»: ${c.votesFor} / ${c.threshold}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              color: c.isApproved || c.isAppointed
                  ? Colors.green
                  : Colors.deepPurple,
            ),
            const SizedBox(height: 8),
            Text(
              'Против: ${c.votesAgainst} · Воздержались: ${c.votesAbstain}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (c.approvedAt != null)
              Text(
                'Утверждена: ${_formatDate(c.approvedAt!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            if (c.appointedAt != null)
              Text(
                'Назначена: ${_formatDate(c.appointedAt!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            if (canVote) ...[
              const SizedBox(height: 16),
              const Text(
                'Ваш голос',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              ...Candidacy.voteChoices.map(
                (choice) => RadioListTile<String>(
                  title: Text(choice['label']!),
                  value: choice['value']!,
                  groupValue: _selectedVote,
                  dense: true,
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _selectedVote = value),
                ),
              ),
              if (_selectedVote != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting
                        ? null
                        : () => _vote(_selectedVote!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Проголосовать'),
                  ),
                ),
            ] else if (c.isActive) ...[
              const SizedBox(height: 12),
              Text(
                CandidacyProvider.participationBlockedReason(auth) ??
                    'Голосование недоступно',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade800,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (canAppoint) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _appoint,
                  icon: const Icon(Icons.military_tech),
                  label: const Text('Назначить на роль'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

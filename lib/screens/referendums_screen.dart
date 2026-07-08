import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/referendum.dart';
import '../providers/auth_provider.dart';
import '../providers/referendum_provider.dart';
import '../services/api_service.dart';
import '../widgets/initiate_referendum_dialog.dart';

class ReferendumsScreen extends StatefulWidget {
  const ReferendumsScreen({super.key});

  @override
  State<ReferendumsScreen> createState() => _ReferendumsScreenState();
}

class _ReferendumsScreenState extends State<ReferendumsScreen> {
  String? _statusFilter = 'Active';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await Provider.of<ReferendumProvider>(context, listen: false)
        .loadReferendums(status: _statusFilter);
  }

  Future<void> _announce() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!ReferendumProvider.canAnnounce(auth)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Объявление доступно только Айе')),
      );
      return;
    }

    await InitiateReferendumDialog.show(context);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final canAnnounce = ReferendumProvider.canAnnounce(auth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Активные референдумы'),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: canAnnounce
          ? FloatingActionButton.extended(
              onPressed: _announce,
              icon: const Icon(Icons.how_to_vote),
              label: const Text('Объявить'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: DropdownButtonFormField<String?>(
              value: _statusFilter,
              decoration: const InputDecoration(
                labelText: 'Статус',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Все')),
                DropdownMenuItem(value: 'Active', child: Text('Активные')),
                DropdownMenuItem(
                  value: 'Completed',
                  child: Text('Завершённые'),
                ),
              ],
              onChanged: (value) {
                setState(() => _statusFilter = value);
                _load();
              },
            ),
          ),
          Expanded(
            child: Consumer<ReferendumProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.referendums.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null && provider.referendums.isEmpty) {
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

                if (provider.referendums.isEmpty) {
                  return const Center(
                    child: Text('Нет референдумов по выбранным фильтрам'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.referendums.length,
                    itemBuilder: (context, index) {
                      return _ReferendumCard(
                        referendum: provider.referendums[index],
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

class _ReferendumCard extends StatefulWidget {
  final Referendum referendum;
  final VoidCallback onChanged;

  const _ReferendumCard({
    required this.referendum,
    required this.onChanged,
  });

  @override
  State<_ReferendumCard> createState() => _ReferendumCardState();
}

class _ReferendumCardState extends State<_ReferendumCard> {
  String? _selectedVote;
  bool _submitting = false;

  Future<void> _vote(String vote) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final provider = Provider.of<ReferendumProvider>(context, listen: false);
    final blocked = ReferendumProvider.participationBlockedReason(auth);
    if (blocked != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blocked)),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await provider.vote(auth, widget.referendum.id, vote);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _selectedVote = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Голос учтён: ${_voteLabel(vote)}')),
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

  String _voteLabel(String vote) {
    switch (vote) {
      case 'For':
        return 'За отмену';
      case 'Against':
        return 'Против отмены';
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
      case 'Completed':
        return Colors.green;
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
    final r = widget.referendum;
    final canVote = r.isActive && ReferendumProvider.canParticipate(auth);
    final totalVotes = r.votesFor + r.votesAgainst + r.votesAbstain;
    final forPercent = totalVotes > 0 ? r.votesFor / totalVotes : 0.0;

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
                    color: _statusColor(r.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    r.statusLabel,
                    style: TextStyle(
                      color: _statusColor(r.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              r.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              r.description,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 8),
            Chip(
              label: Text('Решение: ${r.targetDecision}'),
              visualDensity: VisualDensity.compact,
            ),
            Text(
              'Объявил(а): ${r.announcerName}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            Text(
              'Создан: ${_formatDate(r.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Text(
              'За отмену: ${r.votesFor} · Против: ${r.votesAgainst} · '
              'Воздержались: ${r.votesAbstain}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (totalVotes > 0) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: forPercent.clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade200,
                color: Colors.deepPurple,
              ),
            ],
            if (canVote) ...[
              const SizedBox(height: 16),
              const Text(
                'Ваш голос',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              ...Referendum.voteChoices.map(
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
            ] else if (r.isActive) ...[
              const SizedBox(height: 12),
              Text(
                ReferendumProvider.participationBlockedReason(auth) ??
                    'Голосование недоступно',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade800,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

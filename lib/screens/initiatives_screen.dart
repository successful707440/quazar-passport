import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/initiative.dart';
import '../providers/auth_provider.dart';
import '../providers/initiative_provider.dart';
import '../services/api_service.dart';
import '../widgets/propose_initiative_dialog.dart';

class InitiativesScreen extends StatefulWidget {
  const InitiativesScreen({super.key});

  @override
  State<InitiativesScreen> createState() => _InitiativesScreenState();
}

class _InitiativesScreenState extends State<InitiativesScreen> {
  String? _statusFilter = 'Proposed';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await Provider.of<InitiativeProvider>(context, listen: false)
        .loadInitiatives(status: _statusFilter);
  }

  Future<void> _propose() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final blocked = InitiativeProvider.participationBlockedReason(auth);
    if (blocked != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blocked)),
      );
      return;
    }

    await ProposeInitiativeDialog.show(context);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final canParticipate = InitiativeProvider.canParticipate(auth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Список инициатив'),
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
              onPressed: _propose,
              icon: const Icon(Icons.add),
              label: const Text('Выдвинуть'),
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
                DropdownMenuItem(
                  value: 'Proposed',
                  child: Text('На голосовании'),
                ),
                DropdownMenuItem(value: 'Passed', child: Text('Принятые')),
                DropdownMenuItem(
                  value: 'Rejected',
                  child: Text('Отклонённые'),
                ),
              ],
              onChanged: (value) {
                setState(() => _statusFilter = value);
                _load();
              },
            ),
          ),
          Expanded(
            child: Consumer<InitiativeProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.initiatives.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null && provider.initiatives.isEmpty) {
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

                if (provider.initiatives.isEmpty) {
                  return const Center(
                    child: Text('Нет инициатив по выбранным фильтрам'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.initiatives.length,
                    itemBuilder: (context, index) {
                      return _InitiativeCard(
                        initiative: provider.initiatives[index],
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

class _InitiativeCard extends StatefulWidget {
  final Initiative initiative;
  final VoidCallback onChanged;

  const _InitiativeCard({
    required this.initiative,
    required this.onChanged,
  });

  @override
  State<_InitiativeCard> createState() => _InitiativeCardState();
}

class _InitiativeCardState extends State<_InitiativeCard> {
  String? _selectedVote;
  bool _submitting = false;

  Future<void> _vote(String vote) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final provider = Provider.of<InitiativeProvider>(context, listen: false);
    final blocked = InitiativeProvider.participationBlockedReason(auth);
    if (blocked != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blocked)),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final updated = await provider.vote(auth, widget.initiative.id, vote);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _selectedVote = null;
      });
      final message = updated?.isPassed == true
          ? 'Голос учтён. Инициатива принята!'
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
      case 'Proposed':
        return Colors.orange;
      case 'Passed':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
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
    final i = widget.initiative;
    final canVote = i.isProposed && InitiativeProvider.canParticipate(auth);
    final progress = i.threshold > 0 ? i.votesFor / i.threshold : 0.0;

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
                    color: _statusColor(i.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    i.statusLabel,
                    style: TextStyle(
                      color: _statusColor(i.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              i.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              i.description,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 8),
            Text(
              'Автор: ${i.proposerName}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            Text(
              'Создана: ${_formatDate(i.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Text(
              'Голоса «За»: ${i.votesFor} / ${i.threshold}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              color: i.isPassed ? Colors.green : Colors.deepPurple,
            ),
            const SizedBox(height: 8),
            Text(
              'Против: ${i.votesAgainst} · Воздержались: ${i.votesAbstain}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (i.passedAt != null)
              Text(
                'Принята: ${_formatDate(i.passedAt!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            if (canVote) ...[
              const SizedBox(height: 16),
              const Text(
                'Ваш голос',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              ...Initiative.voteChoices.map(
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
            ] else if (i.isProposed) ...[
              const SizedBox(height: 12),
              Text(
                InitiativeProvider.participationBlockedReason(auth) ??
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

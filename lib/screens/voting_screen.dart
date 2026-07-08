import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vote.dart';
import '../providers/auth_provider.dart';
import '../providers/votes_provider.dart';

class VotingScreen extends StatefulWidget {
  const VotingScreen({super.key});

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<VotesProvider>(context, listen: false).loadVotes(auth);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VotesProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading &&
            provider.activeVotes.isEmpty &&
            provider.pastVotes.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null &&
            provider.activeVotes.isEmpty &&
            provider.pastVotes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                provider.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          );
        }

        return Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Активные', icon: Icon(Icons.how_to_vote)),
                Tab(text: 'История', icon: Icon(Icons.history)),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ActiveVotesList(provider: provider),
                  _PastVotesList(provider: provider),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActiveVotesList extends StatelessWidget {
  final VotesProvider provider;

  const _ActiveVotesList({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.activeVotes.isEmpty) {
      return const Center(child: Text('Нет активных голосований'));
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);

    return RefreshIndicator(
      onRefresh: () => provider.loadVotes(auth),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.activeVotes.length,
        itemBuilder: (context, index) {
          final vote = provider.activeVotes[index];
          return _VoteCard(vote: vote, isActive: true);
        },
      ),
    );
  }
}

class _PastVotesList extends StatelessWidget {
  final VotesProvider provider;

  const _PastVotesList({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.pastVotes.isEmpty) {
      return const Center(child: Text('Нет завершённых голосований'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.pastVotes.length,
      itemBuilder: (context, index) {
        final vote = provider.pastVotes[index];
        return _VoteCard(vote: vote, isActive: false);
      },
    );
  }
}

class _VoteCard extends StatefulWidget {
  final Vote vote;
  final bool isActive;

  const _VoteCard({required this.vote, required this.isActive});

  @override
  State<_VoteCard> createState() => _VoteCardState();
}

class _VoteCardState extends State<_VoteCard> {
  String? _selectedChoice;
  bool _isSubmitting = false;

  String get _timeRemaining {
    final duration = widget.vote.endTime.difference(DateTime.now());
    if (duration.isNegative) return 'Завершено';
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    return 'Осталось: ${days}д ${hours}ч ${minutes}м';
  }

  Future<void> _submitVote() async {
    if (_selectedChoice == null) return;

    setState(() => _isSubmitting = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final votesProvider = Provider.of<VotesProvider>(context, listen: false);

    final success = await votesProvider.submitVote(
      auth,
      widget.vote.id,
      _selectedChoice!,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Голос успешно учтён!' : 'Не удалось отправить голос',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (widget.isActive ? Colors.orange : Colors.grey)
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.isActive ? 'Активно' : 'Завершено',
                style: TextStyle(
                  color: widget.isActive ? Colors.orange : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.vote.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (widget.vote.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.vote.description,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ],
            if (widget.isActive) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.timer, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    _timeRemaining,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...Vote.choices.map((choice) {
                return RadioListTile<String>(
                  title: Text(choice['label']!),
                  value: choice['value']!,
                  groupValue: _selectedChoice,
                  onChanged: (value) {
                    setState(() => _selectedChoice = value);
                  },
                );
              }),
              if (_selectedChoice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitVote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSubmitting
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
                ),
            ],
          ],
        ),
      ),
    );
  }
}

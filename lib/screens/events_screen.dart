import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/events_provider.dart';
import '../providers/structure_provider.dart';
import '../models/event.dart';
import '../widgets/structure_card.dart';
import 'event_detail_screen.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final eventsProvider = Provider.of<EventsProvider>(context);
    final structureProvider = Provider.of<StructureProvider>(context);

    if (structureProvider.structure == null && !structureProvider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        structureProvider.loadStructure(auth);
      });
    }

    if (eventsProvider.isLoading && eventsProvider.events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          eventsProvider.loadEvents(auth),
          structureProvider.loadStructure(auth),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          if (structureProvider.structure != null)
            StructureCard(
              citizensCount:
                  structureProvider.structure!['citizens_count'] ?? 0,
              blocksCount: structureProvider.structure!['blocks_count'] ?? 0,
              eventsCount: structureProvider.structure!['events_count'] ?? 0,
              lawsCount: structureProvider.structure!['laws_count'] ?? 0,
              hasConstitution:
                  structureProvider.structure!['has_constitution'] ?? false,
              nodesCount: structureProvider.structure!['nodes_count'] ?? 0,
              pendingEvents:
                  structureProvider.structure!['pending_events'] ?? 0,
              version: structureProvider.structure!['version'] ?? '0.7.0',
            ),
          if (eventsProvider.error != null && eventsProvider.events.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                eventsProvider.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else if (eventsProvider.events.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'Нет событий в очереди\n\nЗдесь отображаются события, '
                  'ожидающие включения в блок',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...eventsProvider.events.map((event) => _EventCard(event: event)),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailScreen(event: event),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
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
                      color: event.confirmed
                          ? Colors.green.shade100
                          : Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.confirmed ? 'В блоке' : 'В очереди',
                      style: TextStyle(
                        fontSize: 11,
                        color: event.confirmed
                            ? Colors.green.shade900
                            : Colors.amber.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTypeColor(event.type).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getTypeText(event.type),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getTypeColor(event.type),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(event.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                event.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                event.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (event.initiator != null && event.initiator!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Инициатор: ${event.initiator}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inDays > 0) return '${difference.inDays} дн. назад';
    if (difference.inHours > 0) return '${difference.inHours} ч. назад';
    if (difference.inMinutes > 0) return '${difference.inMinutes} мин. назад';
    return 'только что';
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'LawAdded':
      case 'ConstitutionFullText':
        return Colors.blue;
      case 'CitizenAdded':
      case 'PassportIssued':
        return Colors.green;
      case 'PassportRevoked':
      case 'CitizenStatusChanged':
        return Colors.orange;
      case 'PeerListUpdate':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getTypeText(String type) {
    switch (type) {
      case 'LawAdded':
        return 'Закон';
      case 'ConstitutionFullText':
        return 'Конституция';
      case 'CitizenAdded':
        return 'Гражданин';
      case 'PassportIssued':
        return 'Паспорт';
      case 'PassportRevoked':
        return 'Аннулирование';
      case 'CitizenStatusChanged':
        return 'Статус';
      case 'PeerListUpdate':
        return 'Сеть';
      default:
        return type.isNotEmpty ? type : 'Событие';
    }
  }
}

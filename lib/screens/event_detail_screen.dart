import 'package:flutter/material.dart';
import '../models/event.dart';

class EventDetailScreen extends StatelessWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали события'),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getTypeColor(event.type).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getTypeText(event.type),
                style: TextStyle(
                  color: _getTypeColor(event.type),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              event.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${event.timestamp.day}.${event.timestamp.month}.${event.timestamp.year} '
                  '${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
            if (event.initiator != null && event.initiator!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Инициатор: ${event.initiator}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              event.description,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            if (event.id.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'ID: ${event.id}',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'LawAdded':
      case 'ConstitutionFullText':
        return Colors.blue;
      case 'CitizenAdded':
      case 'PassportIssued':
        return Colors.green;
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
      default:
        return type.isNotEmpty ? type : 'Событие';
    }
  }
}

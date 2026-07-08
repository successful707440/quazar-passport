import 'package:flutter/material.dart';

class StructureCard extends StatelessWidget {
  final int citizensCount;
  final int blocksCount;
  final int eventsCount;
  final int lawsCount;
  final bool hasConstitution;
  final int nodesCount;
  final int pendingEvents;
  final String version;

  const StructureCard({
    super.key,
    required this.citizensCount,
    required this.blocksCount,
    required this.eventsCount,
    required this.lawsCount,
    required this.hasConstitution,
    required this.nodesCount,
    this.pendingEvents = 0,
    required this.version,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text(
                  '📊 СТРУКТУРА КВАЗАРА',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🟢 Активно',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.people,
                    label: 'Граждане',
                    value: '$citizensCount',
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.gavel,
                    label: 'Законы',
                    value: '$lawsCount',
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.grid_view,
                    label: 'Блоки',
                    value: '$blocksCount',
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.event_note,
                    label: 'События',
                    value: '$eventsCount',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (hasConstitution) ...[
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '✅ Конституция принята',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade800,
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.warning, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '⚠️ Конституция не принята',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
                const Spacer(),
                if (pendingEvents > 0) ...[
                  Icon(Icons.hourglass_top, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    '$pendingEvents в очереди',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.dns, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  '$nodesCount узлов',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.sync, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  'v$version',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.deepPurple.shade400),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

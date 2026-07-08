import 'package:flutter/material.dart';

class InitiateReferendumDialog extends StatefulWidget {
  const InitiateReferendumDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const InitiateReferendumDialog(),
    );
  }

  @override
  State<InitiateReferendumDialog> createState() =>
      _InitiateReferendumDialogState();
}

class _InitiateReferendumDialogState extends State<InitiateReferendumDialog> {
  final _controller = TextEditingController();
  String _selectedDecision = 'Закон о налогах';

  static const _decisions = [
    'Закон о налогах',
    'Указ о назначении',
    'Решение Совета',
  ];

  void _submit() {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🗳️ Инициирование референдума...')),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Инициировать референдум'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedDecision,
            decoration: const InputDecoration(
              labelText: 'Решение для отмены',
              border: OutlineInputBorder(),
            ),
            items: _decisions
                .map(
                  (d) => DropdownMenuItem(value: d, child: Text(d)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedDecision = value);
              }
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Обоснование',
              border: OutlineInputBorder(),
              hintText: 'Почему это решение нужно отменить',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Инициировать'),
        ),
      ],
    );
  }
}

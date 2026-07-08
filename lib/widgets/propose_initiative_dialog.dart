import 'package:flutter/material.dart';

class ProposeInitiativeDialog extends StatefulWidget {
  const ProposeInitiativeDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ProposeInitiativeDialog(),
    );
  }

  @override
  State<ProposeInitiativeDialog> createState() =>
      _ProposeInitiativeDialogState();
}

class _ProposeInitiativeDialogState extends State<ProposeInitiativeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🗳️ Выдвижение инициативы...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Выдвинуть инициативу'),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Описание инициативы',
          border: OutlineInputBorder(),
          hintText: 'Опишите предложение для Совета граждан',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Выдвинуть'),
        ),
      ],
    );
  }
}

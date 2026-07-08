import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/referendum_provider.dart';
import '../services/api_service.dart';

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
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedDecision = 'Закон о налогах';
  bool _submitting = false;

  static const _decisions = [
    'Закон о налогах',
    'Указ о назначении',
    'Решение Совета',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните название и обоснование')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final provider = Provider.of<ReferendumProvider>(context, listen: false);

    setState(() => _submitting = true);

    try {
      await provider.announce(
        auth,
        title: title,
        description: description,
        targetDecision: _selectedDecision,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗳️ Референдум объявлен'),
          backgroundColor: Colors.green,
        ),
      );
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
          content: Text('Не удалось объявить референдум: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Инициировать референдум'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Название референдума',
                border: OutlineInputBorder(),
                hintText: 'Краткое название',
              ),
            ),
            const SizedBox(height: 16),
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
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _selectedDecision = value);
                      }
                    },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Обоснование',
                border: OutlineInputBorder(),
                hintText: 'Почему это решение нужно отменить',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Инициировать'),
        ),
      ],
    );
  }
}

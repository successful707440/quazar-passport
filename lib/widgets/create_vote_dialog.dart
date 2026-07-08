import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/votes_provider.dart';

class CreateVoteDialog extends StatefulWidget {
  const CreateVoteDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const CreateVoteDialog(),
    );
  }

  @override
  State<CreateVoteDialog> createState() => _CreateVoteDialogState();
}

class _CreateVoteDialogState extends State<CreateVoteDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _durationDays = 1;
  bool _isSubmitting = false;
  String? _error;

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
      setState(() => _error = 'Заполните название и описание');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final votes = Provider.of<VotesProvider>(context, listen: false);

    final success = await votes.createVote(
      auth,
      title: title,
      description: description,
      durationSecs: _durationDays * 86400,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Голосование создано'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _isSubmitting = false;
        _error = 'Не удалось создать голосование';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Создать голосование'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Описание',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _durationDays,
              decoration: const InputDecoration(
                labelText: 'Длительность',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 день')),
                DropdownMenuItem(value: 3, child: Text('3 дня')),
                DropdownMenuItem(value: 7, child: Text('7 дней')),
              ],
              onChanged: _isSubmitting
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _durationDays = value);
                      }
                    },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Создать'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/citizen.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'citizen_autocomplete_field.dart';

class AssignRoleDialog extends StatefulWidget {
  const AssignRoleDialog({super.key});

  static const _roles = <String, String>{
    'Citizen': 'Гражданин',
    'Judge': 'Судья',
    'Guardian': 'Охранник',
    'Aiya': 'Айя',
  };

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const AssignRoleDialog(),
    );
  }

  @override
  State<AssignRoleDialog> createState() => _AssignRoleDialogState();
}

class _AssignRoleDialogState extends State<AssignRoleDialog> {
  Citizen? _selected;
  String _newRole = 'Citizen';
  bool _submitting = false;
  String? _error;

  String _roleLabel(String? role) {
    if (role == null) return '—';
    return AssignRoleDialog._roles[role] ?? role;
  }

  Future<void> _submit() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final apiKey = auth.apiKey;
    final citizen = _selected;
    if (apiKey == null || citizen == null) return;

    if (citizen.role == _newRole) {
      setState(() => _error = 'У гражданина уже эта роль');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final updated = await ApiService.updateCitizenRole(
        apiKey,
        citizen.id,
        _newRole,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Роль ${updated.name} изменена на ${_roleLabel(updated.role)}. '
            'Ожидает включения в блок.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Не удалось назначить роль: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final apiKey = auth.apiKey ?? '';

    return AlertDialog(
      title: const Text('Назначить роль'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CitizenAutocompleteField(
                apiKey: apiKey,
                selected: _selected,
                labelText: 'Имя гражданина',
                hintText: 'Начните вводить имя',
                roleLabel: _roleLabel,
                statusLabel: _statusLabel,
                onSelected: (citizen) {
                  setState(() {
                    _selected = citizen;
                    _newRole = citizen?.role ?? 'Citizen';
                    _error = null;
                  });
                },
              ),
              if (_selected != null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _newRole,
                  decoration: const InputDecoration(
                    labelText: 'Новая роль',
                    border: OutlineInputBorder(),
                  ),
                  items: AssignRoleDialog._roles.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _newRole = value);
                          }
                        },
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submitting || _selected == null ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Назначить'),
        ),
      ],
    );
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'активен';
      case 'suspended':
        return 'приостановлен';
      case 'revoked':
        return 'лишён гражданства';
      default:
        return status;
    }
  }
}

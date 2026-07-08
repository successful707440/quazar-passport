import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/candidacy.dart';
import '../models/citizen.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'citizen_autocomplete_field.dart';

class NominateCandidateDialog extends StatefulWidget {
  const NominateCandidateDialog({super.key});

  static const _targetRoles = <String, String>{
    'Guardian': 'Охранник',
    'Judge': 'Судья',
    'Aiya': 'Айя',
  };

  static Future<Candidacy?> show(BuildContext context) {
    return showDialog<Candidacy?>(
      context: context,
      builder: (_) => const NominateCandidateDialog(),
    );
  }

  @override
  State<NominateCandidateDialog> createState() =>
      _NominateCandidateDialogState();
}

class _NominateCandidateDialogState extends State<NominateCandidateDialog> {
  Citizen? _selected;
  String _targetRole = 'Guardian';
  bool _submitting = false;
  String? _error;

  String _roleLabel(String? role) {
    if (role == null) return '—';
    return NominateCandidateDialog._targetRoles[role] ?? role;
  }

  Future<void> _submit() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final candidate = _selected;
    if (candidate == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final candidacy = await ApiService.nominateCandidate(
        auth.apiKey!,
        candidateId: candidate.id,
        targetRole: _targetRole,
      );
      if (!mounted) return;
      Navigator.of(context).pop(candidacy);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Кандидатура ${candidacy.citizenName} на роль '
            '${candidacy.roleLabel} выдвинута.',
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
        _error = 'Не удалось выдвинуть кандидатуру: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final apiKey = auth.apiKey ?? '';

    return AlertDialog(
      title: const Text('Выдвинуть кандидатуру'),
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
                labelText: 'Имя кандидата',
                hintText: 'Начните вводить имя',
                roleLabel: _roleLabel,
                statusLabel: _statusLabel,
                onSelected: (citizen) {
                  setState(() {
                    _selected = citizen;
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _targetRole,
                decoration: const InputDecoration(
                  labelText: 'Целевая роль',
                  border: OutlineInputBorder(),
                ),
                items: NominateCandidateDialog._targetRoles.entries
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
                          setState(() => _targetRole = value);
                        }
                      },
              ),
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
              : const Text('Выдвинуть'),
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

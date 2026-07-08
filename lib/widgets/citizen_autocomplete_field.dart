import 'dart:async';

import 'package:flutter/material.dart';

import '../models/citizen.dart';
import '../services/api_service.dart';

/// Поле выбора гражданина с автодополнением (T9).
///
/// Пустое поле при фокусе — список всех граждан; при вводе — поиск по имени.
class CitizenAutocompleteField extends StatefulWidget {
  const CitizenAutocompleteField({
    super.key,
    required this.apiKey,
    required this.onSelected,
    this.selected,
    this.labelText = 'Имя гражданина',
    this.hintText = 'Начните вводить имя',
    this.roleLabel,
    this.statusLabel,
  });

  final String apiKey;
  final Citizen? selected;
  final ValueChanged<Citizen?> onSelected;
  final String labelText;
  final String? hintText;
  final String Function(String? role)? roleLabel;
  final String Function(String status)? statusLabel;

  static const _itemExtent = 48.0;
  static const _visibleItems = 3;
  static const _dropdownMaxHeight = _itemExtent * _visibleItems;

  @override
  State<CitizenAutocompleteField> createState() =>
      _CitizenAutocompleteFieldState();
}

class _CitizenAutocompleteFieldState extends State<CitizenAutocompleteField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<Citizen> _suggestions = [];
  bool _loading = false;
  bool _showDropdown = false;
  String? _error;
  Timer? _debounce;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _syncSelectedText();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(CitizenAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected?.id != widget.selected?.id) {
      _syncSelectedText();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _syncSelectedText() {
    final name = widget.selected?.name ?? '';
    if (_controller.text != name) {
      _controller.text = name;
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _fetchSuggestions(_controller.text.trim());
    } else {
      setState(() => _showDropdown = false);
    }
  }

  void _onTextChanged(String value) {
    final selected = widget.selected;
    if (selected != null && value != selected.name) {
      widget.onSelected(null);
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _fetchSuggestions(value.trim());
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    final generation = ++_requestGeneration;

    setState(() {
      _loading = true;
      _showDropdown = true;
      _error = null;
    });

    try {
      final citizens = query.isEmpty
          ? await ApiService.listCitizens(widget.apiKey)
          : await ApiService.searchCitizens(widget.apiKey, query);

      if (!mounted || generation != _requestGeneration) return;

      citizens.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      setState(() {
        _suggestions = citizens;
        _loading = false;
        if (query.isNotEmpty && citizens.isEmpty) {
          _error = 'Гражданин не найден';
        }
      });
    } on ApiException catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _loading = false;
        _suggestions = [];
        _error = e.message;
      });
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _loading = false;
        _suggestions = [];
        _error = 'Ошибка поиска: $e';
      });
    }
  }

  void _selectCitizen(Citizen citizen) {
    _controller.text = citizen.name;
    widget.onSelected(citizen);
    setState(() {
      _showDropdown = false;
      _error = null;
    });
    _focusNode.unfocus();
  }

  String _roleLabel(String? role) {
    if (widget.roleLabel != null) return widget.roleLabel!(role);
    return role ?? '—';
  }

  String _statusLabel(String status) {
    if (widget.statusLabel != null) return widget.statusLabel!(status);
    return status;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.arrow_drop_down),
                    onPressed: () {
                      if (_focusNode.hasFocus && _showDropdown) {
                        _focusNode.unfocus();
                      } else {
                        _focusNode.requestFocus();
                        _fetchSuggestions(_controller.text.trim());
                      }
                    },
                  ),
          ),
          onChanged: _onTextChanged,
          onTap: () {
            if (!_showDropdown) {
              _fetchSuggestions(_controller.text.trim());
            }
          },
        ),
        if (_showDropdown &&
            (_loading || _suggestions.isNotEmpty || _error != null)) ...[
          const SizedBox(height: 4),
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(4),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: CitizenAutocompleteField._dropdownMaxHeight,
              ),
              child: _loading && _suggestions.isEmpty
                  ? const SizedBox(
                      height: CitizenAutocompleteField._itemExtent,
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : _suggestions.isEmpty
                      ? SizedBox(
                          height: CitizenAutocompleteField._itemExtent,
                          child: Center(
                            child: Text(
                              _error ?? 'Нет граждан',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: _error != null
                                        ? colorScheme.error
                                        : colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        )
                      : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemExtent: CitizenAutocompleteField._itemExtent,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final citizen = _suggestions[index];
                        final isSelected = widget.selected?.id == citizen.id;
                        return InkWell(
                          onTap: () => _selectCitizen(citizen),
                          child: Container(
                            color: isSelected
                                ? colorScheme.primaryContainer
                                    .withValues(alpha: 0.4)
                                : null,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  citizen.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Роль: ${_roleLabel(citizen.role)} · '
                                  '${_statusLabel(citizen.status)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/node_provider.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Map<String, dynamic>> _onlineCitizens = [];
  bool _loadingOnline = false;
  String? _onlineError;
  bool? _hasPassword;
  bool _checkingPassword = false;

  final _primaryController = TextEditingController();
  final _secondaryController = TextEditingController();
  bool _savingUrls = false;
  String? _urlSaveError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final nodes = Provider.of<NodeProvider>(context, listen: false);
        _primaryController.text = nodes.primaryUrl ?? '';
        _secondaryController.text = nodes.secondaryUrl ?? '';
        nodes.refreshReachableNodes();
        _loadOnlineCitizens();
        _checkPasswordStatus();
      }
    });
  }

  Future<void> _checkPasswordStatus() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.citizenName == null) return;

    setState(() => _checkingPassword = true);
    try {
      final has = await ApiService.checkHasPassword(auth.citizenName!);
      if (mounted) {
        setState(() {
          _hasPassword = has;
          _checkingPassword = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _checkingPassword = false);
      }
    }
  }

  Future<void> _showSetPasswordDialog() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscure = true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                _hasPassword == true ? 'Сменить пароль' : 'Задать пароль',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Новый пароль',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setDialogState(() => obscure = !obscure);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: obscure,
                    decoration: const InputDecoration(
                      labelText: 'Подтвердите пароль',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || !mounted) return;

    final password = passwordController.text;
    final confirm = confirmController.text;
    passwordController.dispose();
    confirmController.dispose();

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пароль должен быть не короче 6 символов'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пароли не совпадают'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final error = await auth.setPassword(password);
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _hasPassword = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Пароль сохранён'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
    super.dispose();
  }

  Future<void> _loadOnlineCitizens() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.apiKey == null) return;

    setState(() {
      _loadingOnline = true;
      _onlineError = null;
    });

    try {
      final citizens = await ApiService.getOnlineCitizens(auth.apiKey!);
      if (mounted) {
        setState(() {
          _onlineCitizens = citizens;
          _loadingOnline = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _onlineError = e.toString();
          _loadingOnline = false;
        });
      }
    }
  }

  Future<void> _refreshNodes() async {
    await Provider.of<NodeProvider>(context, listen: false).refreshReachableNodes();
  }

  Future<void> _saveServerUrls() async {
    final nodes = Provider.of<NodeProvider>(context, listen: false);

    setState(() {
      _savingUrls = true;
      _urlSaveError = null;
    });

    final error = await nodes.saveServerUrls(
      primary: _primaryController.text,
      secondary: _secondaryController.text,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _savingUrls = false;
        _urlSaveError = error;
      });
      return;
    }

    ApiService.syncActiveNode();
    await nodes.findAndSwitchToAvailable(showSwitching: false);
    await _refreshNodes();

    setState(() => _savingUrls = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Адреса серверов сохранены'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _resetServerUrls() async {
    final nodes = Provider.of<NodeProvider>(context, listen: false);
    await nodes.resetServerUrlsToDefaults();
    _primaryController.text = nodes.primaryUrl ?? '';
    _secondaryController.text = nodes.secondaryUrl ?? '';
    ApiService.syncActiveNode();
    await nodes.findAndSwitchToAvailable(showSwitching: false);
    await _refreshNodes();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Адреса сброшены к значениям по умолчанию')),
      );
    }
  }

  Future<void> _clearData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистка данных'),
        content: const Text(
          'Вы уверены, что хотите очистить все данные? '
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.clearAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Все данные очищены'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _refreshProfile() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.refreshCitizenProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль обновлён')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Биометрия',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Использовать биометрию'),
                    subtitle: const Text(
                      'Быстрый вход по отпечатку или PIN при следующем запуске',
                    ),
                    value: auth.useBiometrics,
                    onChanged: (value) async {
                      final error = await auth.setUseBiometrics(value);
                      if (error != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    activeThumbColor: Colors.deepPurple,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Пароль',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: Icon(
                      _hasPassword == true ? Icons.lock : Icons.lock_open,
                      color: _hasPassword == true
                          ? Colors.green
                          : Colors.orange,
                    ),
                    title: Text(
                      _checkingPassword
                          ? 'Проверка…'
                          : _hasPassword == true
                              ? 'Пароль задан'
                              : _hasPassword == false
                                  ? 'Пароль не задан'
                                  : 'Статус неизвестен',
                    ),
                    subtitle: const Text(
                      'Пароль используется для входа в приложение',
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: auth.isLoggedIn ? _showSetPasswordDialog : null,
                      icon: const Icon(Icons.password),
                      label: Text(
                        _hasPassword == true
                            ? 'Сменить пароль'
                            : 'Задать пароль',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Профиль',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.badge),
                    title: const Text('Имя'),
                    subtitle: Text(auth.citizenName ?? '—'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.fingerprint),
                    title: const Text('ID гражданина'),
                    subtitle: Text(
                      auth.citizenId ?? '—',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      auth.passportIssued ? Icons.verified : Icons.pending,
                      color: auth.passportIssued ? Colors.green : Colors.orange,
                    ),
                    title: const Text('Паспорт'),
                    subtitle: Text(
                      auth.passportIssued ? 'Выдан' : 'Не выдан',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _refreshProfile,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Обновить с сервера'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Граждане онлайн',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Обновить',
                        onPressed: _loadOnlineCitizens,
                      ),
                    ],
                  ),
                  if (_loadingOnline)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_onlineError != null)
                    Text(
                      _onlineError!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    )
                  else if (_onlineCitizens.isEmpty)
                    Text(
                      'Сейчас никто не в сети',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  else
                    ..._onlineCitizens.map(
                      (c) => ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.circle,
                          color: Colors.green.shade400,
                          size: 12,
                        ),
                        title: Text(c['name'] as String? ?? '—'),
                        subtitle: Text(
                          c['id'] as String? ?? '',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Опасная зона',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Очистка всех данных приведёт к выходу из системы '
                    'и удалению сохранённых учётных данных.',
                    style: TextStyle(fontSize: 14, color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _clearData,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Очистить все данные'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Адрес сервера',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Основной и резервный узлы Quazar. Перед сохранением проверяется /status.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _primaryController,
                    decoration: const InputDecoration(
                      labelText: 'Основной адрес',
                      hintText: 'http://192.168.0.20:8080',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enabled: !_savingUrls,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _secondaryController,
                    decoration: const InputDecoration(
                      labelText: 'Вторичный адрес (необязательно)',
                      hintText: 'http://192.168.0.20:8081',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link_off),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enabled: !_savingUrls,
                  ),
                  if (_urlSaveError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _urlSaveError!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _savingUrls ? null : _saveServerUrls,
                          icon: _savingUrls
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(_savingUrls ? 'Проверка…' : 'Сохранить'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _savingUrls ? null : _resetServerUrls,
                        child: const Text('Сброс'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Consumer<NodeProvider>(
                builder: (context, nodes, _) {
                  final reachable = nodes.reachableNodes;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Сервер',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (nodes.scanningNodes)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Обновить список узлов',
                              onPressed: _refreshNodes,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.dns),
                        title: const Text('Активный узел'),
                        subtitle: Text(ApiService.baseUrl),
                      ),
                      if (nodes.scanningNodes && reachable.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Проверка узлов…',
                            style: TextStyle(fontSize: 13),
                          ),
                        )
                      else if (reachable.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Нет доступных узлов',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade700,
                            ),
                          ),
                        )
                      else ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 4),
                          child: Text(
                            'Работающие узлы (${reachable.length})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        ...reachable.map(
                          (url) => ListTile(
                            dense: true,
                            leading: Icon(
                              url == nodes.activeNode
                                  ? Icons.check_circle
                                  : Icons.circle,
                              color: url == nodes.activeNode
                                  ? Colors.green
                                  : Colors.green.shade300,
                              size: 20,
                            ),
                            title: Text(
                              url,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: url == nodes.activeNode
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              url == nodes.activeNode
                                  ? 'Используется сейчас · ${nodes.labelFor(url)}'
                                  : nodes.labelFor(url),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('Версия приложения'),
                        subtitle: const Text('1.0.0'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

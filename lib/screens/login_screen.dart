import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/node_provider.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _obscureApiKey = true;
  String? _serverStatus;

  @override
  void initState() {
    super.initState();
    _checkServer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showStoredLoginError();
      _tryBiometricLogin();
    });
  }

  void _showStoredLoginError() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final message = auth.lastLoginError;
    if (message == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _checkServer() async {
    final nodes = Provider.of<NodeProvider>(context, listen: false);
    final ready = await nodes.ensureAvailableNode(showSwitching: false);
    ApiService.syncActiveNode();

    if (!mounted) return;

    if (!ready) {
      setState(() => _serverStatus = nodes.unavailableMessage);
      return;
    }

    final online = await ApiService.checkStatus();
    if (mounted) {
      setState(() {
        _serverStatus = online
            ? 'Узел ${nodes.nodeLabel} доступен'
            : nodes.unavailableMessage;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _nameController.text.trim(),
      _apiKeyController.text.trim(),
    );

    if (!success && mounted) {
      final message = authProvider.lastLoginError ??
          'Не удалось войти. Проверьте имя гражданина и API-ключ';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _tryBiometricLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.canUseBiometricLogin || auth.isLoading) return;

    final success = await auth.loginWithBiometrics();
    if (!success && mounted) {
      final name = auth.citizenName;
      if (name != null) {
        _nameController.text = name;
      }
      final message = auth.lastLoginError;
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final showBiometric = auth.canUseBiometricLogin;

    if (showBiometric &&
        auth.citizenName != null &&
        _nameController.text.isEmpty) {
      _nameController.text = auth.citizenName!;
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade900,
              Colors.deepPurple.shade500,
              Colors.purple.shade300,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          showBiometric
                              ? Icons.fingerprint
                              : Icons.assignment_ind,
                          size: 80,
                          color: Colors.deepPurple.shade700,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Quazar Passport',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade900,
                          ),
                        ),
                        if (_serverStatus != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _serverStatus!,
                            style: TextStyle(
                              fontSize: 12,
                              color: _serverStatus!.contains('доступен')
                                  ? Colors.green.shade700
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ],
                        if (showBiometric) ...[
                          const SizedBox(height: 20),
                          Text(
                            auth.citizenName != null
                                ? 'Войти как ${auth.citizenName}'
                                : 'Вход по биометрии',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: auth.isLoading
                                  ? null
                                  : _tryBiometricLogin,
                              icon: const Icon(Icons.fingerprint),
                              label: const Text('Войти по отпечатку'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(color: Colors.grey.shade400),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'или введите ключ',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          const SizedBox(height: 24),
                        ],
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Имя гражданина',
                            hintText: 'successful',
                            prefixIcon: Icon(Icons.badge),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Введите имя гражданина';
                            }
                            if (!RegExp(r'^[A-Za-z]+$')
                                .hasMatch(value.trim())) {
                              return 'Только латинские буквы';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _apiKeyController,
                          obscureText: _obscureApiKey,
                          decoration: InputDecoration(
                            labelText: 'API-ключ',
                            hintText: 'successful_app_key_2026',
                            prefixIcon: const Icon(Icons.key),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureApiKey
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureApiKey = !_obscureApiKey;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Введите API-ключ';
                            }
                            return null;
                          },
                        ),
                        if (!showBiometric) ...[
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: auth.isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple.shade700,
                                foregroundColor: Colors.white,
                              ),
                              child: auth.isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text('Войти'),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: auth.isLoading ? null : _handleLogin,
                            child: const Text('Войти с API-ключом'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

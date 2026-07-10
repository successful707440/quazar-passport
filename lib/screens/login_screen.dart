import 'dart:async';

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
  final _passwordController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureApiKey = true;
  bool _useApiKeyMode = false;
  String? _serverStatus;
  String? _loginErrorMessage;
  Timer? _loginErrorTimer;

  @override
  void initState() {
    super.initState();
    _checkServer();
    _nameController.addListener(_onLoginFieldChanged);
    _passwordController.addListener(_onLoginFieldChanged);
    _apiKeyController.addListener(_onLoginFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeStoredLoginError();
      _tryBiometricLogin();
    });
  }

  void _onLoginFieldChanged() {
    if (_loginErrorMessage != null) {
      _clearLoginError();
    }
  }

  void _consumeStoredLoginError() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final message = auth.lastLoginError;
    if (message == null || !mounted) return;

    auth.clearLoginError();
    _showLoginError(message);
  }

  void _showLoginError(String message) {
    _loginErrorTimer?.cancel();

    final suggestsApiKey = message.contains('Пароль не задан') ||
        message.contains('API-ключ');

    setState(() {
      _loginErrorMessage = suggestsApiKey
          ? '$message\nНажмите «Забыл пароль» для входа по API-ключу'
          : message;
    });

    _loginErrorTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _loginErrorMessage = null);
      }
    });
  }

  void _clearLoginError() {
    _loginErrorTimer?.cancel();
    _loginErrorTimer = null;
    if (_loginErrorMessage == null) return;
    setState(() => _loginErrorMessage = null);
  }

  void _switchLoginMode(bool useApiKey) {
    _clearLoginError();
    setState(() => _useApiKeyMode = useApiKey);
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
    _loginErrorTimer?.cancel();
    _nameController.removeListener(_onLoginFieldChanged);
    _passwordController.removeListener(_onLoginFieldChanged);
    _apiKeyController.removeListener(_onLoginFieldChanged);
    _nameController.dispose();
    _passwordController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _nameController.text.trim(),
      _passwordController.text,
    );

    if (!success && mounted) {
      final message = authProvider.lastLoginError ??
          'Не удалось войти. Проверьте имя гражданина и пароль';
      authProvider.clearLoginError();
      _showLoginError(message);
    }
  }

  Future<void> _handleApiKeyLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.loginWithApiKey(
      _nameController.text.trim(),
      _apiKeyController.text.trim(),
    );

    if (!success && mounted) {
      final message = authProvider.lastLoginError ??
          'Не удалось войти. Проверьте имя гражданина и API-ключ';
      authProvider.clearLoginError();
      _showLoginError(message);
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
        auth.clearLoginError();
        _showLoginError(message);
      }
    }
  }

  String? _validateCitizenName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите имя гражданина';
    }
    if (!RegExp(r'^[A-Za-z]+$').hasMatch(value.trim())) {
      return 'Только латинские буквы';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final showBiometric = auth.canUseBiometricLogin && !_useApiKeyMode;

    if (showBiometric &&
        auth.citizenName != null &&
        _nameController.text.isEmpty) {
      _nameController.text = auth.citizenName!;
    }

    return Scaffold(
      body: GestureDetector(
        onTap: _clearLoginError,
        behavior: HitTestBehavior.translucent,
        child: Container(
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
                              : _useApiKeyMode
                                  ? Icons.vpn_key
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
                        if (_useApiKeyMode) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Вход по API-ключу',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
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
                        if (_loginErrorMessage != null) ...[
                          const SizedBox(height: 12),
                          _buildLoginErrorBanner(),
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
                                  'или введите пароль',
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
                            prefixIcon: Icon(Icons.badge),
                            border: OutlineInputBorder(),
                          ),
                          validator: _validateCitizenName,
                        ),
                        const SizedBox(height: 16),
                        if (_useApiKeyMode) ...[
                          TextFormField(
                            controller: _apiKeyController,
                            obscureText: _obscureApiKey,
                            decoration: InputDecoration(
                              labelText: 'API-ключ',
                              prefixIcon: const Icon(Icons.vpn_key),
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
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed:
                                  auth.isLoading ? null : _handleApiKeyLogin,
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
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: auth.isLoading
                                ? null
                                : () => _switchLoginMode(false),
                            child: const Text('Войти по паролю'),
                          ),
                        ] else ...[
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Пароль',
                              prefixIcon: const Icon(Icons.lock),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Введите пароль';
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
                                onPressed:
                                    auth.isLoading ? null : _handlePasswordLogin,
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
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : () => _switchLoginMode(true),
                              child: const Text('Забыл пароль'),
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed:
                                  auth.isLoading ? null : _handlePasswordLogin,
                              child: const Text('Войти с паролем'),
                            ),
                            TextButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : () => _switchLoginMode(true),
                              child: const Text('Забыл пароль'),
                            ),
                          ],
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
    ),
    );
  }

  Widget _buildLoginErrorBanner() {
    final message = _loginErrorMessage;
    if (message == null) return const SizedBox.shrink();

    final suggestsApiKey = message.contains('API-ключ');

    return Material(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontSize: 13,
                ),
              ),
            ),
            if (suggestsApiKey)
              TextButton(
                onPressed: () => _switchLoginMode(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade800,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('API-ключ'),
              ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.red.shade700, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _clearLoginError,
              tooltip: 'Закрыть',
            ),
          ],
        ),
      ),
    );
  }
}

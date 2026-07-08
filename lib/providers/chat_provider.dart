import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'auth_provider.dart';

class ChatProvider extends ChangeNotifier {
  static const Duration refreshInterval = Duration(seconds: 10);

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  bool _isActive = false;
  Timer? _refreshTimer;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;

  static bool canSend(AuthProvider auth) {
    if (!auth.isLoggedIn || auth.apiKey == null) return false;
    if (Constants.isRevokedStatus(auth.status)) return false;
    if (auth.status.toLowerCase() == 'suspended') return false;
    return auth.status.toLowerCase() == 'active';
  }

  static String? sendBlockedReason(AuthProvider auth) {
    if (!auth.isLoggedIn) return 'Войдите в аккаунт';
    if (Constants.isRevokedStatus(auth.status)) {
      return Constants.accessDeniedRevoked;
    }
    if (auth.status.toLowerCase() == 'suspended') {
      return 'Отправка недоступна: статус приостановлен';
    }
    if (auth.status.toLowerCase() != 'active') {
      return 'Отправка недоступна: статус ${auth.status}';
    }
    return null;
  }

  Future<void> loadMessages(AuthProvider auth, {bool silent = false}) async {
    final apiKey = auth.apiKey;
    if (apiKey == null) return;

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _messages = await ApiService.listChatMessages(apiKey);
      _error = null;
    } on ApiException catch (e) {
      if (!silent) _error = e.message;
    } catch (e) {
      if (!silent) _error = 'Ошибка загрузки чата: $e';
      debugPrint('Error loading chat: $e');
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<bool> sendMessage(AuthProvider auth, String content) async {
    final apiKey = auth.apiKey;
    if (apiKey == null) return false;

    final blocked = sendBlockedReason(auth);
    if (blocked != null) {
      _error = blocked;
      notifyListeners();
      return false;
    }

    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;

    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final message = await ApiService.sendChatMessage(apiKey, trimmed);
      if (!_messages.any((m) => m.id == message.id)) {
        _messages = [..._messages, message];
      }
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Не удалось отправить: $e';
      debugPrint('Error sending chat message: $e');
      notifyListeners();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void startAutoRefresh(AuthProvider auth) {
    _isActive = true;
    loadMessages(auth);
    _scheduleRefresh(auth);
  }

  void _scheduleRefresh(AuthProvider auth) {
    _refreshTimer?.cancel();
    if (!_isActive) return;

    _refreshTimer = Timer(refreshInterval, () async {
      if (_isActive) {
        await loadMessages(auth, silent: true);
        _scheduleRefresh(auth);
      }
    });
  }

  void stopAutoRefresh() {
    _isActive = false;
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}

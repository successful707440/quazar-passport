import 'package:flutter/material.dart';

import '../models/initiative.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'auth_provider.dart';

class InitiativeProvider extends ChangeNotifier {
  List<Initiative> _initiatives = [];
  bool _isLoading = false;
  String? _error;
  String? _statusFilter;

  List<Initiative> get initiatives => _initiatives;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get statusFilter => _statusFilter;

  Future<void> loadInitiatives({String? status}) async {
    _statusFilter = status;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _initiatives = await ApiService.listInitiatives(status: status);
    } on ApiException catch (e) {
      _error = e.message;
      _initiatives = [];
    } catch (e) {
      _error = 'Ошибка загрузки инициатив: $e';
      _initiatives = [];
      debugPrint('Error loading initiatives: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Initiative?> propose(
    AuthProvider auth, {
    required String title,
    required String description,
  }) async {
    final apiKey = auth.apiKey;
    if (apiKey == null) return null;

    try {
      final initiative = await ApiService.proposeInitiative(
        apiKey,
        title: title,
        description: description,
      );
      await loadInitiatives(status: _statusFilter);
      return initiative;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<Initiative?> vote(
    AuthProvider auth,
    String initiativeId,
    String vote,
  ) async {
    final apiKey = auth.apiKey;
    if (apiKey == null) return null;

    try {
      final updated = await ApiService.voteOnInitiative(
        apiKey,
        initiativeId,
        vote,
      );
      await loadInitiatives(status: _statusFilter);
      return updated;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  static bool canParticipate(AuthProvider auth) {
    return auth.isLoggedIn &&
        auth.apiKey != null &&
        auth.status.toLowerCase() == 'active';
  }

  static String? participationBlockedReason(AuthProvider auth) {
    if (!auth.isLoggedIn) return 'Войдите в аккаунт';
    if (Constants.isRevokedStatus(auth.status)) {
      return Constants.accessDeniedRevoked;
    }
    if (auth.status.toLowerCase() == 'suspended') {
      return 'Действие недоступно: статус приостановлен';
    }
    if (auth.status.toLowerCase() != 'active') {
      return 'Действие недоступно: статус ${auth.status}';
    }
    return null;
  }
}

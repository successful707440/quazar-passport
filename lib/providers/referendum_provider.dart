import 'package:flutter/material.dart';

import '../models/referendum.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'auth_provider.dart';

class ReferendumProvider extends ChangeNotifier {
  List<Referendum> _referendums = [];
  bool _isLoading = false;
  String? _error;
  String? _statusFilter;

  List<Referendum> get referendums => _referendums;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get statusFilter => _statusFilter;

  Future<void> loadReferendums({String? status}) async {
    _statusFilter = status;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _referendums = await ApiService.listReferendums(status: status);
    } on ApiException catch (e) {
      _error = e.message;
      _referendums = [];
    } catch (e) {
      _error = 'Ошибка загрузки референдумов: $e';
      _referendums = [];
      debugPrint('Error loading referendums: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Referendum?> announce(
    AuthProvider auth, {
    required String title,
    required String description,
    required String targetDecision,
  }) async {
    final apiKey = auth.apiKey;
    if (apiKey == null) return null;

    try {
      final referendum = await ApiService.announceReferendum(
        apiKey,
        title: title,
        description: description,
        targetDecision: targetDecision,
      );
      await loadReferendums(status: _statusFilter);
      return referendum;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<Referendum?> vote(
    AuthProvider auth,
    String referendumId,
    String vote,
  ) async {
    final apiKey = auth.apiKey;
    if (apiKey == null) return null;

    try {
      final updated = await ApiService.voteOnReferendum(
        apiKey,
        referendumId,
        vote,
      );
      await loadReferendums(status: _statusFilter);
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

  static bool canAnnounce(AuthProvider auth) {
    return canParticipate(auth) &&
        (auth.role == 'Aiya' || auth.canVeto);
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

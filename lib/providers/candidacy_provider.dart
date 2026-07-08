import 'package:flutter/material.dart';

import '../models/candidacy.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'auth_provider.dart';

class CandidacyProvider extends ChangeNotifier {
  List<Candidacy> _candidacies = [];
  bool _isLoading = false;
  String? _error;
  String? _statusFilter;
  String? _roleFilter;

  List<Candidacy> get candidacies => _candidacies;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get statusFilter => _statusFilter;
  String? get roleFilter => _roleFilter;

  Future<void> loadCandidacies({
    String? status,
    String? targetRole,
  }) async {
    _statusFilter = status;
    _roleFilter = targetRole;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _candidacies = await ApiService.listCandidacies(
        status: status,
        targetRole: targetRole,
      );
    } on ApiException catch (e) {
      _error = e.message;
      _candidacies = [];
    } catch (e) {
      _error = 'Ошибка загрузки кандидатур: $e';
      _candidacies = [];
      debugPrint('Error loading candidacies: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Candidacy?> nominate(
    AuthProvider auth, {
    required String candidateId,
    required String targetRole,
  }) async {
    final apiKey = auth.apiKey;
    if (apiKey == null) return null;

    try {
      final candidacy = await ApiService.nominateCandidate(
        apiKey,
        candidateId: candidateId,
        targetRole: targetRole,
      );
      await loadCandidacies(
        status: _statusFilter,
        targetRole: _roleFilter,
      );
      return candidacy;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<Candidacy?> vote(
    AuthProvider auth,
    String candidacyId,
    String vote,
  ) async {
    final apiKey = auth.apiKey;
    if (apiKey == null) return null;

    try {
      final updated = await ApiService.voteForCandidate(
        apiKey,
        candidacyId,
        vote,
      );
      await loadCandidacies(
        status: _statusFilter,
        targetRole: _roleFilter,
      );
      return updated;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<Candidacy?> appoint(
    AuthProvider auth,
    String candidacyId,
  ) async {
    final apiKey = auth.apiKey;
    if (apiKey == null) return null;

    try {
      final updated = await ApiService.appointCandidate(apiKey, candidacyId);
      await loadCandidacies(
        status: _statusFilter,
        targetRole: _roleFilter,
      );
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

  static bool canAppoint(AuthProvider auth) {
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

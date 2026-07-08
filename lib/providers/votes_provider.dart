import 'package:flutter/material.dart';
import '../models/vote.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class VotesProvider extends ChangeNotifier {
  List<Vote> _activeVotes = [];
  List<Vote> _pastVotes = [];
  bool _isLoading = false;
  String? _error;

  List<Vote> get activeVotes => _activeVotes;
  List<Vote> get pastVotes => _pastVotes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadVotes(AuthProvider auth) async {
    if (auth.apiKey == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final allVotes = await ApiService.getVotes(auth.apiKey!);
      _activeVotes = allVotes.where((v) => v.isActive).toList();
      _pastVotes = allVotes.where((v) => !v.isActive).toList();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Ошибка загрузки голосований: $e';
      debugPrint('Error loading votes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitVote(
    AuthProvider auth,
    String voteId,
    String choice,
  ) async {
    if (auth.apiKey == null || auth.citizenId == null) return false;

    try {
      final success = await ApiService.submitVote(
        auth.apiKey!,
        voteId,
        auth.citizenId!,
        choice,
      );
      if (success) {
        await loadVotes(auth);
      }
      return success;
    } catch (e) {
      debugPrint('Error submitting vote: $e');
      return false;
    }
  }

  Future<bool> createVote(
    AuthProvider auth, {
    required String title,
    required String description,
    int durationSecs = 86400,
  }) async {
    if (auth.apiKey == null) return false;

    try {
      await ApiService.createVote(
        auth.apiKey!,
        title: title,
        description: description,
        durationSecs: durationSecs,
      );
      await loadVotes(auth);
      return true;
    } catch (e) {
      debugPrint('Error creating vote: $e');
      return false;
    }
  }

  Duration getTimeRemaining(DateTime endDate) {
    return endDate.difference(DateTime.now());
  }
}

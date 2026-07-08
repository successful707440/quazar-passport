import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class EventsProvider extends ChangeNotifier {
  List<Event> _events = [];
  bool _isLoading = false;
  String? _error;

  List<Event> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadEvents(AuthProvider auth) async {
    if (auth.apiKey == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _events = await ApiService.getEvents(auth.apiKey!);
      if (_events.isEmpty) {
        _error = 'Нет событий';
      } else {
        _error = null;
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Ошибка загрузки событий: $e';
      debugPrint('Error loading events: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

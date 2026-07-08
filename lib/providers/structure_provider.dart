import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class StructureProvider extends ChangeNotifier {
  Map<String, dynamic>? _structure;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get structure => _structure;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadStructure(AuthProvider auth) async {
    if (auth.apiKey == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _structure = await ApiService.getStructure(auth.apiKey!);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading structure: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

import 'package:flutter/material.dart';
import '../providers/node_provider.dart';
import '../services/api_service.dart';

class OnlineProvider extends ChangeNotifier {
  bool _serverOnline = false;
  int _blocksCount = 0;
  int _pendingEvents = 0;
  String _version = '';
  bool _isLoading = false;
  String? _error;
  bool _isActive = true;

  bool get serverOnline => _serverOnline;
  int get blocksCount => _blocksCount;
  int get pendingEvents => _pendingEvents;
  String get version => _version;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> refreshStatus() async {
    if (!_isActive) return;

    final nodes = NodeProvider.instance;

    _isLoading = true;
    notifyListeners();

    try {
      final status = await ApiService.getServerStatus();
      _applyStatus(status);
      _error = null;
    } catch (e) {
      if (nodes != null &&
          NodeProvider.isConnectionError(e) &&
          !nodes.allNodesOffline) {
        final switched = await nodes.findAndSwitchToAvailable(
          showSwitching: true,
        );
        if (switched) {
          try {
            final status = await ApiService.getServerStatus();
            _applyStatus(status);
            _error = null;
            return;
          } catch (retryError) {
            _error = retryError.toString();
          }
        }
      }

      _serverOnline = false;
      _error = e.toString();
      debugPrint('Error loading server status: $e');
    } finally {
      if (_isActive) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _applyStatus(Map<String, dynamic> status) {
    _serverOnline = true;
    _blocksCount = status['blocks'] as int? ?? 0;
    _pendingEvents = status['pending_events_local'] as int? ?? 0;
    _version = status['version'] as String? ?? '';
  }

  void startAutoRefresh() {
    _isActive = true;
    refreshStatus();
    _scheduleNextRefresh();
  }

  void _scheduleNextRefresh() {
    if (!_isActive) return;

    Future.delayed(const Duration(seconds: 30), () {
      if (_isActive) {
        refreshStatus();
        _scheduleNextRefresh();
      }
    });
  }

  void stopAutoRefresh() {
    _isActive = false;
  }

  @override
  void dispose() {
    _isActive = false;
    super.dispose();
  }
}

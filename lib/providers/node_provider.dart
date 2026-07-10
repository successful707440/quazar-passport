import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/native_http.dart';
import '../services/server_settings.dart';
import '../utils/config.dart';

class NodeProvider extends ChangeNotifier {
  static NodeProvider? _instance;

  static const Duration requestTimeout = Duration(seconds: 12);
  static const Duration unavailableTtl = Duration(seconds: 30);
  static const String _keyLastNode = 'last_active_node';
  static const String _keyDeadUntil = 'dead_nodes_until';

  /// Активный узел для API-запросов.
  static String get currentNode =>
      _instance?._currentNode ?? _instance?.knownNodes.first ?? Config.defaultPrimaryUrl;

  static NodeProvider? get instance => _instance;

  String? _currentNode;
  String? _primaryUrl;
  String? _secondaryUrl;
  bool _isSwitching = false;
  bool _isInitialized = false;
  bool _allNodesOffline = false;
  String _switchingMessage = 'Поиск доступного узла...';
  final Map<String, DateTime> _unavailableUntil = {};
  List<String> _reachableNodes = [];
  bool _scanningNodes = false;
  String? _lastCheckError;

  /// Список узлов: из настроек или значения по умолчанию.
  List<String> get knownNodes {
    return ServerSettings(
      primaryUrl: _primaryUrl,
      secondaryUrl: _secondaryUrl,
    ).knownNodes;
  }

  String? get primaryUrl => _primaryUrl ?? Config.defaultPrimaryUrl;
  String? get secondaryUrl => _secondaryUrl;

  String get activeNode => _currentNode ?? knownNodes.first;
  String? get lastCheckError => _lastCheckError;

  String get unavailableMessage {
    if (_lastCheckError != null) {
      return 'Узлы недоступны: $_lastCheckError';
    }
    return 'Узлы недоступны. Подключитесь к Wi‑Fi (192.168.0.x) и проверьте адреса в настройках';
  }
  bool get isSwitching => _isSwitching;
  bool get isInitialized => _isInitialized;
  bool get allNodesOffline => _allNodesOffline;
  String get switchingMessage => _switchingMessage;
  List<String> get reachableNodes => List.unmodifiable(_reachableNodes);
  bool get scanningNodes => _scanningNodes;

  String get nodeLabel {
    try {
      final uri = Uri.parse(activeNode);
      if (uri.port != 80 && uri.port != 443) {
        return ':${uri.port}';
      }
      return uri.host;
    } catch (_) {
      return activeNode;
    }
  }

  NodeProvider() {
    _instance = this;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadPersistedState();
    await findAndSwitchToAvailable(showSwitching: true);
    _isInitialized = true;
    notifyListeners();
  }

  /// Перед логином или API-запросом — убедиться, что выбран живой узел.
  Future<bool> ensureAvailableNode({bool showSwitching = true}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isMarkedUnavailable(activeNode) && await checkNode(activeNode)) {
      _allNodesOffline = false;
      return true;
    }

    markUnavailable(activeNode);
    return findAndSwitchToAvailable(showSwitching: showSwitching);
  }

  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = await ServerSettings.load();
    _primaryUrl = settings.primaryUrl;
    _secondaryUrl = settings.secondaryUrl;

    final last = prefs.getString(_keyLastNode);
    if (last != null && knownNodes.contains(last)) {
      _currentNode = last;
    } else {
      _currentNode = knownNodes.first;
    }

    final deadJson = prefs.getString(_keyDeadUntil);
    if (deadJson == null) return;

    try {
      final map = jsonDecode(deadJson) as Map<String, dynamic>;
      final now = DateTime.now();
      for (final entry in map.entries) {
        final until = DateTime.fromMillisecondsSinceEpoch(entry.value as int);
        if (now.isBefore(until)) {
          _unavailableUntil[entry.key] = until;
        }
      }
    } catch (_) {
      // ignore corrupt cache
    }
  }

  Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentNode != null) {
        await prefs.setString(_keyLastNode, _currentNode!);
      }
      final dead = <String, int>{
        for (final e in _unavailableUntil.entries)
          e.key: e.value.millisecondsSinceEpoch,
      };
      await prefs.setString(_keyDeadUntil, jsonEncode(dead));
    } catch (e) {
      debugPrint('NodeProvider persist error: $e');
    }
  }

  /// Нормализует URL: добавляет http:// при отсутствии схемы, убирает trailing slash.
  static String _normalizeUrl(String raw) => ServerSettings.normalizeUrl(raw);

  /// Проверяет формат URL.
  static String? validateUrlFormat(String raw) =>
      ServerSettings.validateUrlFormat(raw);

  /// Сохраняет адреса серверов после проверки /status.
  /// Возвращает null при успехе, иначе текст ошибки.
  Future<String?> saveServerUrls({
    required String primary,
    String? secondary,
  }) async {
    final primaryNorm = _normalizeUrl(primary);
    final formatError = validateUrlFormat(primaryNorm);
    if (formatError != null) return formatError;

    String? secondaryNorm;
    if (secondary != null && secondary.trim().isNotEmpty) {
      secondaryNorm = _normalizeUrl(secondary);
      final secError = validateUrlFormat(secondaryNorm);
      if (secError != null) return secError;
      if (secondaryNorm == primaryNorm) {
        return 'Вторичный адрес не должен совпадать с основным';
      }
    }

    if (!await checkNode(primaryNorm)) {
      return _lastCheckError ?? 'Основной сервер недоступен';
    }

    if (secondaryNorm != null && !await checkNode(secondaryNorm)) {
      return 'Вторичный сервер недоступен: ${_lastCheckError ?? "нет ответа"}';
    }

    await ServerSettings.save(primary: primaryNorm, secondary: secondaryNorm);

    _primaryUrl = primaryNorm;
    _secondaryUrl = secondaryNorm;
    _unavailableUntil.clear();

    if (_currentNode == null || !knownNodes.contains(_currentNode)) {
      _currentNode = primaryNorm;
    }

    await _persistState();
    notifyListeners();
    return null;
  }

  /// Сбрасывает адреса к значениям по умолчанию из config.dart.
  Future<void> resetServerUrlsToDefaults() async {
    await ServerSettings.clear();
    _primaryUrl = null;
    _secondaryUrl = null;
    _currentNode = Config.defaultPrimaryUrl;
    _unavailableUntil.clear();
    await _persistState();
    notifyListeners();
  }

  void markUnavailable(String node) {
    _unavailableUntil[node] = DateTime.now().add(unavailableTtl);
    unawaited(_persistState());
  }

  void markAvailable(String node) {
    _unavailableUntil.remove(node);
    unawaited(_persistState());
  }

  bool _isMarkedUnavailable(String node) {
    final until = _unavailableUntil[node];
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _unavailableUntil.remove(node);
      unawaited(_persistState());
      return false;
    }
    return true;
  }

  Future<bool> checkNode(String baseUrl) async {
    try {
      final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/status');
      final response = await NativeHttp.get(
        uri,
        headers: {'Content-Type': 'application/json'},
        timeout: requestTimeout,
      );

      if (response.statusCode != 200) {
        _lastCheckError = 'HTTP ${response.statusCode} от ${_nodeShortLabel(baseUrl)}';
        debugPrint('NodeProvider checkNode $baseUrl: $_lastCheckError');
        return false;
      }

      final bodyText = response.body;
      if (bodyText.isEmpty) {
        _lastCheckError =
            'Пустой ответ от ${_nodeShortLabel(baseUrl)} — проверьте адрес узла';
        debugPrint('NodeProvider checkNode $baseUrl: $_lastCheckError');
        return false;
      }

      Map<String, dynamic> body;
      try {
        final decoded = jsonDecode(bodyText);
        if (decoded is! Map<String, dynamic>) {
          _lastCheckError = 'Неверный JSON от ${_nodeShortLabel(baseUrl)}';
          debugPrint('NodeProvider checkNode $baseUrl: $_lastCheckError');
          return false;
        }
        body = decoded;
      } on FormatException {
        _lastCheckError = 'Неверный JSON от ${_nodeShortLabel(baseUrl)}';
        debugPrint('NodeProvider checkNode $baseUrl: $_lastCheckError');
        return false;
      }

      if (body['status'] != 'success') {
        _lastCheckError = 'Статус ${body['status']} от ${_nodeShortLabel(baseUrl)}';
        debugPrint('NodeProvider checkNode $baseUrl: $_lastCheckError');
        return false;
      }

      _lastCheckError = null;
      return true;
    } on TimeoutException {
      _lastCheckError =
          'Таймаут ${_nodeShortLabel(baseUrl)} — проверьте Wi‑Fi (та же сеть, что ПК) и отключите мобильный интернет';
      debugPrint('NodeProvider checkNode $baseUrl: $_lastCheckError');
      return false;
    } on SocketException catch (e) {
      _lastCheckError =
          '${e.message} (${_nodeShortLabel(baseUrl)}) — нужен Wi‑Fi в той же сети';
      debugPrint('NodeProvider checkNode $baseUrl: $_lastCheckError');
      return false;
    } catch (e) {
      _lastCheckError = '$e (${_nodeShortLabel(baseUrl)})';
      debugPrint('NodeProvider checkNode $baseUrl: $_lastCheckError');
      return false;
    }
  }

  /// Проверяет все knownNodes и возвращает только отвечающие на /status.
  Future<List<String>> refreshReachableNodes() async {
    _scanningNodes = true;
    notifyListeners();

    try {
      final checks = await Future.wait(
        knownNodes.map((node) async {
          final ok = await checkNode(node);
          return (node, ok);
        }),
      );

      _reachableNodes = checks
          .where((entry) => entry.$2)
          .map((entry) => entry.$1)
          .toList();

      for (final entry in checks) {
        if (entry.$2) {
          markAvailable(entry.$1);
        }
      }

      notifyListeners();
      return _reachableNodes;
    } finally {
      _scanningNodes = false;
      notifyListeners();
    }
  }

  String labelFor(String node) => _nodeShortLabel(node);

  Future<bool> findAndSwitchToAvailable({bool showSwitching = true}) async {
    if (showSwitching) {
      _isSwitching = true;
      _switchingMessage = 'Поиск доступного узла...';
      notifyListeners();
    }

    try {
      final ordered = _orderedNodes();

      for (final node in ordered) {
        if (_isMarkedUnavailable(node)) continue;

        _switchingMessage = 'Проверка ${_nodeShortLabel(node)}...';
        notifyListeners();

        if (await checkNode(node)) {
          markAvailable(node);
          _currentNode = node;
          _allNodesOffline = false;
          await _persistState();
          notifyListeners();
          return true;
        }

        markUnavailable(node);
      }

      _allNodesOffline = true;
      notifyListeners();
      return false;
    } finally {
      if (showSwitching) {
        _isSwitching = false;
        notifyListeners();
      }
    }
  }

  List<String> _orderedNodes() {
    final current = activeNode;
    final nodes = knownNodes;
    final startIndex = nodes.indexOf(current);
    if (startIndex < 0) return List<String>.from(nodes);

    return [
      ...nodes.skip(startIndex),
      ...nodes.take(startIndex),
    ];
  }

  Future<bool> handleConnectionFailure(String failedNode) async {
    markUnavailable(failedNode);
    return findAndSwitchToAvailable(showSwitching: true);
  }

  /// Устанавливает активный узел после успешного входа.
  Future<void> selectActiveNode(String node) async {
    if (!knownNodes.contains(node)) return;
    _currentNode = node;
    _allNodesOffline = false;
    markAvailable(node);
    await _persistState();
    notifyListeners();
  }

  List<String> get nodesForLogin => _orderedNodes();

  /// Узлы для повторных запросов: сначала активный, затем остальные.
  List<String> get nodesForFailover => _orderedNodes();

  static bool isConnectionError(Object error) {
    if (error is TimeoutException) return true;
    if (error is SocketException) return true;
    if (error is http.ClientException) return true;
    if (error is HandshakeException) return true;
    if (error is HttpException) return true;
    if (error is IOException) return true;

    final message = error.toString().toLowerCase();
    if (message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('connection closed') ||
        message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        message.contains('timed out') ||
        message.contains('software caused connection abort')) {
      return true;
    }

    return false;
  }

  String _nodeShortLabel(String node) {
    try {
      final uri = Uri.parse(node);
      if (uri.port != 80 && uri.port != 443) return ':${uri.port}';
      return uri.host;
    } catch (_) {
      return node;
    }
  }

  @override
  void dispose() {
    if (_instance == this) {
      _instance = null;
    }
    super.dispose();
  }
}

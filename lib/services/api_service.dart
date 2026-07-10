import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'native_http.dart';
import '../models/api_response.dart';
import '../models/initiative.dart';
import '../models/referendum.dart';
import '../models/candidacy.dart';
import '../models/chat_message.dart';
import '../models/exchange.dart';
import '../models/citizen.dart';
import '../models/event.dart';
import '../models/svod_service.dart';
import '../models/vote.dart';
import '../providers/node_provider.dart';
import '../utils/config.dart';
import '../utils/constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  static String _baseUrl = NodeProvider.currentNode;

  /// Синхронизируется с NodeProvider после переключения узла.
  static String get baseUrl => _baseUrl;

  static void syncActiveNode() {
    _baseUrl = NodeProvider.currentNode;
  }

  static bool _isAuthError(Object error) {
    return error is ApiException &&
        (error.statusCode == 401 || error.statusCode == 403);
  }

  /// Перебирает узлы: при 401/403 — failover (ключ может быть на другом узле),
  /// при сетевой ошибке — помечает узел недоступным и пробует следующий.
  static Future<T> _withFailover<T>(
    Future<T> Function(String baseUrl) request,
  ) async {
    final provider = NodeProvider.instance;
    final nodes = provider?.nodesForFailover ?? Config.defaultKnownNodes;
    Object? lastError;

    for (final node in nodes) {
      try {
        final result = await request(node);
        if (provider != null && provider.activeNode != node) {
          await provider.selectActiveNode(node);
        }
        syncActiveNode();
        return result;
      } catch (e) {
        lastError = e;
        if (_isAuthError(e)) {
          continue;
        }
        if (NodeProvider.isConnectionError(e)) {
          provider?.markUnavailable(node);
          continue;
        }
        rethrow;
      }
    }

    if (lastError != null) throw lastError;
    throw ApiException('Нет доступных узлов');
  }

  static Map<String, String> _authHeaders(String apiKey) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

  static Future<ApiResponse> _parseResponse(http.Response response) async {
    final body = response.body;
    if (body.isEmpty) {
      if (response.statusCode == 401) {
        throw ApiException('Неверный API-ключ', statusCode: 401);
      }
      if (response.statusCode == 403) {
        throw ApiException('Доступ запрещён', statusCode: 403);
      }
      if (response.statusCode >= 502 && response.statusCode <= 504) {
        throw http.ClientException(
          'Узел недоступен (${response.statusCode})',
        );
      }
      throw ApiException('Пустой ответ сервера (${response.statusCode})',
          statusCode: response.statusCode);
    }

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw ApiException(
          'Неожиданный ответ сервера',
          statusCode: response.statusCode,
        );
      }
      json = decoded;
    } catch (_) {
      final text = body.trim();
      if (text.contains('svod_code')) {
        throw ApiException(
          'Выберите услугу из Свода',
          statusCode: response.statusCode,
        );
      }
      throw ApiException(
        text.length > 180 ? '${text.substring(0, 180)}…' : text,
        statusCode: response.statusCode,
      );
    }
    final apiResponse = ApiResponse.fromJson(json);

    if (!apiResponse.isSuccess) {
      throw ApiException(
        apiResponse.error ?? 'Ошибка сервера',
        statusCode: response.statusCode,
      );
    }

    return apiResponse;
  }

  static Future<ApiResponse> _get(
    String path, {
    String? apiKey,
    Map<String, String>? query,
  }) async {
    return _withFailover((baseUrl) async {
      final uri = Uri.parse('$baseUrl$path').replace(
        queryParameters: query,
      );
      final headers = apiKey != null
          ? _authHeaders(apiKey)
          : {'Content-Type': 'application/json'};

      final response = await NativeHttp.get(
        uri,
        headers: headers,
        timeout: NodeProvider.requestTimeout,
      );
      return _parseResponse(response);
    });
  }


  static Future<ApiResponse> _post(
    String path, {
    required String apiKey,
    Map<String, dynamic>? body,
  }) async {
    return _withFailover((baseUrl) async {
      final response = await NativeHttp.post(
        Uri.parse('$baseUrl$path'),
        headers: _authHeaders(apiKey),
        body: body != null ? jsonEncode(body) : null,
        timeout: NodeProvider.requestTimeout,
      );

      return _parseResponse(response);
    });
  }

  static Future<ApiResponse> _delete(
    String path, {
    required String apiKey,
  }) async {
    return _withFailover((baseUrl) async {
      final response = await NativeHttp.delete(
        Uri.parse('$baseUrl$path'),
        headers: _authHeaders(apiKey),
        timeout: NodeProvider.requestTimeout,
      );
      return _parseResponse(response);
    });
  }

  static Future<ApiResponse> _patch(
    String path, {
    required String apiKey,
    required Map<String, dynamic> body,
  }) async {
    return _withFailover((baseUrl) async {
      final response = await NativeHttp.patch(
        Uri.parse('$baseUrl$path'),
        headers: _authHeaders(apiKey),
        body: jsonEncode(body),
        timeout: NodeProvider.requestTimeout,
      );
      return _parseResponse(response);
    });
  }

  static Future<List<Citizen>> listCitizens(String apiKey) async {
    final response = await _get(
      Constants.endpointCitizenList,
      apiKey: apiKey,
    );
    return _extractCitizens(response.data);
  }

  static Future<List<Citizen>> searchCitizens(
    String apiKey,
    String query,
  ) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final response = await _get(
      Constants.endpointCitizenSearch,
      apiKey: apiKey,
      query: {'q': q},
    );
    return _extractCitizens(response.data);
  }

  /// PATCH /citizen/:id/role — только Айя; событие уходит в pending.
  static Future<Citizen> updateCitizenRole(
    String apiKey,
    String citizenId,
    String role,
  ) async {
    final response = await _patch(
      '${Constants.endpointCitizen}/$citizenId/role',
      apiKey: apiKey,
      body: {'role': role},
    );
    return Citizen.fromJson(response.data as Map<String, dynamic>);
  }

  /// Вход по паролю: POST /auth/login → api_key для дальнейших запросов.
  static Future<Map<String, dynamic>> loginWithPassword(
    String citizenName,
    String password,
  ) async {
    final provider = NodeProvider.instance;
    final nodes = provider?.nodesForLogin ?? Config.defaultKnownNodes;
    final trimmedName = citizenName.trim();
    Object? lastError;

    for (final baseUrl in nodes) {
      try {
        final uri = Uri.parse('$baseUrl${Constants.endpointAuthLogin}');
        final response = await NativeHttp.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': trimmedName,
            'password': password.trim(),
          }),
          timeout: NodeProvider.requestTimeout,
        );

        final apiResponse = await _parseResponse(response);
        final data = apiResponse.data;
        if (data is! Map<String, dynamic>) {
          throw ApiException('Неожиданный ответ сервера');
        }

        if (provider != null && provider.activeNode != baseUrl) {
          await provider.selectActiveNode(baseUrl);
        }
        syncActiveNode();
        return data;
      } on ApiException catch (e) {
        lastError = e;
        if (NodeProvider.isConnectionError(e)) {
          provider?.markUnavailable(baseUrl);
          continue;
        }
        rethrow;
      } catch (e) {
        lastError = e;
        if (NodeProvider.isConnectionError(e)) {
          provider?.markUnavailable(baseUrl);
          continue;
        }
        rethrow;
      }
    }

    if (lastError != null) throw lastError;
    throw ApiException('Нет доступных узлов для входа');
  }

  /// Установка или смена пароля (требуется API-ключ гражданина).
  static Future<void> setPassword(String apiKey, String password) async {
    await _post(
      Constants.endpointAuthSetPassword,
      apiKey: apiKey,
      body: {'password': password.trim()},
    );
  }

  /// Проверка, задан ли пароль у гражданина (публичный эндпоинт).
  static Future<bool> checkHasPassword(String citizenName) async {
    final response = await _get(
      Constants.endpointAuthCheck,
      query: {'name': citizenName.trim()},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) return false;
    return data['has_password'] as bool? ?? false;
  }

  /// Вход: перебирает все узлы — ключ может быть только на одном из них.
  static Future<Citizen> login(String citizenName, String apiKey) async {
    final provider = NodeProvider.instance;
    final nodes = provider?.nodesForLogin ?? Config.defaultKnownNodes;
    final trimmedName = citizenName.trim();

    var authRejected = false;
    var citizenMissing = false;
    var connectionFailed = false;
    Object? lastError;

    for (final baseUrl in nodes) {
      try {
        final response = await _getRaw(
          baseUrl,
          Constants.endpointCitizenSearch,
          apiKey: apiKey,
          query: {'q': trimmedName},
        );

        final citizens = _extractCitizens(response.data);
        Citizen? citizen;
        for (final c in citizens) {
          if (c.name.toLowerCase() == trimmedName.toLowerCase()) {
            citizen = c;
            break;
          }
        }

        if (citizen == null) {
          citizenMissing = true;
          continue;
        }

        if (Constants.isRevokedStatus(citizen.status)) {
          throw ApiException(Constants.accessDeniedRevoked);
        }

        if (provider != null) {
          await provider.selectActiveNode(baseUrl);
        }
        syncActiveNode();
        return citizen;
      } on ApiException catch (e) {
        lastError = e;
        if (e.statusCode == 401 || e.statusCode == 403) {
          authRejected = true;
          continue;
        }
        if (NodeProvider.isConnectionError(e)) {
          connectionFailed = true;
          provider?.markUnavailable(baseUrl);
          continue;
        }
        rethrow;
      } catch (e) {
        lastError = e;
        if (NodeProvider.isConnectionError(e)) {
          connectionFailed = true;
          provider?.markUnavailable(baseUrl);
          continue;
        }
        rethrow;
      }
    }

    if (authRejected && !citizenMissing) {
      throw ApiException('Неверный API-ключ', statusCode: 401);
    }
    if (citizenMissing && !authRejected) {
      throw ApiException('Гражданин «$trimmedName» не найден');
    }
    if (authRejected && citizenMissing) {
      throw ApiException(
        'Неверный API-ключ или гражданин «$trimmedName» не найден',
        statusCode: 401,
      );
    }
    if (connectionFailed) {
      throw ApiException(
        'Узлы недоступны. Проверьте сеть и адреса узлов в настройках',
      );
    }
    if (lastError != null) throw lastError;
    throw ApiException('Нет доступных узлов для входа');
  }

  static Future<ApiResponse> _getRaw(
    String baseUrl,
    String path, {
    String? apiKey,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = apiKey != null
        ? _authHeaders(apiKey)
        : {'Content-Type': 'application/json'};

    final response = await NativeHttp.get(
      uri,
      headers: headers,
      timeout: NodeProvider.requestTimeout,
    );
    return _parseResponse(response);
  }

  static Future<Citizen> getCitizen(String apiKey, String citizenId) async {
    final response = await _get(
      '${Constants.endpointCitizen}/$citizenId',
      apiKey: apiKey,
    );
    return Citizen.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<bool> sendOnlineStatus(
    String apiKey,
    String citizenId,
    bool isOnline,
  ) async {
    final endpoint =
        isOnline ? Constants.endpointOnline : Constants.endpointOffline;
    await _post(
      endpoint,
      apiKey: apiKey,
      body: {'citizen_id': citizenId},
    );
    return true;
  }

  static Future<Map<String, dynamic>> getServerStatus() async {
    final response = await _get(Constants.endpointStatus);
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<bool> checkStatus() async {
    try {
      await getServerStatus();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// События в очереди — ещё не включены в блок (GET /events).
  static Future<List<Event>> getPendingEvents(
    String apiKey, {
    int limit = 50,
  }) async {
    final response = await _get(Constants.endpointEvents, apiKey: apiKey);
    final data = response.data;

    final raw = data is List
        ? data
        : (data is Map<String, dynamic> ? data['events'] as List? : null) ?? [];

    final events = raw
        .whereType<Map<String, dynamic>>()
        .map(Event.fromJson)
        .toList();

    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (events.length > limit) {
      return events.sublist(0, limit);
    }
    return events;
  }

  /// События в очереди (алиас getPendingEvents).
  static Future<List<Event>> getEvents(String apiKey, {int limit = 50}) async {
    return getPendingEvents(apiKey, limit: limit);
  }

  /// Подтверждённые события из блокчейна (GET /blocks).
  static Future<List<Event>> getConfirmedEvents(
    String apiKey, {
    int limit = 50,
  }) async {
    final response = await _get(Constants.endpointBlocks, apiKey: apiKey);
    final blocks = response.data as List<dynamic>? ?? [];

    final events = <Event>[];
    for (final block in blocks) {
      if (block is! Map<String, dynamic>) continue;
      final blockEvents = block['events'] as List<dynamic>? ?? [];
      for (final event in blockEvents) {
        if (event is Map<String, dynamic>) {
          events.add(Event.fromJson(event, confirmed: true));
        }
      }
    }

    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (events.length > limit) {
      return events.sublist(0, limit);
    }
    return events;
  }

  static Future<List<Map<String, dynamic>>> getOnlineCitizens(
    String apiKey,
  ) async {
    final response = await _get(
      Constants.endpointCitizensOnline,
      apiKey: apiKey,
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) return [];
    final raw = data['citizens'] as List<dynamic>? ?? [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  static Future<Vote> createVote(
    String apiKey, {
    required String title,
    required String description,
    int durationSecs = 86400,
  }) async {
    final response = await _post(
      Constants.endpointVotes,
      apiKey: apiKey,
      body: {
        'title': title,
        'description': description,
        'duration_secs': durationSecs,
      },
    );
    final data = response.data as Map<String, dynamic>? ?? {};
    return Vote(
      id: data['vote_id'] as String? ?? '',
      title: title,
      description: description,
      startTime: DateTime.now(),
      endTime: DateTime.now().add(Duration(seconds: durationSecs)),
      status: data['status'] as String? ?? 'active',
    );
  }

  static Future<List<Vote>> getVotes(String apiKey) async {
    final response = await _get(Constants.endpointVotes, apiKey: apiKey);
    final data = response.data;

    List<dynamic> rawVotes;
    if (data is Map<String, dynamic>) {
      rawVotes = data['votes'] as List<dynamic>? ?? [];
    } else if (data is List) {
      rawVotes = data;
    } else {
      rawVotes = [];
    }

    return rawVotes
        .whereType<Map<String, dynamic>>()
        .map(Vote.fromJson)
        .toList();
  }

  static Future<bool> submitVote(
    String apiKey,
    String voteId,
    String citizenId,
    String choice,
  ) async {
    await _post(
      Constants.endpointVote,
      apiKey: apiKey,
      body: {
        'vote_id': voteId,
        'citizen_id': citizenId,
        'choice': choice,
      },
    );
    return true;
  }

  static Future<Map<String, dynamic>> getStructure(String apiKey) async {
    final status = await getServerStatus();
    final blocksResponse = await _get(Constants.endpointBlocks, apiKey: apiKey);
    final blocks = blocksResponse.data as List<dynamic>? ?? [];

    int citizensCount = 0;
    int lawsCount = 0;
    bool hasConstitution = false;
    int totalEvents = 0;

    for (final block in blocks) {
      if (block is! Map<String, dynamic>) continue;
      final blockEvents = block['events'] as List<dynamic>? ?? [];
      totalEvents += blockEvents.length;

      for (final event in blockEvents) {
        if (event is! Map<String, dynamic>) continue;
        final type = event['event_type'] as String? ?? '';
        if (type == 'CitizenAdded') citizensCount++;
        if (type == 'ConstitutionFullText') hasConstitution = true;
        if (type == 'LawAdded') lawsCount++;
      }
    }

    int nodesCount = 0;
    try {
      final nodesResponse = await _get(Constants.endpointNodes, apiKey: apiKey);
      final nodes = nodesResponse.data;
      if (nodes is List) {
        nodesCount = nodes.length;
      }
    } catch (_) {
      nodesCount = 0;
    }

    return {
      'blocks_count': status['blocks'] ?? blocks.length,
      'events_count': totalEvents,
      'citizens_count': citizensCount,
      'laws_count': lawsCount,
      'has_constitution': hasConstitution,
      'nodes_count': nodesCount,
      'pending_events': status['pending_events_local'] ?? 0,
      'version': status['version'] ?? '0.7.0',
      'is_block_producer': status['is_block_producer'] ?? false,
    };
  }

  static Future<ExchangeBalance> getExchangeBalance(String apiKey) async {
    final response = await _get(
      Constants.endpointExchangeBalance,
      apiKey: apiKey,
    );
    return ExchangeBalance.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<List<ExchangeOffer>> getExchangeOffers(
    String apiKey, {
    String? status,
    String? service,
  }) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status;
    if (service != null && service.isNotEmpty) query['service'] = service;

    final response = await _get(
      Constants.endpointExchangeOffers,
      apiKey: apiKey,
      query: query.isEmpty ? null : query,
    );

    final data = response.data;
    if (data is! List) return [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(ExchangeOffer.fromJson)
        .toList();
  }

  static Future<List<ExchangeOrder>> getExchangeOrders(
    String apiKey, {
    String? status,
  }) async {
    final response = await _get(
      Constants.endpointExchangeOrders,
      apiKey: apiKey,
      query: status != null ? {'status': status} : null,
    );

    final data = response.data;
    if (data is! List) return [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(ExchangeOrder.fromJson)
        .toList();
  }

  static Future<List<SvodService>> getSvodCatalog(String apiKey) async {
    final response = await _get(Constants.endpointSvod, apiKey: apiKey);

    final data = response.data;
    if (data is! List) return [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(SvodService.fromJson)
        .toList();
  }

  static Future<String> createExchangeOffer(
    String apiKey, {
    required String svodCode,
    required int price,
    required int quantity,
  }) async {
    final response = await _post(
      Constants.endpointExchangeOffer,
      apiKey: apiKey,
      body: {
        'svod_code': svodCode,
        'price': price,
        'quantity': quantity,
      },
    );
    final data = response.data as Map<String, dynamic>? ?? {};
    return data['offer_id'] as String? ?? '';
  }

  static Future<void> cancelExchangeOffer(
    String apiKey,
    String offerId,
  ) async {
    await _delete(
      '${Constants.endpointExchangeOffer}/$offerId',
      apiKey: apiKey,
    );
  }

  static Future<List<Candidacy>> listCandidacies({
    String? status,
    String? targetRole,
  }) async {
    final query = <String, String>{};
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (targetRole != null && targetRole.isNotEmpty) {
      query['target_role'] = targetRole;
    }

    final response = await _get(
      Constants.endpointCandidacyList,
      query: query.isEmpty ? null : query,
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) return [];

    final raw = data['candidacies'] as List<dynamic>? ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Candidacy.fromJson)
        .toList();
  }

  static Future<Candidacy> getCandidacy(String id) async {
    final response = await _get('${Constants.endpointCandidacy}/$id');
    return Candidacy.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Candidacy> nominateCandidate(
    String apiKey, {
    required String candidateId,
    required String targetRole,
  }) async {
    final response = await _post(
      Constants.endpointCandidacyNominate,
      apiKey: apiKey,
      body: {
        'candidate_id': candidateId,
        'target_role': targetRole,
      },
    );
    return Candidacy.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Candidacy> voteForCandidate(
    String apiKey,
    String candidacyId,
    String vote,
  ) async {
    final response = await _post(
      '${Constants.endpointCandidacy}/$candidacyId/vote',
      apiKey: apiKey,
      body: {'vote': vote},
    );
    return Candidacy.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Candidacy> appointCandidate(
    String apiKey,
    String candidacyId,
  ) async {
    final response = await _post(
      '${Constants.endpointCandidacy}/$candidacyId/appoint',
      apiKey: apiKey,
    );
    return Candidacy.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<List<Initiative>> listInitiatives({String? status}) async {
    final query = <String, String>{};
    if (status != null && status.isNotEmpty) query['status'] = status;

    final response = await _get(
      Constants.endpointInitiativeList,
      query: query.isEmpty ? null : query,
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) return [];

    final raw = data['initiatives'] as List<dynamic>? ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Initiative.fromJson)
        .toList();
  }

  static Future<Initiative> getInitiative(String id) async {
    final response = await _get('${Constants.endpointInitiative}/$id');
    return Initiative.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Initiative> proposeInitiative(
    String apiKey, {
    required String title,
    required String description,
  }) async {
    final response = await _post(
      Constants.endpointInitiativePropose,
      apiKey: apiKey,
      body: {
        'title': title,
        'description': description,
      },
    );
    return Initiative.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Initiative> voteOnInitiative(
    String apiKey,
    String initiativeId,
    String vote,
  ) async {
    final response = await _post(
      '${Constants.endpointInitiative}/$initiativeId/vote',
      apiKey: apiKey,
      body: {'vote': vote},
    );
    return Initiative.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<List<Referendum>> listReferendums({String? status}) async {
    final query = <String, String>{};
    if (status != null && status.isNotEmpty) query['status'] = status;

    final response = await _get(
      Constants.endpointReferendumList,
      query: query.isEmpty ? null : query,
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) return [];

    final raw = data['referendums'] as List<dynamic>? ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Referendum.fromJson)
        .toList();
  }

  static Future<Referendum> getReferendum(String id) async {
    final response = await _get('${Constants.endpointReferendum}/$id');
    return Referendum.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Referendum> announceReferendum(
    String apiKey, {
    required String title,
    required String description,
    required String targetDecision,
  }) async {
    final response = await _post(
      Constants.endpointReferendumAnnounce,
      apiKey: apiKey,
      body: {
        'title': title,
        'description': description,
        'target_decision': targetDecision,
      },
    );
    return Referendum.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Referendum> voteOnReferendum(
    String apiKey,
    String referendumId,
    String vote,
  ) async {
    final response = await _post(
      '${Constants.endpointReferendum}/$referendumId/vote',
      apiKey: apiKey,
      body: {'vote': vote},
    );
    return Referendum.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<List<ChatMessage>> listChatMessages(
    String apiKey, {
    int limit = 50,
    String? before,
  }) async {
    final query = <String, String>{'limit': limit.toString()};
    if (before != null && before.isNotEmpty) {
      query['before'] = before;
    }

    final response = await _get(
      Constants.endpointChatMessages,
      apiKey: apiKey,
      query: query,
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) return [];

    final raw = data['messages'] as List<dynamic>? ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
  }

  static Future<ChatMessage> sendChatMessage(
    String apiKey,
    String content,
  ) async {
    final response = await _post(
      Constants.endpointChatSend,
      apiKey: apiKey,
      body: {'content': content},
    );
    return ChatMessage.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<String> createExchangeOrder(
    String apiKey, {
    required String offerId,
    required int quantity,
  }) async {
    final response = await _post(
      Constants.endpointExchangeOrder,
      apiKey: apiKey,
      body: {
        'offer_id': offerId,
        'quantity': quantity,
      },
    );
    final data = response.data as Map<String, dynamic>? ?? {};
    return data['message'] as String? ?? 'Заказ создан';
  }

  static List<Citizen> _extractCitizens(dynamic data) {
    if (data is Map<String, dynamic>) {
      final citizens = data['citizens'] as List<dynamic>? ?? [];
      return citizens
          .whereType<Map<String, dynamic>>()
          .map(Citizen.fromJson)
          .toList();
    }
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Citizen.fromJson)
          .toList();
    }
    return [];
  }
}

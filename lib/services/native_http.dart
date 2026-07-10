import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// На части Android (MIUI + LTE) Dart-сокеты не ходят в LAN; Java HttpURLConnection — да.
class NativeHttp {
  static const _channel = MethodChannel('com.quazar.quazar_passport/lan_http');

  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 12),
  }) =>
      _request('GET', uri, headers: headers, timeout: timeout);

  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 12),
  }) =>
      _request(
        'POST',
        uri,
        headers: headers,
        body: body is String ? body : (body != null ? jsonEncode(body) : null),
        timeout: timeout,
      );

  static Future<http.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 12),
  }) =>
      _request('DELETE', uri, headers: headers, timeout: timeout);

  static Future<http.Response> patch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 12),
  }) =>
      _request(
        'PATCH',
        uri,
        headers: headers,
        body: body is String ? body : (body != null ? jsonEncode(body) : null),
        timeout: timeout,
      );

  static Future<http.Response> _request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    String? body,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (!Platform.isAndroid) {
      switch (method) {
        case 'GET':
          return http.get(uri, headers: headers).timeout(timeout);
        case 'POST':
          return http
              .post(uri, headers: headers, body: body)
              .timeout(timeout);
        case 'DELETE':
          return http.delete(uri, headers: headers).timeout(timeout);
        case 'PATCH':
          return http
              .patch(uri, headers: headers, body: body)
              .timeout(timeout);
        default:
          throw UnsupportedError(method);
      }
    }

    try {
      final args = <String, dynamic>{
        'method': method,
        'url': uri.toString(),
        'timeoutMs': timeout.inMilliseconds,
        'headers': headers ?? const <String, String>{},
      };
      if (body != null) {
        // Кириллица в POST-теле ломает MethodChannel — шлём base64.
        args['bodyBase64'] = base64.encode(utf8.encode(body));
      }
      final raw = await _channel.invokeMapMethod<String, dynamic>('request', args);
      final statusCode = raw?['statusCode'] as int? ?? 0;
      final responseBody = _decodeBody(raw);
      return http.Response(responseBody, statusCode);
    } on PlatformException catch (e) {
      throw http.ClientException(
        e.message ?? 'Сетевая ошибка (${e.code})',
        uri,
      );
    }
  }

  /// Для unit-тестов декодирования ответа MethodChannel.
  @visibleForTesting
  static String decodeBodyForTest(Map<String, dynamic>? raw) => _decodeBody(raw);

  static String _decodeBody(Map<String, dynamic>? raw) {
    if (raw == null) return '';

    final base64Body = raw['bodyBase64'];
    if (base64Body is String && base64Body.isNotEmpty) {
      return utf8.decode(base64.decode(base64Body), allowMalformed: true);
    }

    final bytes = raw['bodyBytes'];
    if (bytes is List) {
      final data = bytes
          .map((value) => (value as num).toInt())
          .toList(growable: false);
      return utf8.decode(data, allowMalformed: true);
    }

    return raw['body'] as String? ?? '';
  }
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quazar_passport/services/native_http.dart';

void main() {
  group('NativeHttp body decode', () {
    test('decodes base64 UTF-8 chat JSON with Cyrillic', () {
      const json =
          '{"status":"success","data":{"messages":[{"id":"1","content":"первое сообщение","author":"Айя"}]}}';
      final encoded = base64.encode(utf8.encode(json));

      final decoded = NativeHttp.decodeBodyForTest({
        'statusCode': 200,
        'bodyBase64': encoded,
      });

      expect(decoded, json);

      final parsed = jsonDecode(decoded) as Map<String, dynamic>;
      expect(parsed['status'], 'success');
      final messages =
          (parsed['data'] as Map<String, dynamic>)['messages'] as List;
      expect(messages.first['content'], 'первое сообщение');
    });

    test('falls back to bodyBytes list', () {
      const text = 'Привет, мир!';
      final bytes = utf8.encode(text);

      final decoded = NativeHttp.decodeBodyForTest({
        'bodyBytes': bytes,
      });

      expect(decoded, text);
    });
  });
}

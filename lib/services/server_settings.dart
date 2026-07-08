import 'package:shared_preferences/shared_preferences.dart';

import '../utils/config.dart';

/// Хранение адресов серверов в SharedPreferences.
class ServerSettings {
  static const String keyPrimaryUrl = 'server_url_primary';
  static const String keySecondaryUrl = 'server_url_secondary';

  final String? primaryUrl;
  final String? secondaryUrl;

  const ServerSettings({
    this.primaryUrl,
    this.secondaryUrl,
  });

  String get effectivePrimary => primaryUrl ?? Config.defaultPrimaryUrl;

  List<String> get knownNodes {
    final nodes = <String>[effectivePrimary];
    final secondary = secondaryUrl?.trim();
    if (secondary != null && secondary.isNotEmpty && secondary != effectivePrimary) {
      nodes.add(normalizeUrl(secondary));
    } else if (primaryUrl == null && secondaryUrl == null) {
      for (final node in Config.defaultKnownNodes) {
        if (!nodes.contains(node)) {
          nodes.add(node);
        }
      }
    }
    return nodes;
  }

  static String normalizeUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    return url.replaceAll(RegExp(r'/+$'), '');
  }

  static String? validateUrlFormat(String raw) {
    final normalized = normalizeUrl(raw);
    if (normalized.isEmpty) {
      return 'Адрес не может быть пустым';
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) {
      return 'Неверный формат адреса (пример: http://192.168.0.20:8080)';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Поддерживаются только http и https';
    }
    return null;
  }

  static Future<ServerSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ServerSettings(
      primaryUrl: prefs.getString(keyPrimaryUrl),
      secondaryUrl: prefs.getString(keySecondaryUrl),
    );
  }

  static Future<void> save({
    required String primary,
    String? secondary,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyPrimaryUrl, normalizeUrl(primary));
    final secondaryNorm = secondary?.trim();
    if (secondaryNorm != null && secondaryNorm.isNotEmpty) {
      await prefs.setString(keySecondaryUrl, normalizeUrl(secondaryNorm));
    } else {
      await prefs.remove(keySecondaryUrl);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyPrimaryUrl);
    await prefs.remove(keySecondaryUrl);
  }
}

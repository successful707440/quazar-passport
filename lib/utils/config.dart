class Config {
  // Quazar Registry в локальной сети (IP компьютера с сервером).
  // Телефон должен быть в той же Wi‑Fi сети (192.168.0.x), не на мобильном интернете.
  // Android-эмулятор: http://10.0.2.2:8080 / :8081
  static const String defaultPrimaryUrl = 'http://192.168.0.20:8080';
  static const String defaultSecondaryUrl = 'http://192.168.0.20:8081';

  /// Значения по умолчанию, если в настройках не задан свой адрес.
  static List<String> get defaultKnownNodes => [
        defaultPrimaryUrl,
        defaultSecondaryUrl,
      ];

  /// @deprecated Используйте [defaultKnownNodes] или NodeProvider.knownNodes.
  static List<String> get knownNodes => defaultKnownNodes;
}

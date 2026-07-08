class Constants {

  static const String storageCitizenId = 'citizen_id';
  static const String storageCitizenName = 'citizen_name';
  static const String storageApiKey = 'api_key';
  static const String storagePublicKey = 'public_key';
  static const String storagePassportIssued = 'passport_issued';
  static const String storageIsLoggedIn = 'is_logged_in';
  static const String storageUseBiometrics = 'use_biometrics';

  static const String endpointStatus = '/status';
  static const String endpointBlocks = '/blocks';
  static const String endpointEvents = '/events';
  static const String endpointNodes = '/nodes';
  static const String endpointCitizensOnline = '/citizens/online';
  static const String endpointOnline = '/online';
  static const String endpointOffline = '/offline';
  static const String endpointVote = '/vote';
  static const String endpointVotes = '/votes';
  static const String endpointCitizen = '/citizen';
  static const String endpointCitizenList = '/citizen/list';
  static const String endpointCitizenSearch = '/citizen/search';

  static const String endpointExchangeOffers = '/exchange/offers';
  static const String endpointExchangeOffer = '/exchange/offer';
  static const String endpointExchangeOrder = '/exchange/order';
  static const String endpointExchangeOrders = '/exchange/orders';
  static const String endpointExchangeBalance = '/exchange/balance';

  static const String endpointSvod = '/svod';

  static const String endpointCandidacyList = '/candidacy/list';
  static const String endpointCandidacy = '/candidacy';
  static const String endpointCandidacyNominate = '/candidacy/nominate';

  /// Внутренняя валюта государства Квазар
  static const String currencyName = 'Квази';

  static const String accessDeniedRevoked =
      'В доступе отказано. Причина: лишён гражданства';

  static bool isRevokedStatus(String status) =>
      status.toLowerCase() == 'revoked';

  static String formatAmount(int amount) => '$amount $currencyName';

  /// Заменяет QUAZAR в ответах сервера на «Квази».
  static String localizeCurrency(String text) {
    return text.replaceAll(RegExp(r'QUAZAR', caseSensitive: false), currencyName);
  }
}

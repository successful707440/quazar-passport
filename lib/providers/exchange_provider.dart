import 'package:flutter/material.dart';
import '../models/exchange.dart';
import '../models/svod_service.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class ExchangeProvider extends ChangeNotifier {
  ExchangeBalance? _balance;
  List<ExchangeOffer> _offers = [];
  List<ExchangeOrder> _orders = [];
  List<SvodService> _svodServices = [];
  bool _isLoading = false;
  String? _error;

  ExchangeBalance? get balance => _balance;
  List<ExchangeOffer> get offers => _offers;
  List<ExchangeOrder> get orders => _orders;
  List<SvodService> get svodServices => _svodServices;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<ExchangeOffer> get activeOffers =>
      _offers.where((o) => o.isActive).toList();

  Future<void> loadAll(AuthProvider auth) async {
    if (auth.apiKey == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        ApiService.getExchangeBalance(auth.apiKey!),
        ApiService.getExchangeOffers(auth.apiKey!, status: 'active'),
        ApiService.getExchangeOrders(auth.apiKey!),
        ApiService.getSvodCatalog(auth.apiKey!),
      ]);

      _balance = results[0] as ExchangeBalance;
      _offers = results[1] as List<ExchangeOffer>;
      _orders = results[2] as List<ExchangeOrder>;
      _svodServices = results[3] as List<SvodService>;
    } on ApiException catch (e) {
      _error = _translateError(e.message);
    } catch (e) {
      _error = 'Ошибка загрузки биржи: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createOffer(
    AuthProvider auth, {
    required String svodCode,
    required int price,
    required int quantity,
  }) async {
    if (auth.apiKey == null) return 'Не авторизован';

    try {
      await ApiService.createExchangeOffer(
        auth.apiKey!,
        svodCode: svodCode,
        price: price,
        quantity: quantity,
      );
      await loadAll(auth);
      return null;
    } on ApiException catch (e) {
      return _translateError(e.message);
    } catch (e) {
      return 'Ошибка: $e';
    }
  }

  Future<String?> buyOffer(
    AuthProvider auth, {
    required ExchangeOffer offer,
    required int quantity,
  }) async {
    if (auth.apiKey == null) return 'Не авторизован';

    try {
      await ApiService.createExchangeOrder(
        auth.apiKey!,
        offerId: offer.id,
        quantity: quantity,
      );
      await loadAll(auth);
      return null;
    } on ApiException catch (e) {
      return _translateError(e.message);
    } catch (e) {
      return 'Ошибка: $e';
    }
  }

  Future<String?> cancelOffer(
    AuthProvider auth,
    ExchangeOffer offer,
  ) async {
    if (auth.apiKey == null) return 'Не авторизован';

    try {
      await ApiService.cancelExchangeOffer(auth.apiKey!, offer.id);
      await loadAll(auth);
      return null;
    } on ApiException catch (e) {
      return _translateError(e.message);
    } catch (e) {
      return 'Ошибка: $e';
    }
  }

  bool isMyOffer(ExchangeOffer offer, AuthProvider auth) {
    if (auth.citizenId == null) return false;
    return offer.seller == auth.citizenId ||
        offer.seller == auth.citizenName;
  }

  String _translateError(String message) {
    if (message.contains('Insufficient balance')) {
      return 'Недостаточно ${Constants.currencyName} на балансе';
    }
    if (message.contains('Insufficient quantity')) {
      return 'Недостаточно товара в предложении';
    }
    if (message.contains('Cannot buy your own offer')) {
      return 'Нельзя купить своё предложение';
    }
    if (message.contains('Unauthorized')) {
      return 'Недостаточно прав';
    }
    if (message.contains('Service not in Svod catalog')) {
      return 'Услуга не найдена в Своде';
    }
    if (message.contains('Price must be at least')) {
      return Constants.localizeCurrency(message);
    }
    if (message.contains('Quantity must be at least')) {
      return message.replaceFirst('Quantity must be at least', 'Минимальное количество');
    }
    if (message.contains('Quantity must be at most')) {
      return message.replaceFirst('Quantity must be at most', 'Максимальное количество');
    }
    return Constants.localizeCurrency(message);
  }
}

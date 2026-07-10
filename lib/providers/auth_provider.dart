import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/citizen.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../providers/node_provider.dart';
import '../utils/constants.dart';

class AuthProvider extends ChangeNotifier {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  bool _initialized = false;
  bool _isLoggedIn = false;
  String? _citizenId;
  String? _citizenName;
  String? _apiKey;
  String? _publicKey;
  bool _passportIssued = false;
  String? _role;
  String _status = 'active';
  bool _isCouncilMember = false;
  bool _canVeto = false;
  bool _useBiometrics = false;
  bool _hasStoredCredentials = false;
  bool _isLoading = false;
  String? _lastLoginError;

  bool get isInitialized => _initialized;
  bool get isLoggedIn => _isLoggedIn;
  String? get citizenId => _citizenId;
  String? get citizenName => _citizenName;
  String? get apiKey => _apiKey;
  String? get publicKey => _publicKey;
  bool get passportIssued => _passportIssued;
  String? get role => _role;
  String get status => _status;
  bool get isCouncilMember => _isCouncilMember;
  bool get canVeto => _canVeto;
  bool get useBiometrics => _useBiometrics;
  bool get hasStoredCredentials => _hasStoredCredentials;
  bool get canUseBiometricLogin =>
      _useBiometrics && _hasStoredCredentials && !_isLoggedIn;
  bool get isLoading => _isLoading;
  String? get lastLoginError => _lastLoginError;

  void clearLoginError() {
    if (_lastLoginError == null) return;
    _lastLoginError = null;
    notifyListeners();
  }

  AuthProvider();

  void _applyCitizenProfile(Citizen citizen) {
    _citizenName = citizen.name;
    _publicKey = citizen.publicKey;
    _passportIssued = citizen.passportIssued;
    _role = citizen.role;
    _status = citizen.status;
    _isCouncilMember = citizen.isCouncilMember ?? citizen.role != null;
    _canVeto = citizen.canVeto ?? citizen.role == 'Aiya';
  }

  void _ensureCitizenCanAccess(Citizen citizen) {
    if (Constants.isRevokedStatus(citizen.status)) {
      throw ApiException(Constants.accessDeniedRevoked);
    }
  }

  Future<void> _clearLoggedInState({String? error}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Constants.storageIsLoggedIn, false);
    _isLoggedIn = false;
    _citizenId = null;
    _apiKey = null;
    _publicKey = null;
    if (error != null) {
      _lastLoginError = error;
    }
    notifyListeners();
  }

  /// Вызывается после инициализации NodeProvider — до любых API-запросов.
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadSession();
  }

  Future<bool> _ensureNodeReady() async {
    final nodes = NodeProvider.instance;
    if (nodes == null) return true;

    final ok = await nodes.ensureAvailableNode(showSwitching: true);
    if (ok) {
      ApiService.syncActiveNode();
    }
    return ok;
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final wasLoggedIn = prefs.getBool(Constants.storageIsLoggedIn) ?? false;
    _useBiometrics = prefs.getBool(Constants.storageUseBiometrics) ?? false;
    _passportIssued =
        prefs.getBool(Constants.storagePassportIssued) ?? false;

    await _refreshStoredCredentialsFlag();

    if (_useBiometrics && _hasStoredCredentials) {
      _citizenName = await _secureStorage.read(
        key: Constants.storageCitizenName,
      );

      if (wasLoggedIn) {
        // Биометрия включена — всегда просим отпечаток при запуске
        _isLoggedIn = false;
        _citizenId = null;
        _apiKey = null;
        _publicKey = null;
      } else {
        _isLoggedIn = false;
      }
    } else if (wasLoggedIn && _hasStoredCredentials) {
      _citizenId =
          await _secureStorage.read(key: Constants.storageCitizenId);
      _citizenName =
          await _secureStorage.read(key: Constants.storageCitizenName);
      _apiKey = await _secureStorage.read(key: Constants.storageApiKey);
      _publicKey =
          await _secureStorage.read(key: Constants.storagePublicKey);
      _isLoggedIn = true;
      try {
        if (await _ensureNodeReady()) {
          await refreshCitizenProfile();
          if (_isLoggedIn &&
              _apiKey != null &&
              _citizenId != null &&
              !Constants.isRevokedStatus(_status)) {
            await ApiService.sendOnlineStatus(_apiKey!, _citizenId!, true);
          }
        } else {
          _isLoggedIn = false;
        }
      } on ApiException catch (e) {
        debugPrint('Session restore denied: $e');
        await _clearLoggedInState(error: e.message);
      } catch (e) {
        debugPrint('Session restore failed: $e');
        _isLoggedIn = false;
      }
    } else {
      _isLoggedIn = false;
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> _refreshStoredCredentialsFlag() async {
    final storedName =
        await _secureStorage.read(key: Constants.storageCitizenName);
    final storedKey = await _secureStorage.read(key: Constants.storageApiKey);
    _hasStoredCredentials = storedName != null &&
        storedName.isNotEmpty &&
        storedKey != null &&
        storedKey.isNotEmpty;
  }

  Future<void> _persistCredentials({
    required String citizenId,
    required String citizenName,
    required String apiKey,
    required String publicKey,
    required bool passportIssued,
  }) async {
    await _secureStorage.write(
      key: Constants.storageCitizenId,
      value: citizenId,
    );
    await _secureStorage.write(
      key: Constants.storageCitizenName,
      value: citizenName,
    );
    await _secureStorage.write(key: Constants.storageApiKey, value: apiKey);
    await _secureStorage.write(
      key: Constants.storagePublicKey,
      value: publicKey,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Constants.storagePassportIssued, passportIssued);
    _hasStoredCredentials = true;
  }

  Future<bool> loginWithApiKey(String citizenName, String apiKey) async {
    _isLoading = true;
    _lastLoginError = null;
    notifyListeners();

    try {
      if (!await _ensureNodeReady()) {
        _lastLoginError =
            'Узлы недоступны. Проверьте сеть и адреса узлов в настройках';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final profile =
          await ApiService.login(citizenName.trim(), apiKey.trim());
      _ensureCitizenCanAccess(profile);
      await _saveSession(profile, apiKey.trim());
      await ApiService.sendOnlineStatus(apiKey.trim(), profile.id, true);

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      debugPrint('API key login error: $e');
      _lastLoginError = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('API key login error: $e');
      _lastLoginError = NodeProvider.isConnectionError(e)
          ? 'Узлы недоступны. Проверьте сеть и адреса узлов в настройках'
          : 'Не удалось войти: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String citizenName, String password) async {
    _isLoading = true;
    _lastLoginError = null;
    notifyListeners();

    try {
      if (!await _ensureNodeReady()) {
        _lastLoginError =
            'Узлы недоступны. Проверьте сеть и адреса узлов в настройках';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final loginData =
          await ApiService.loginWithPassword(citizenName.trim(), password.trim());
      final apiKey = loginData['api_key'] as String? ?? '';
      final citizenId = loginData['citizen_id'] as String? ?? '';
      if (apiKey.isEmpty || citizenId.isEmpty) {
        throw ApiException('Неожиданный ответ сервера');
      }

      final profile = await ApiService.getCitizen(apiKey, citizenId);
      _ensureCitizenCanAccess(profile);
      await _saveSession(profile, apiKey);
      await ApiService.sendOnlineStatus(apiKey, profile.id, true);

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      debugPrint('Login error: $e');
      _lastLoginError = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      _lastLoginError = NodeProvider.isConnectionError(e)
          ? 'Узлы недоступны. Проверьте сеть и адреса узлов в настройках'
          : 'Не удалось войти: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> setPassword(String password) async {
    if (_apiKey == null) {
      return 'Сначала войдите в систему';
    }
    try {
      await ApiService.setPassword(_apiKey!, password);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Не удалось сохранить пароль: $e';
    }
  }

  Future<bool> loginWithBiometrics() async {
    if (!canUseBiometricLogin) {
      debugPrint(
        'Biometric login unavailable: '
        'useBiometrics=$_useBiometrics, '
        'hasStored=$_hasStoredCredentials, '
        'isLoggedIn=$_isLoggedIn',
      );
      return false;
    }

    final result = await BiometricService.authenticateForLogin();
    if (!result.success) {
      _lastLoginError = result.errorMessage;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _lastLoginError = null;
    notifyListeners();

    try {
      _citizenName =
          await _secureStorage.read(key: Constants.storageCitizenName);
      _apiKey = await _secureStorage.read(key: Constants.storageApiKey);
      _citizenId = await _secureStorage.read(key: Constants.storageCitizenId);
      _publicKey =
          await _secureStorage.read(key: Constants.storagePublicKey);

      if (_citizenName == null || _apiKey == null || _citizenId == null) {
        _hasStoredCredentials = false;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (!await _ensureNodeReady()) {
        _lastLoginError =
            'Узлы недоступны. Проверьте сеть и адреса узлов в настройках';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await refreshCitizenProfile();
      if (Constants.isRevokedStatus(_status)) {
        _lastLoginError = Constants.accessDeniedRevoked;
        _citizenId = null;
        _apiKey = null;
        _publicKey = null;
        _isLoggedIn = false;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await ApiService.sendOnlineStatus(_apiKey!, _citizenId!, true);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(Constants.storageIsLoggedIn, true);

      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      debugPrint('Biometric login error: $e');
      _lastLoginError = e.message;
      _citizenId = null;
      _apiKey = null;
      _publicKey = null;
      _isLoggedIn = false;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Biometric login error: $e');
      _lastLoginError = NodeProvider.isConnectionError(e)
          ? 'Узлы недоступны. Проверьте сеть и адреса узлов в настройках'
          : 'Не удалось войти: $e';
      _citizenId = null;
      _apiKey = null;
      _publicKey = null;
      _isLoggedIn = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshCitizenProfile() async {
    if (_apiKey == null || _citizenId == null) return;

    final citizen = await ApiService.getCitizen(_apiKey!, _citizenId!);
    if (Constants.isRevokedStatus(citizen.status)) {
      _applyCitizenProfile(citizen);
      await _clearLoggedInState(error: Constants.accessDeniedRevoked);
      return;
    }

    _applyCitizenProfile(citizen);

    await _persistCredentials(
      citizenId: _citizenId!,
      citizenName: citizen.name,
      apiKey: _apiKey!,
      publicKey: citizen.publicKey,
      passportIssued: citizen.passportIssued,
    );
    notifyListeners();
  }

  Future<void> _saveSession(Citizen citizen, String apiKey) async {
    await _persistCredentials(
      citizenId: citizen.id,
      citizenName: citizen.name,
      apiKey: apiKey,
      publicKey: citizen.publicKey,
      passportIssued: citizen.passportIssued,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Constants.storageIsLoggedIn, true);

    _isLoggedIn = true;
    _citizenId = citizen.id;
    _citizenName = citizen.name;
    _apiKey = apiKey;
    _publicKey = citizen.publicKey;
    _passportIssued = citizen.passportIssued;
    _applyCitizenProfile(citizen);
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    final storedId =
        _citizenId ?? await _secureStorage.read(key: Constants.storageCitizenId);
    final storedKey =
        _apiKey ?? await _secureStorage.read(key: Constants.storageApiKey);

    if (storedId != null && storedKey != null) {
      try {
        await ApiService.sendOnlineStatus(storedKey, storedId, false);
      } catch (e) {
        debugPrint('Offline status error: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Constants.storageIsLoggedIn, false);
    await prefs.setBool(Constants.storagePassportIssued, false);

    if (_useBiometrics && _hasStoredCredentials) {
      // Мягкий выход: ключ остаётся для входа по отпечатку
      _citizenName = await _secureStorage.read(
        key: Constants.storageCitizenName,
      );
      _isLoggedIn = false;
      _citizenId = null;
      _apiKey = null;
      _publicKey = null;
      _passportIssued = false;
      _role = null;
      _status = 'active';
      _isCouncilMember = false;
      _canVeto = false;
    } else {
      await _secureStorage.delete(key: Constants.storageCitizenId);
      await _secureStorage.delete(key: Constants.storageCitizenName);
      await _secureStorage.delete(key: Constants.storageApiKey);
      await _secureStorage.delete(key: Constants.storagePublicKey);

      _isLoggedIn = false;
      _citizenId = null;
      _citizenName = null;
      _apiKey = null;
      _publicKey = null;
      _passportIssued = false;
      _role = null;
      _status = 'active';
      _isCouncilMember = false;
      _canVeto = false;
      _hasStoredCredentials = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<String?> setUseBiometrics(bool value) async {
    if (value) {
      final status = await BiometricService.checkStatus();
      if (status != null) {
        return status;
      }
      if (!_isLoggedIn && !_hasStoredCredentials) {
        return 'Сначала войдите с паролем';
      }

      if (_isLoggedIn &&
          _citizenId != null &&
          _citizenName != null &&
          _apiKey != null) {
        await _persistCredentials(
          citizenId: _citizenId!,
          citizenName: _citizenName!,
          apiKey: _apiKey!,
          publicKey: _publicKey ?? '',
          passportIssued: _passportIssued,
        );
      }

      final result = await BiometricService.authenticateForEnable();
      if (!result.success) {
        return result.errorMessage ?? 'Биометрия не подтверждена';
      }
    }

    _useBiometrics = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Constants.storageUseBiometrics, value);
    notifyListeners();
    return null;
  }

  Future<void> clearAllData() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isLoggedIn = false;
    _citizenId = null;
    _citizenName = null;
    _apiKey = null;
    _publicKey = null;
    _passportIssued = false;
    _role = null;
    _status = 'active';
    _isCouncilMember = false;
    _canVeto = false;
    _useBiometrics = false;
    _hasStoredCredentials = false;
    notifyListeners();
  }
}

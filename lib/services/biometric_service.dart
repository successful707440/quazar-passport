import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthResult {
  final bool success;
  final String? errorMessage;

  const BiometricAuthResult({required this.success, this.errorMessage});
}

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    final status = await checkStatus();
    return status == null;
  }

  static Future<String?> checkStatus() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        return 'Устройство не поддерживает биометрию';
      }

      final canCheck = await _auth.canCheckBiometrics;
      final types = await _auth.getAvailableBiometrics();

      if (!canCheck && types.isEmpty) {
        return 'Настройте отпечаток или PIN/графический ключ в настройках телефона';
      }

      return null;
    } catch (e) {
      debugPrint('Biometric checkStatus error: $e');
      return 'Не удалось проверить биометрию';
    }
  }

  static Future<BiometricAuthResult> authenticateForLogin() {
    return authenticate(
      reason: 'Войдите в Quazar Passport',
    );
  }

  static Future<BiometricAuthResult> authenticateForEnable() {
    return authenticate(
      reason: 'Подтвердите включение биометрии',
    );
  }

  static Future<BiometricAuthResult> authenticate({
    required String reason,
  }) async {
    final status = await checkStatus();
    if (status != null) {
      return BiometricAuthResult(success: false, errorMessage: status);
    }

    try {
      final success = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );

      if (success) {
        return const BiometricAuthResult(success: true);
      }
      return const BiometricAuthResult(
        success: false,
        errorMessage: 'Подтверждение отменено',
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric authenticate error: ${e.code} ${e.message}');
      return BiometricAuthResult(
        success: false,
        errorMessage: _mapPlatformError(e),
      );
    } catch (e) {
      debugPrint('Biometric authenticate error: $e');
      return const BiometricAuthResult(
        success: false,
        errorMessage: 'Ошибка биометрии',
      );
    }
  }

  static String _mapPlatformError(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return 'Биометрия недоступна. Настройте отпечаток или блокировку экрана';
      case 'NotEnrolled':
        return 'Отпечаток не добавлен. Добавьте его в настройках телефона';
      case 'LockedOut':
      case 'PermanentlyLockedOut':
        return 'Слишком много попыток. Попробуйте позже';
      case 'PasscodeNotSet':
        return 'Установите PIN или графический ключ на телефоне';
      case 'auth_in_progress':
        return 'Подождите, проверка уже выполняется';
      default:
        return e.message ?? 'Биометрия не подтверждена';
    }
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/json_utils.dart';
import '../data/auth_remember_me_store.dart';

enum AuthFlowStep {
  login,
  register,
  verifyEmail,
  forgotPassword,
  verifyResetCode,
  resetPassword,
}

class AuthVerificationMeta {
  const AuthVerificationMeta({
    required this.maskedEmail,
    required this.resendCooldownSeconds,
  });

  final String maskedEmail;
  final int resendCooldownSeconds;

  factory AuthVerificationMeta.fromMap(Map<String, dynamic>? map) {
    return AuthVerificationMeta(
      maskedEmail: map?['maskedEmail']?.toString() ?? '',
      resendCooldownSeconds:
          (map?['resendCooldownSeconds'] as num?)?.toInt() ?? 60,
    );
  }
}

class AuthFlowState {
  const AuthFlowState({
    this.step = AuthFlowStep.login,
    this.loading = false,
    this.rememberMe = true,
    this.acceptTerms = false,
    this.error,
    this.notice,
    this.verificationMeta,
    this.resendSeconds = 0,
  });

  final AuthFlowStep step;
  final bool loading;
  final bool rememberMe;
  final bool acceptTerms;
  final String? error;
  final String? notice;
  final AuthVerificationMeta? verificationMeta;
  final int resendSeconds;

  static const _unset = Object();

  AuthFlowState copyWith({
    AuthFlowStep? step,
    bool? loading,
    bool? rememberMe,
    bool? acceptTerms,
    Object? error = _unset,
    Object? notice = _unset,
    Object? verificationMeta = _unset,
    int? resendSeconds,
  }) {
    return AuthFlowState(
      step: step ?? this.step,
      loading: loading ?? this.loading,
      rememberMe: rememberMe ?? this.rememberMe,
      acceptTerms: acceptTerms ?? this.acceptTerms,
      error: identical(error, _unset) ? this.error : error as String?,
      notice: identical(notice, _unset) ? this.notice : notice as String?,
      verificationMeta: identical(verificationMeta, _unset)
          ? this.verificationMeta
          : verificationMeta as AuthVerificationMeta?,
      resendSeconds: resendSeconds ?? this.resendSeconds,
    );
  }
}

class AuthFlowSubmitOutcome {
  const AuthFlowSubmitOutcome({
    this.prefillEmail,
    this.clearSensitiveFields = false,
  });

  final String? prefillEmail;
  final bool clearSensitiveFields;
}

abstract class AuthFlowGateway {
  Future<Map<String, dynamic>> login(String email, String password);

  Future<Map<String, dynamic>> register(String name, String email, String password);

  Future<Map<String, dynamic>> verifyEmail(String email, String code);

  Future<Map<String, dynamic>> resendVerificationCode(String email);

  Future<Map<String, dynamic>> requestPasswordReset(String email);

  Future<Map<String, dynamic>> verifyPasswordResetCode(String email, String code);

  Future<Map<String, dynamic>> resetPassword(String email, String code, String password);
}

class DefaultAuthFlowGateway implements AuthFlowGateway {
  const DefaultAuthFlowGateway();

  @override
  Future<Map<String, dynamic>> login(String email, String password) {
    return AuthService.instance.login(email, password);
  }

  @override
  Future<Map<String, dynamic>> register(String name, String email, String password) {
    return AuthService.instance.register(name, email, password);
  }

  @override
  Future<Map<String, dynamic>> verifyEmail(String email, String code) {
    return AuthService.instance.verifyEmail(email, code);
  }

  @override
  Future<Map<String, dynamic>> resendVerificationCode(String email) {
    return AuthService.instance.resendVerificationCode(email);
  }

  @override
  Future<Map<String, dynamic>> requestPasswordReset(String email) {
    return AuthService.instance.requestPasswordReset(email);
  }

  @override
  Future<Map<String, dynamic>> verifyPasswordResetCode(String email, String code) {
    return AuthService.instance.verifyPasswordResetCode(email, code);
  }

  @override
  Future<Map<String, dynamic>> resetPassword(
    String email,
    String code,
    String password,
  ) {
    return AuthService.instance.resetPassword(email, code, password);
  }
}

/// Controller leve do fluxo de autenticação.
///
/// Mantém as transições do fluxo, feedback ao usuário e o timer de reenvio
/// fora da widget tree, preservando o comportamento atual por compatibilidade.
class AuthFlowController extends ChangeNotifier {
  AuthFlowController({
    AuthFlowGateway? gateway,
    AuthRememberMeStore? rememberMeStore,
  })  : _gateway = gateway ?? const DefaultAuthFlowGateway(),
        _rememberMeStore = rememberMeStore ?? SharedPrefsAuthRememberMeStore();

  final AuthFlowGateway _gateway;
  final AuthRememberMeStore _rememberMeStore;

  AuthFlowState _state = const AuthFlowState();
  Timer? _resendTimer;

  AuthFlowState get state => _state;

  Future<String?> restoreRememberedEmail() async {
    final remembered = await _rememberMeStore.load();
    _state = _state.copyWith(rememberMe: remembered.enabled);
    notifyListeners();
    return remembered.email.isEmpty ? null : remembered.email;
  }

  void setRememberMe(bool value) {
    _state = _state.copyWith(rememberMe: value);
    notifyListeners();
  }

  void setAcceptTerms(bool value) {
    _state = _state.copyWith(acceptTerms: value);
    notifyListeners();
  }

  void switchTo(AuthFlowStep step) {
    _state = _state.copyWith(
      step: step,
      error: null,
      notice: null,
    );
    notifyListeners();
  }

  Future<AuthFlowSubmitOutcome> submit({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String code,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    _state = _state.copyWith(loading: true, error: null);
    notifyListeners();

    try {
      switch (_state.step) {
        case AuthFlowStep.login:
          await _gateway.login(email, password);
          await _persistRememberedEmail(email);
          return const AuthFlowSubmitOutcome();
        case AuthFlowStep.register:
          if (!_state.acceptTerms) {
            throw AppException(
              message: 'Você precisa aceitar os termos para criar a conta.',
              category: 'validation_error',
              code: 'legal_terms_required',
            );
          }
          _validatePasswordMatch(password, passwordConfirmation);
          final data = await _gateway.register(name, email, password);
          _state = _state.copyWith(
            step: AuthFlowStep.verifyEmail,
            notice: data['message']?.toString(),
          );
          _applyVerificationMeta(castJsonMap(data['verification']));
          notifyListeners();
          return const AuthFlowSubmitOutcome();
        case AuthFlowStep.verifyEmail:
          await _gateway.verifyEmail(email, code);
          await _persistRememberedEmail(email);
          return const AuthFlowSubmitOutcome();
        case AuthFlowStep.forgotPassword:
          final data = await _gateway.requestPasswordReset(email);
          _state = _state.copyWith(
            step: AuthFlowStep.verifyResetCode,
            notice: data['message']?.toString(),
          );
          _startResendTimer();
          notifyListeners();
          return const AuthFlowSubmitOutcome();
        case AuthFlowStep.verifyResetCode:
          final data = await _gateway.verifyPasswordResetCode(email, code);
          _state = _state.copyWith(
            step: AuthFlowStep.resetPassword,
            notice: data['message']?.toString(),
          );
          notifyListeners();
          return const AuthFlowSubmitOutcome();
        case AuthFlowStep.resetPassword:
          _validatePasswordMatch(newPassword, newPasswordConfirmation);
          final data = await _gateway.resetPassword(email, code, newPassword);
          _state = _state.copyWith(
            step: AuthFlowStep.login,
            notice:
                data['message']?.toString() ?? 'Senha atualizada com sucesso.',
          );
          notifyListeners();
          return const AuthFlowSubmitOutcome(clearSensitiveFields: true);
      }
    } catch (error) {
      if (_state.step == AuthFlowStep.login &&
          error is AppException &&
          error.code == 'email_verification_required') {
        final details = castJsonMap(error.details);
        _state = _state.copyWith(
          step: AuthFlowStep.verifyEmail,
          notice: error.message,
        );
        _applyVerificationMeta(details);
        notifyListeners();
        return AuthFlowSubmitOutcome(
          prefillEmail: details['email']?.toString(),
        );
      }

      _state = _state.copyWith(
        error: error is AppException
            ? error.message
            : 'Não foi possível concluir a operação agora.',
      );
      notifyListeners();
      rethrow;
    } finally {
      _state = _state.copyWith(loading: false);
      notifyListeners();
    }
  }

  Future<void> resendCode(String email) async {
    if (_state.resendSeconds > 0 || _state.loading) return;

    _state = _state.copyWith(loading: true, error: null);
    notifyListeners();

    try {
      if (_state.step == AuthFlowStep.verifyEmail) {
        final data = await _gateway.resendVerificationCode(email);
        _state = _state.copyWith(notice: data['message']?.toString());
        _applyVerificationMeta(castJsonMap(data['verification']));
      } else if (_state.step == AuthFlowStep.verifyResetCode) {
        final data = await _gateway.requestPasswordReset(email);
        _state = _state.copyWith(notice: data['message']?.toString());
        _startResendTimer();
      }
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(
        error: error is AppException
            ? error.message
            : 'Não foi possível reenviar o código agora.',
      );
      notifyListeners();
      rethrow;
    } finally {
      _state = _state.copyWith(loading: false);
      notifyListeners();
    }
  }

  void _applyVerificationMeta(Map<String, dynamic>? meta) {
    final verificationMeta = AuthVerificationMeta.fromMap(meta);
    _state = _state.copyWith(verificationMeta: verificationMeta);
    _startResendTimer(verificationMeta.resendCooldownSeconds);
  }

  Future<void> _persistRememberedEmail(String email) {
    return _rememberMeStore.save(
      enabled: _state.rememberMe,
      email: email,
    );
  }

  void _validatePasswordMatch(String password, String confirmation) {
    if (password == confirmation) return;
    throw AppException(
      message: 'As senhas informadas não coincidem.',
      category: 'validation_error',
      code: 'password_mismatch',
    );
  }

  void _startResendTimer([int seconds = 60]) {
    _resendTimer?.cancel();
    _state = _state.copyWith(resendSeconds: seconds);
    if (seconds <= 0) return;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final currentSeconds = _state.resendSeconds;
      if (currentSeconds <= 1) {
        timer.cancel();
        _state = _state.copyWith(resendSeconds: 0);
      } else {
        _state = _state.copyWith(resendSeconds: currentSeconds - 1);
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }
}

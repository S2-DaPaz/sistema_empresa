import 'package:flutter_test/flutter_test.dart';

import 'package:rv_sistema_mobile/core/errors/app_exception.dart';
import 'package:rv_sistema_mobile/features/auth/data/auth_remember_me_store.dart';
import 'package:rv_sistema_mobile/features/auth/presentation/auth_flow_controller.dart';

class _FakeRememberMeStore implements AuthRememberMeStore {
  _FakeRememberMeStore({
    this.enabled = true,
    this.email = '',
  });

  bool enabled;
  String email;

  @override
  Future<RememberedEmailData> load() async {
    return RememberedEmailData(enabled: enabled, email: email);
  }

  @override
  Future<void> save({
    required bool enabled,
    required String email,
  }) async {
    this.enabled = enabled;
    this.email = email;
  }
}

class _FakeGateway implements AuthFlowGateway {
  Future<Map<String, dynamic>> Function(String email, String password)? onLogin;
  Future<Map<String, dynamic>> Function(String name, String email, String password)?
      onRegister;
  Future<Map<String, dynamic>> Function(String email, String code)? onVerifyEmail;
  Future<Map<String, dynamic>> Function(String email)? onResendVerificationCode;
  Future<Map<String, dynamic>> Function(String email)? onRequestPasswordReset;
  Future<Map<String, dynamic>> Function(String email, String code)?
      onVerifyPasswordResetCode;
  Future<Map<String, dynamic>> Function(String email, String code, String password)?
      onResetPassword;

  @override
  Future<Map<String, dynamic>> login(String email, String password) {
    return onLogin!(email, password);
  }

  @override
  Future<Map<String, dynamic>> register(String name, String email, String password) {
    return onRegister!(name, email, password);
  }

  @override
  Future<Map<String, dynamic>> verifyEmail(String email, String code) {
    return onVerifyEmail!(email, code);
  }

  @override
  Future<Map<String, dynamic>> resendVerificationCode(String email) {
    return onResendVerificationCode!(email);
  }

  @override
  Future<Map<String, dynamic>> requestPasswordReset(String email) {
    return onRequestPasswordReset!(email);
  }

  @override
  Future<Map<String, dynamic>> verifyPasswordResetCode(String email, String code) {
    return onVerifyPasswordResetCode!(email, code);
  }

  @override
  Future<Map<String, dynamic>> resetPassword(
    String email,
    String code,
    String password,
  ) {
    return onResetPassword!(email, code, password);
  }
}

void main() {
  test('restaura o e-mail lembrado do armazenamento', () async {
    final controller = AuthFlowController(
      gateway: _FakeGateway(),
      rememberMeStore: _FakeRememberMeStore(
        enabled: true,
        email: 'gestor@empresa.com',
      ),
    );

    final rememberedEmail = await controller.restoreRememberedEmail();

    expect(rememberedEmail, 'gestor@empresa.com');
    expect(controller.state.rememberMe, isTrue);
  });

  test('move para verificacao de e-mail quando o login exige confirmacao', () async {
    final gateway = _FakeGateway()
      ..onLogin = (email, password) async {
        expect(password, 'senha123');
        throw AppException(
          message: 'Confirme seu e-mail antes de entrar.',
          category: 'validation_error',
          code: 'email_verification_required',
          details: {
            'email': email,
            'maskedEmail': 'g***@empresa.com',
            'resendCooldownSeconds': 45,
          },
        );
      };

    final controller = AuthFlowController(
      gateway: gateway,
      rememberMeStore: _FakeRememberMeStore(),
    );

    final outcome = await controller.submit(
      name: '',
      email: 'gestor@empresa.com',
      password: 'senha123',
      passwordConfirmation: '',
      code: '',
      newPassword: '',
      newPasswordConfirmation: '',
    );

    expect(controller.state.step, AuthFlowStep.verifyEmail);
    expect(controller.state.notice, 'Confirme seu e-mail antes de entrar.');
    expect(controller.state.verificationMeta?.maskedEmail, 'g***@empresa.com');
    expect(controller.state.resendSeconds, 45);
    expect(outcome.prefillEmail, 'gestor@empresa.com');
  });

  test('cadastro respeita aceite legal e avança para verificacao', () async {
    final gateway = _FakeGateway()
      ..onRegister = (name, email, password) async {
        expect(name, 'Maria Silva');
        expect(email, 'maria@empresa.com');
        expect(password, 'Senha123');
        return {
          'message': 'Conta criada.',
          'verification': {
            'maskedEmail': 'm***@empresa.com',
            'resendCooldownSeconds': 30,
          },
        };
      };

    final controller = AuthFlowController(
      gateway: gateway,
      rememberMeStore: _FakeRememberMeStore(),
    );

    controller.switchTo(AuthFlowStep.register);
    controller.setAcceptTerms(true);
    await controller.submit(
      name: 'Maria Silva',
      email: 'maria@empresa.com',
      password: 'Senha123',
      passwordConfirmation: 'Senha123',
      code: '',
      newPassword: '',
      newPasswordConfirmation: '',
    );

    expect(controller.state.step, AuthFlowStep.verifyEmail);
    expect(controller.state.notice, 'Conta criada.');
    expect(controller.state.verificationMeta?.resendCooldownSeconds, 30);
  });
}

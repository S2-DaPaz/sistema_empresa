import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/errors/app_exception.dart';
import '../services/auth_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_ui.dart';
import '../widgets/brand_logo.dart';
import '../widgets/form_fields.dart';

enum _AuthFlow {
  login,
  register,
  verifyEmail,
  forgotPassword,
  verifyResetCode,
  resetPassword,
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _AuthFlow _flow = _AuthFlow.login;
  bool _loading = false;
  String? _error;
  String? _notice;
  Map<String, dynamic>? _verificationMeta;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _passwordConfirm = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _newPasswordConfirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _code.dispose();
    _newPassword.dispose();
    _newPasswordConfirm.dispose();
    super.dispose();
  }

  void _switchTo(_AuthFlow flow) {
    setState(() {
      _flow = flow;
      _error = null;
      _notice = null;
    });
  }

  void _setError(Object error, {String? fallback}) {
    setState(() {
      _error = error is AppException
          ? error.message
          : fallback ?? 'Não foi possível concluir a operação agora.';
    });
  }

  void _validatePasswordConfirmation(String password, String confirmation) {
    if (password != confirmation) {
      throw AppException(
        message: 'As senhas informadas não coincidem.',
        category: 'validation_error',
        code: 'password_confirmation_mismatch',
      );
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_flow == _AuthFlow.login) {
        await AuthService.instance.login(
          _email.text.trim(),
          _password.text,
        );
        return;
      }

      if (_flow == _AuthFlow.register) {
        _validatePasswordConfirmation(_password.text, _passwordConfirm.text);
        final data = await AuthService.instance.register(
          _name.text.trim(),
          _email.text.trim(),
          _password.text,
        );
        setState(() {
          _verificationMeta = _asMap(data['verification']);
          _notice = data['message']?.toString() ??
              'Conta criada com sucesso. Enviamos um código para o seu e-mail.';
          _flow = _AuthFlow.verifyEmail;
        });
        return;
      }

      if (_flow == _AuthFlow.verifyEmail) {
        await AuthService.instance.verifyEmail(
          _email.text.trim(),
          _code.text.trim(),
        );
        return;
      }

      if (_flow == _AuthFlow.forgotPassword) {
        final data = await AuthService.instance.requestPasswordReset(
          _email.text.trim(),
        );
        setState(() {
          _notice = data['message']?.toString() ??
              'Se o e-mail informado estiver cadastrado, você receberá um código para redefinir a senha.';
          _flow = _AuthFlow.verifyResetCode;
        });
        return;
      }

      if (_flow == _AuthFlow.verifyResetCode) {
        final data = await AuthService.instance.verifyPasswordResetCode(
          _email.text.trim(),
          _code.text.trim(),
        );
        setState(() {
          _notice =
              data['message']?.toString() ?? 'Código validado com sucesso.';
          _flow = _AuthFlow.resetPassword;
        });
        return;
      }

      if (_flow == _AuthFlow.resetPassword) {
        _validatePasswordConfirmation(
          _newPassword.text,
          _newPasswordConfirm.text,
        );
        final data = await AuthService.instance.resetPassword(
          _email.text.trim(),
          _code.text.trim(),
          _newPassword.text,
        );
        setState(() {
          _flow = _AuthFlow.login;
          _notice =
              data['message']?.toString() ?? 'Senha redefinida com sucesso.';
          _password.clear();
          _passwordConfirm.clear();
          _newPassword.clear();
          _newPasswordConfirm.clear();
          _code.clear();
        });
      }
    } catch (error) {
      if (_flow == _AuthFlow.login &&
          error is AppException &&
          error.code == 'email_verification_required') {
        final details = _asMap(error.details);
        setState(() {
          _verificationMeta = details;
          _notice = error.message;
          _flow = _AuthFlow.verifyEmail;
          if (details?['email'] != null) {
            _email.text = details!['email'].toString();
          }
        });
      } else {
        _setError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resendVerificationCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AuthService.instance.resendVerificationCode(
        _email.text.trim(),
      );
      setState(() {
        _verificationMeta = _asMap(data['verification']) ?? _verificationMeta;
        _notice =
            data['message']?.toString() ?? 'Enviamos um novo código de verificação.';
      });
    } catch (error) {
      _setError(
        error,
        fallback: 'Não foi possível reenviar o código de verificação agora.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  String get _title {
    switch (_flow) {
      case _AuthFlow.login:
        return 'Acesse sua conta';
      case _AuthFlow.register:
        return 'Crie sua conta';
      case _AuthFlow.verifyEmail:
        return 'Confirme seu e-mail';
      case _AuthFlow.forgotPassword:
        return 'Recupere o acesso';
      case _AuthFlow.verifyResetCode:
        return 'Valide o código';
      case _AuthFlow.resetPassword:
        return 'Defina uma nova senha';
    }
  }

  String get _subtitle {
    switch (_flow) {
      case _AuthFlow.login:
        return 'Entre com e-mail e senha para continuar no ambiente operacional.';
      case _AuthFlow.register:
        return 'Cadastre uma nova conta para começar a usar o sistema.';
      case _AuthFlow.verifyEmail:
        return 'Informe o código enviado para o e-mail cadastrado.';
      case _AuthFlow.forgotPassword:
        return 'Informe o e-mail cadastrado para receber o código de recuperação.';
      case _AuthFlow.verifyResetCode:
        return 'Digite o código recebido para validar a redefinição.';
      case _AuthFlow.resetPassword:
        return 'Crie uma nova senha para concluir a recuperação.';
    }
  }

  String get _submitLabel {
    if (_loading) {
      return 'Aguarde...';
    }
    switch (_flow) {
      case _AuthFlow.login:
        return 'Entrar';
      case _AuthFlow.register:
        return 'Criar conta';
      case _AuthFlow.verifyEmail:
        return 'Confirmar e acessar';
      case _AuthFlow.forgotPassword:
        return 'Enviar código';
      case _AuthFlow.verifyResetCode:
        return 'Validar código';
      case _AuthFlow.resetPassword:
        return 'Salvar nova senha';
    }
  }

  int get _progressStep {
    switch (_flow) {
      case _AuthFlow.register:
        return 1;
      case _AuthFlow.verifyEmail:
      case _AuthFlow.verifyResetCode:
      case _AuthFlow.resetPassword:
        return 2;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final maskedEmail = _verificationMeta?['maskedEmail']?.toString();

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppTokens.softBackgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.space5),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppHeroBanner(
                      title: AppConfig.appName,
                      subtitle: AppConfig.appTagline,
                      trailing: const CircleAvatar(
                        radius: 28,
                        backgroundColor: Color(0x1FFFFFFF),
                        child: BrandLogo(height: 34),
                      ),
                      metrics: [
                        AppHeroMetric(
                          label: 'Etapa',
                          value: _flow == _AuthFlow.login ? 'Login' : 'Conta',
                        ),
                        AppHeroMetric(
                          label: 'Fluxo',
                          value: _flow == _AuthFlow.login ? 'Acesso' : 'Verificação',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space5),
                    AppSurface(
                      padding: const EdgeInsets.all(AppTokens.space5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_flow == _AuthFlow.login ||
                              _flow == _AuthFlow.register) ...[
                            SegmentedButton<_AuthFlow>(
                              segments: const [
                                ButtonSegment(
                                  value: _AuthFlow.login,
                                  label: Text('Entrar'),
                                ),
                                ButtonSegment(
                                  value: _AuthFlow.register,
                                  label: Text('Criar conta'),
                                ),
                              ],
                              selected: {_flow},
                              onSelectionChanged: _loading
                                  ? null
                                  : (value) => _switchTo(value.first),
                            ),
                            const SizedBox(height: AppTokens.space5),
                          ],
                          _FlowProgress(step: _progressStep),
                          const SizedBox(height: AppTokens.space4),
                          Text(
                            _title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _subtitle,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppTokens.space5),
                          if (_notice != null) ...[
                            AppMessageBanner(
                              message: _notice!,
                              icon: Icons.mark_email_read_outlined,
                            ),
                            const SizedBox(height: AppTokens.space3),
                          ],
                          if (_error != null) ...[
                            AppMessageBanner(
                              message: _error!,
                              icon: Icons.error_outline_rounded,
                              toneColor: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(height: AppTokens.space3),
                          ],
                          if (_flow == _AuthFlow.register) ...[
                            AppTextField(
                              label: 'Nome completo',
                              controller: _name,
                              hintText: 'Informe seu nome completo',
                            ),
                            const SizedBox(height: AppTokens.space4),
                          ],
                          AppTextField(
                            label: 'E-mail',
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            enabled: ![
                              _AuthFlow.verifyEmail,
                              _AuthFlow.verifyResetCode,
                              _AuthFlow.resetPassword,
                            ].contains(_flow),
                            hintText: 'voce@empresa.com.br',
                          ),
                          if (_flow == _AuthFlow.login ||
                              _flow == _AuthFlow.register) ...[
                            const SizedBox(height: AppTokens.space4),
                            AppTextField(
                              label: 'Senha',
                              controller: _password,
                              obscureText: true,
                              hintText: 'Digite sua senha',
                              suffixIcon: const Icon(Icons.lock_outline_rounded),
                            ),
                          ],
                          if (_flow == _AuthFlow.register) ...[
                            const SizedBox(height: AppTokens.space4),
                            AppTextField(
                              label: 'Confirmar senha',
                              controller: _passwordConfirm,
                              obscureText: true,
                              hintText: 'Repita a senha informada',
                              suffixIcon: const Icon(Icons.lock_outline_rounded),
                            ),
                          ],
                          if (_flow == _AuthFlow.verifyEmail ||
                              _flow == _AuthFlow.verifyResetCode) ...[
                            const SizedBox(height: AppTokens.space4),
                            AppTextField(
                              label: 'Código de verificação',
                              controller: _code,
                              keyboardType: TextInputType.number,
                              hintText: 'Informe o código de 6 dígitos',
                              onChanged: (value) {
                                final digitsOnly =
                                    value.replaceAll(RegExp(r'[^0-9]'), '');
                                if (digitsOnly != value) {
                                  _code.value = TextEditingValue(
                                    text: digitsOnly,
                                    selection: TextSelection.collapsed(
                                      offset: digitsOnly.length,
                                    ),
                                  );
                                }
                              },
                            ),
                            if (_flow == _AuthFlow.verifyEmail &&
                                maskedEmail != null &&
                                maskedEmail.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Código enviado para $maskedEmail.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                          if (_flow == _AuthFlow.resetPassword) ...[
                            const SizedBox(height: AppTokens.space4),
                            AppTextField(
                              label: 'Nova senha',
                              controller: _newPassword,
                              obscureText: true,
                              hintText: 'Crie uma nova senha',
                              suffixIcon: const Icon(Icons.lock_outline_rounded),
                            ),
                            const SizedBox(height: AppTokens.space4),
                            AppTextField(
                              label: 'Confirmar nova senha',
                              controller: _newPasswordConfirm,
                              obscureText: true,
                              hintText: 'Repita a nova senha',
                              suffixIcon: const Icon(Icons.lock_outline_rounded),
                            ),
                          ],
                          const SizedBox(height: AppTokens.space5),
                          ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: Text(_submitLabel),
                          ),
                          const SizedBox(height: AppTokens.space3),
                          _buildFooterActions(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterActions() {
    final bodySmall = Theme.of(context).textTheme.bodySmall;

    switch (_flow) {
      case _AuthFlow.login:
        return Column(
          children: [
            TextButton(
              onPressed: _loading ? null : () => _switchTo(_AuthFlow.forgotPassword),
              child: const Text('Esqueci minha senha'),
            ),
            Text(
              'A conta precisa estar verificada para liberar o acesso completo.',
              textAlign: TextAlign.center,
              style: bodySmall,
            ),
          ],
        );
      case _AuthFlow.register:
        return Text(
          'Novos cadastros são criados como visitante até a confirmação do e-mail.',
          textAlign: TextAlign.center,
          style: bodySmall,
        );
      case _AuthFlow.verifyEmail:
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 0,
          children: [
            TextButton(
              onPressed: _loading ? null : _resendVerificationCode,
              child: const Text('Reenviar código'),
            ),
            TextButton(
              onPressed: _loading ? null : () => _switchTo(_AuthFlow.login),
              child: const Text('Voltar para o login'),
            ),
          ],
        );
      case _AuthFlow.forgotPassword:
        return TextButton(
          onPressed: _loading ? null : () => _switchTo(_AuthFlow.login),
          child: const Text('Voltar para o login'),
        );
      case _AuthFlow.verifyResetCode:
      case _AuthFlow.resetPassword:
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            TextButton(
              onPressed: _loading ? null : () => _switchTo(_AuthFlow.forgotPassword),
              child: const Text('Alterar e-mail'),
            ),
            TextButton(
              onPressed: _loading ? null : () => _switchTo(_AuthFlow.login),
              child: const Text('Voltar para o login'),
            ),
          ],
        );
    }
  }
}

class _FlowProgress extends StatelessWidget {
  const _FlowProgress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final idleColor =
        Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7);
    return Row(
      children: List.generate(
        2,
        (index) => Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(right: index == 0 ? 8 : 0),
            decoration: BoxDecoration(
              color: index < step ? activeColor : idleColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

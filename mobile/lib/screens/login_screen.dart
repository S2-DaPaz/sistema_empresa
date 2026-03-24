import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors/app_exception.dart';
import '../services/auth_service.dart';
import '../theme/app_assets.dart';
import '../theme/app_tokens.dart';
import '../widgets/brand_logo.dart';
import '../widgets/otp_input_group.dart';

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
  static const _rememberEmailKey = 'auth_remember_email';
  static const _rememberFlagKey = 'auth_remember_enabled';

  _AuthFlow _flow = _AuthFlow.login;
  bool _loading = false;
  bool _rememberMe = true;
  bool _acceptTerms = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _obscureNewPassword = true;
  bool _obscureNewPasswordConfirm = true;
  String? _error;
  String? _notice;
  Map<String, dynamic>? _verificationMeta;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _passwordConfirm = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _newPasswordConfirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    _restoreRememberedEmail();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _code.dispose();
    _newPassword.dispose();
    _newPasswordConfirm.dispose();
    super.dispose();
  }

  Future<void> _restoreRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final remembered = prefs.getBool(_rememberFlagKey) ?? true;
    final rememberedEmail = prefs.getString(_rememberEmailKey) ?? '';
    if (!mounted) return;
    setState(() {
      _rememberMe = remembered;
      if (rememberedEmail.isNotEmpty) {
        _email.text = rememberedEmail;
      }
    });
  }

  Future<void> _persistRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberFlagKey, _rememberMe);
    if (_rememberMe) {
      await prefs.setString(_rememberEmailKey, _email.text.trim());
    } else {
      await prefs.remove(_rememberEmailKey);
    }
  }

  void _switchTo(_AuthFlow flow) {
    setState(() {
      _flow = flow;
      _error = null;
      _notice = null;
      if (flow == _AuthFlow.login || flow == _AuthFlow.register) {
        _code.clear();
      }
    });
  }

  void _setError(Object error, {String? fallback}) {
    setState(() {
      _error = error is AppException
          ? error.message
          : fallback ?? 'Não foi possível concluir a operação agora.';
    });
  }

  void _startResendTimer([int seconds = 60]) {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = seconds);
    if (seconds <= 0) return;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  void _applyVerificationMeta(Map<String, dynamic>? meta) {
    _verificationMeta = meta;
    final seconds = (meta?['resendCooldownSeconds'] as num?)?.toInt() ?? 60;
    _startResendTimer(seconds);
  }

  void _validatePasswordMatch(String password, String confirmation) {
    if (password != confirmation) {
      throw AppException(
        message: 'As senhas informadas não coincidem.',
        category: 'validation_error',
        code: 'password_mismatch',
      );
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      switch (_flow) {
        case _AuthFlow.login:
          await AuthService.instance.login(
            _email.text.trim(),
            _password.text,
          );
          await _persistRememberedEmail();
          return;
        case _AuthFlow.register:
          if (!_acceptTerms) {
            throw AppException(
              message: 'Você precisa aceitar os termos para criar a conta.',
              category: 'validation_error',
              code: 'legal_terms_required',
            );
          }
          _validatePasswordMatch(_password.text, _passwordConfirm.text);
          final data = await AuthService.instance.register(
            _name.text.trim(),
            _email.text.trim(),
            _password.text,
          );
          if (!mounted) return;
          setState(() {
            _notice = data['message']?.toString();
            _flow = _AuthFlow.verifyEmail;
          });
          _applyVerificationMeta(_asMap(data['verification']));
          return;
        case _AuthFlow.verifyEmail:
          await AuthService.instance.verifyEmail(
            _email.text.trim(),
            _code.text.trim(),
          );
          await _persistRememberedEmail();
          return;
        case _AuthFlow.forgotPassword:
          final data = await AuthService.instance.requestPasswordReset(
            _email.text.trim(),
          );
          if (!mounted) return;
          setState(() {
            _notice = data['message']?.toString();
            _flow = _AuthFlow.verifyResetCode;
          });
          _startResendTimer();
          return;
        case _AuthFlow.verifyResetCode:
          final data = await AuthService.instance.verifyPasswordResetCode(
            _email.text.trim(),
            _code.text.trim(),
          );
          if (!mounted) return;
          setState(() {
            _notice = data['message']?.toString();
            _flow = _AuthFlow.resetPassword;
          });
          return;
        case _AuthFlow.resetPassword:
          _validatePasswordMatch(
            _newPassword.text,
            _newPasswordConfirm.text,
          );
          final data = await AuthService.instance.resetPassword(
            _email.text.trim(),
            _code.text.trim(),
            _newPassword.text,
          );
          if (!mounted) return;
          setState(() {
            _notice =
                data['message']?.toString() ?? 'Senha atualizada com sucesso.';
            _flow = _AuthFlow.login;
            _password.clear();
            _passwordConfirm.clear();
            _newPassword.clear();
            _newPasswordConfirm.clear();
            _code.clear();
          });
          return;
      }
    } catch (error) {
      if (_flow == _AuthFlow.login &&
          error is AppException &&
          error.code == 'email_verification_required') {
        final details = _asMap(error.details);
        if (!mounted) return;
        setState(() {
          _flow = _AuthFlow.verifyEmail;
          _notice = error.message;
          if (details?['email'] != null) {
            _email.text = details!['email'].toString();
          }
        });
        _applyVerificationMeta(details);
      } else {
        _setError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resendCode() async {
    if (_resendSeconds > 0 || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_flow == _AuthFlow.verifyEmail) {
        final data = await AuthService.instance.resendVerificationCode(
          _email.text.trim(),
        );
        if (!mounted) return;
        setState(() => _notice = data['message']?.toString());
        _applyVerificationMeta(_asMap(data['verification']));
      } else if (_flow == _AuthFlow.verifyResetCode) {
        final data = await AuthService.instance.requestPasswordReset(
          _email.text.trim(),
        );
        if (!mounted) return;
        setState(() => _notice = data['message']?.toString());
        _startResendTimer();
      }
    } catch (error) {
      _setError(error, fallback: 'Não foi possível reenviar o código agora.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String get _title {
    switch (_flow) {
      case _AuthFlow.login:
        return 'Bem-vindo de volta!';
      case _AuthFlow.register:
        return 'Criar conta';
      case _AuthFlow.verifyEmail:
        return 'Verifique seu e-mail';
      case _AuthFlow.forgotPassword:
        return 'Recuperar senha';
      case _AuthFlow.verifyResetCode:
        return 'Validar código';
      case _AuthFlow.resetPassword:
        return 'Definir nova senha';
    }
  }

  String get _subtitle {
    switch (_flow) {
      case _AuthFlow.login:
        return 'Acesse sua conta para continuar.';
      case _AuthFlow.register:
        return 'Vamos começar com seus dados.';
      case _AuthFlow.verifyEmail:
        final maskedEmail = _verificationMeta?['maskedEmail']?.toString();
        if (maskedEmail != null && maskedEmail.isNotEmpty) {
          return 'Enviamos um código de 6 dígitos para $maskedEmail.';
        }
        return 'Digite o código de 6 dígitos enviado para o seu e-mail.';
      case _AuthFlow.forgotPassword:
        return 'Digite seu e-mail e enviaremos um código para redefinir a senha.';
      case _AuthFlow.verifyResetCode:
        return 'Informe o código recebido para continuar a redefinição.';
      case _AuthFlow.resetPassword:
        return 'Crie uma nova senha para concluir o processo.';
    }
  }

  String get _submitLabel {
    if (_loading) return 'Aguarde...';
    switch (_flow) {
      case _AuthFlow.login:
        return 'Entrar';
      case _AuthFlow.register:
        return 'Criar conta';
      case _AuthFlow.verifyEmail:
        return 'Verificar código';
      case _AuthFlow.forgotPassword:
        return 'Enviar código';
      case _AuthFlow.verifyResetCode:
        return 'Validar código';
      case _AuthFlow.resetPassword:
        return 'Salvar nova senha';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    _buildHeader(),
                    const SizedBox(height: 28),
                    Text(
                      _title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.muted,
                          ),
                    ),
                    const SizedBox(height: 24),
                    if (_notice != null) ...[
                      _InlineMessage(
                        text: _notice!,
                        color: AppColors.primary,
                        background: AppColors.primarySoft,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_error != null) ...[
                      _InlineMessage(
                        text: _error!,
                        color: AppColors.danger,
                        background: const Color(0xFFFFECEC),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildForm(),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(_submitLabel),
                    ),
                    const SizedBox(height: 16),
                    _buildFooter(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    switch (_flow) {
      case _AuthFlow.verifyEmail:
      case _AuthFlow.forgotPassword:
      case _AuthFlow.verifyResetCode:
      case _AuthFlow.resetPassword:
        return Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              IconButton(
                onPressed: () => _switchTo(_AuthFlow.login),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              const SizedBox(width: 4),
              const BrandLogo(height: 34),
            ],
          ),
        );
      case _AuthFlow.login:
      case _AuthFlow.register:
        return Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              if (_flow != _AuthFlow.login)
                IconButton(
                  onPressed: () => _switchTo(_AuthFlow.login),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
              const SizedBox(width: 4),
              const BrandLogo(height: 34),
            ],
          ),
        );
    }
  }

  Widget _buildForm() {
    switch (_flow) {
      case _AuthFlow.login:
        return Column(
          children: [
            _AppInput(
              label: 'E-mail',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _PasswordInput(
              label: 'Senha',
              controller: _password,
              obscureText: _obscurePassword,
              onToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (value) =>
                      setState(() => _rememberMe = value ?? true),
                ),
                const Expanded(
                  child: Text('Lembrar de mim'),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => _switchTo(_AuthFlow.forgotPassword),
                  child: const Text('Esqueci minha senha'),
                ),
              ],
            ),
          ],
        );
      case _AuthFlow.register:
        return Column(
          children: [
            _AppInput(
              label: 'Nome completo',
              controller: _name,
            ),
            const SizedBox(height: 12),
            _AppInput(
              label: 'E-mail',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _PasswordInput(
              label: 'Senha',
              controller: _password,
              obscureText: _obscurePassword,
              onToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            const SizedBox(height: 12),
            _PasswordInput(
              label: 'Confirmar senha',
              controller: _passwordConfirm,
              obscureText: _obscurePasswordConfirm,
              onToggle: () => setState(
                () => _obscurePasswordConfirm = !_obscurePasswordConfirm,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _acceptTerms,
                  onChanged: (value) =>
                      setState(() => _acceptTerms = value ?? false),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Eu concordo com os Termos de Uso e a Política de Privacidade.',
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      case _AuthFlow.verifyEmail:
      case _AuthFlow.verifyResetCode:
        return Column(
          children: [
            _TopIllustration(
              asset: _flow == _AuthFlow.verifyEmail
                  ? AppAssets.authEmailVerify
                  : AppAssets.authCode,
            ),
            const SizedBox(height: 20),
            OtpInputGroup(
              length: 6,
              value: _code.text,
              onChanged: (value) {
                _code.text = value;
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _resendSeconds > 0 ? null : _resendCode,
              child: Text(
                _resendSeconds > 0
                    ? 'Reenviar código (00:${_resendSeconds.toString().padLeft(2, '0')})'
                    : 'Reenviar código',
              ),
            ),
            const SizedBox(height: 8),
            _HintCard(
              text: _flow == _AuthFlow.verifyEmail
                  ? 'Não recebeu o código? Verifique sua caixa de spam ou solicite um novo envio.'
                  : 'Se o código expirou, solicite um novo envio para continuar.',
            ),
          ],
        );
      case _AuthFlow.forgotPassword:
        return Column(
          children: [
            const _TopIllustration(asset: AppAssets.authLock),
            const SizedBox(height: 20),
            _AppInput(
              label: 'E-mail',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        );
      case _AuthFlow.resetPassword:
        return Column(
          children: [
            _PasswordInput(
              label: 'Nova senha',
              controller: _newPassword,
              obscureText: _obscureNewPassword,
              onToggle: () =>
                  setState(() => _obscureNewPassword = !_obscureNewPassword),
            ),
            const SizedBox(height: 12),
            _PasswordInput(
              label: 'Confirmar nova senha',
              controller: _newPasswordConfirm,
              obscureText: _obscureNewPasswordConfirm,
              onToggle: () => setState(
                () => _obscureNewPasswordConfirm = !_obscureNewPasswordConfirm,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildFooter() {
    switch (_flow) {
      case _AuthFlow.login:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Não tem uma conta?'),
            TextButton(
              onPressed: _loading ? null : () => _switchTo(_AuthFlow.register),
              child: const Text('Criar conta'),
            ),
          ],
        );
      case _AuthFlow.register:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Já tem uma conta?'),
            TextButton(
              onPressed: _loading ? null : () => _switchTo(_AuthFlow.login),
              child: const Text('Entrar'),
            ),
          ],
        );
      case _AuthFlow.verifyEmail:
        return TextButton(
          onPressed: _loading ? null : () => _switchTo(_AuthFlow.login),
          child: const Text('Voltar para o login'),
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
              onPressed:
                  _loading ? null : () => _switchTo(_AuthFlow.forgotPassword),
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

class _TopIllustration extends StatelessWidget {
  const _TopIllustration({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 124,
        height: 104,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SvgPicture.asset(
          asset,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.text,
    required this.color,
    required this.background,
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _AppInput extends StatelessWidget {
  const _AppInput({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
        ),
      ],
    );
  }
}

class _PasswordInput extends StatelessWidget {
  const _PasswordInput({
    required this.label,
    required this.controller,
    required this.obscureText,
    required this.onToggle,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

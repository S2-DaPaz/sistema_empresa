import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  bool _rememberMe = true;
  bool _acceptTerms = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _obscureNewPassword = true;
  bool _obscureNewPasswordConfirm = true;
  String? _error;
  String? _notice;
  Map<String, dynamic>? _verificationMeta;
  Timer? _cooldownTimer;
  int _resendCooldownSeconds = 0;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _passwordConfirm = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _newPasswordConfirm = TextEditingController();

  @override
  void dispose() {
    _cooldownTimer?.cancel();
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
    _cooldownTimer?.cancel();
    setState(() {
      _flow = flow;
      _error = null;
      _notice = null;
      if (flow != _AuthFlow.verifyEmail) {
        _resendCooldownSeconds = 0;
      }
    });
  }

  void _handleBack() {
    switch (_flow) {
      case _AuthFlow.login:
        return;
      case _AuthFlow.register:
      case _AuthFlow.verifyEmail:
      case _AuthFlow.forgotPassword:
        _switchTo(_AuthFlow.login);
        return;
      case _AuthFlow.verifyResetCode:
        _switchTo(_AuthFlow.forgotPassword);
        return;
      case _AuthFlow.resetPassword:
        _switchTo(_AuthFlow.verifyResetCode);
        return;
    }
  }

  void _setError(Object error, {String? fallback}) {
    setState(() {
      _error = error is AppException
          ? error.message
          : fallback ?? 'Nao foi possivel concluir a operacao agora.';
    });
  }

  void _setVerificationMeta(Map<String, dynamic>? meta) {
    _verificationMeta = meta;
    final seconds =
        int.tryParse(meta?['resendCooldownSeconds']?.toString() ?? '');
    _startCooldown(seconds ?? 0);
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    if (seconds <= 0) {
      if (mounted) {
        setState(() => _resendCooldownSeconds = 0);
      }
      return;
    }

    setState(() => _resendCooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _resendCooldownSeconds = 0);
        return;
      }
      setState(() => _resendCooldownSeconds -= 1);
    });
  }

  void _validatePasswordConfirmation(String password, String confirmation) {
    if (password != confirmation) {
      throw AppException(
        message: 'As senhas informadas nao coincidem.',
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
          rememberSession: _rememberMe,
        );
        return;
      }

      if (_flow == _AuthFlow.register) {
        if (!_acceptTerms) {
          throw AppException(
            message: 'Aceite os Termos de Uso para criar a conta.',
            category: 'validation_error',
            code: 'terms_required',
          );
        }
        _validatePasswordConfirmation(_password.text, _passwordConfirm.text);
        final data = await AuthService.instance.register(
          _name.text.trim(),
          _email.text.trim(),
          _password.text,
        );
        setState(() {
          _setVerificationMeta(_asMap(data['verification']));
          _notice = data['message']?.toString() ??
              'Conta criada com sucesso. Enviamos um codigo para o seu e-mail.';
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
              'Se o e-mail informado estiver cadastrado, voce recebera um codigo.';
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
              data['message']?.toString() ?? 'Codigo validado com sucesso.';
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
          _setVerificationMeta(details);
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
    if (_resendCooldownSeconds > 0) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await AuthService.instance.resendVerificationCode(
        _email.text.trim(),
      );
      setState(() {
        _setVerificationMeta(_asMap(data['verification']) ?? _verificationMeta);
        _notice = data['message']?.toString() ??
            'Enviamos um novo codigo de verificacao.';
      });
    } catch (error) {
      _setError(
        error,
        fallback: 'Nao foi possivel reenviar o codigo agora.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showGoogleMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'A autenticacao com Google depende da configuracao OAuth desta instalacao.',
        ),
      ),
    );
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
        return 'Bem-vindo de volta';
      case _AuthFlow.register:
        return 'Criar sua conta';
      case _AuthFlow.verifyEmail:
        return 'Verificar e-mail';
      case _AuthFlow.forgotPassword:
        return 'Recuperar senha';
      case _AuthFlow.verifyResetCode:
        return 'Validar codigo';
      case _AuthFlow.resetPassword:
        return 'Definir nova senha';
    }
  }

  String get _subtitle {
    switch (_flow) {
      case _AuthFlow.login:
        return 'Faca login para continuar no ambiente operacional.';
      case _AuthFlow.register:
        return 'Preencha seus dados para ativar a conta.';
      case _AuthFlow.verifyEmail:
        return 'Digite o codigo de 6 digitos enviado para o e-mail cadastrado.';
      case _AuthFlow.forgotPassword:
        return 'Informe o e-mail da conta para receber o codigo de recuperacao.';
      case _AuthFlow.verifyResetCode:
        return 'Confirme o codigo recebido antes de redefinir a senha.';
      case _AuthFlow.resetPassword:
        return 'Crie uma nova senha para concluir a recuperacao.';
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
        return 'Enviar codigo';
      case _AuthFlow.verifyResetCode:
        return 'Validar codigo';
      case _AuthFlow.resetPassword:
        return 'Salvar nova senha';
    }
  }

  List<_PasswordRuleState> get _passwordRules {
    final password =
        _flow == _AuthFlow.resetPassword ? _newPassword.text : _password.text;

    return [
      _PasswordRuleState(
        label: 'Minimo de 8 caracteres',
        ok: password.length >= 8,
      ),
      _PasswordRuleState(
        label: 'Pelo menos 1 letra',
        ok: RegExp(r'[A-Za-z]').hasMatch(password),
      ),
      _PasswordRuleState(
        label: 'Pelo menos 1 numero',
        ok: RegExp(r'\d').hasMatch(password),
      ),
    ];
  }

  String get _maskedEmail =>
      _verificationMeta?['maskedEmail']?.toString() ?? _email.text.trim();

  String get _cooldownLabel {
    final minutes = (_resendCooldownSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_resendCooldownSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppTokens.softBackgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (_flow == _AuthFlow.login)
                const _AuthBlueHeader(
                  title: 'Entrar',
                  subtitle: AppConfig.appName,
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.space4,
                    AppTokens.space3,
                    AppTokens.space4,
                    AppTokens.space2,
                  ),
                  child: Row(
                    children: [
                      _HeaderBackButton(onTap: _handleBack),
                      const SizedBox(width: AppTokens.space3),
                      Expanded(
                        child: Text(
                          _flow == _AuthFlow.register
                              ? 'Criar conta'
                              : _flow == _AuthFlow.verifyEmail
                                  ? 'Verificar e-mail'
                                  : _flow == _AuthFlow.forgotPassword
                                      ? 'Recuperar senha'
                                      : _flow == _AuthFlow.verifyResetCode
                                          ? 'Validar codigo'
                                          : 'Nova senha',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.space5,
                    AppTokens.space3,
                    AppTokens.space5,
                    AppTokens.space6,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_flow != _AuthFlow.login) _buildFlowIcon(),
                          AppSurface(
                            radius: AppTokens.radiusXl,
                            padding: const EdgeInsets.all(AppTokens.space6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _title,
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
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
                                    toneColor:
                                        Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(height: AppTokens.space3),
                                ],
                                ..._buildFlowFields(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlowIcon() {
    final (color, icon) = switch (_flow) {
      _AuthFlow.verifyEmail || _AuthFlow.verifyResetCode => (
          AppTokens.primaryBlue,
          Icons.verified_user_outlined,
        ),
      _AuthFlow.forgotPassword => (
          AppTokens.warning,
          Icons.lock_reset_rounded,
        ),
      _AuthFlow.resetPassword => (
          AppTokens.primaryBlue,
          Icons.password_rounded,
        ),
      _AuthFlow.register => (
          AppTokens.primaryBlue,
          Icons.person_add_alt_1_rounded,
        ),
      _AuthFlow.login => (
          AppTokens.primaryBlue,
          Icons.login_rounded,
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 30),
        ),
      ),
    );
  }

  List<Widget> _buildFlowFields() {
    return switch (_flow) {
      _AuthFlow.login => _buildLoginFields(),
      _AuthFlow.register => _buildRegisterFields(),
      _AuthFlow.verifyEmail => _buildVerifyEmailFields(),
      _AuthFlow.forgotPassword => _buildForgotPasswordFields(),
      _AuthFlow.verifyResetCode => _buildVerifyResetCodeFields(),
      _AuthFlow.resetPassword => _buildResetPasswordFields(),
    };
  }

  List<Widget> _buildLoginFields() {
    return [
      AppTextField(
        label: 'E-mail',
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        hintText: 'voce@empresa.com.br',
        prefixIcon: const Icon(Icons.mail_outline_rounded),
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
      ),
      const SizedBox(height: AppTokens.space4),
      AppTextField(
        label: 'Senha',
        controller: _password,
        obscureText: _obscurePassword,
        hintText: 'Digite sua senha',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.password],
      ),
      const SizedBox(height: AppTokens.space3),
      Row(
        children: [
          Expanded(
            child: CheckboxListTile(
              dense: true,
              value: _rememberMe,
              onChanged: (value) => setState(() => _rememberMe = value ?? true),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'Lembrar de mim',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          TextButton(
            onPressed:
                _loading ? null : () => _switchTo(_AuthFlow.forgotPassword),
            child: const Text('Esqueceu?'),
          ),
        ],
      ),
      const SizedBox(height: AppTokens.space3),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: Text(_submitLabel),
        ),
      ),
      const SizedBox(height: AppTokens.space4),
      const _AuthDivider(label: 'ou continue com'),
      const SizedBox(height: AppTokens.space4),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _loading ? null : _showGoogleMessage,
          icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
          label: const Text('Google'),
        ),
      ),
      const SizedBox(height: AppTokens.space4),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Nao tem conta? ',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TextButton(
            onPressed: _loading ? null : () => _switchTo(_AuthFlow.register),
            child: const Text('Criar conta'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildRegisterFields() {
    return [
      AppTextField(
        label: 'Nome completo',
        controller: _name,
        hintText: 'Informe seu nome completo',
        prefixIcon: const Icon(Icons.person_outline_rounded),
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: AppTokens.space4),
      AppTextField(
        label: 'E-mail',
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        hintText: 'voce@empresa.com.br',
        prefixIcon: const Icon(Icons.mail_outline_rounded),
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: AppTokens.space4),
      AppTextField(
        label: 'Senha',
        controller: _password,
        obscureText: _obscurePassword,
        hintText: 'Crie sua senha',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      const SizedBox(height: AppTokens.space4),
      AppTextField(
        label: 'Confirmar senha',
        controller: _passwordConfirm,
        obscureText: _obscurePasswordConfirm,
        hintText: 'Repita a senha',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: () => setState(
            () => _obscurePasswordConfirm = !_obscurePasswordConfirm,
          ),
          icon: Icon(
            _obscurePasswordConfirm
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      const SizedBox(height: AppTokens.space4),
      _PasswordRulesList(rules: _passwordRules),
      const SizedBox(height: AppTokens.space4),
      CheckboxListTile(
        value: _acceptTerms,
        onChanged: (value) => setState(() => _acceptTerms = value ?? false),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          'Aceito os Termos de Uso',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      const SizedBox(height: AppTokens.space3),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: Text(_submitLabel),
        ),
      ),
      const SizedBox(height: AppTokens.space4),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ja tem conta? ',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TextButton(
            onPressed: _loading ? null : () => _switchTo(_AuthFlow.login),
            child: const Text('Fazer login'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildVerifyEmailFields() {
    return [
      Text(
        'Codigo enviado para $_maskedEmail',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: AppTokens.space4),
      OtpInputGroup(
        value: _code.text,
        enabled: !_loading,
        onChanged: (value) => _code.text = value,
      ),
      const SizedBox(height: AppTokens.space4),
      if (_resendCooldownSeconds > 0)
        Text(
          'Reenvio disponivel em $_cooldownLabel',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      const SizedBox(height: AppTokens.space3),
      TextButton(
        onPressed: _loading || _resendCooldownSeconds > 0
            ? null
            : _resendVerificationCode,
        child: const Text('Nao recebeu o codigo?'),
      ),
      const SizedBox(height: AppTokens.space3),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: Text(_submitLabel),
        ),
      ),
      const SizedBox(height: AppTokens.space4),
      const AppInfoCallout(
        title: 'Verificacao obrigatoria',
        message:
            'A conta so libera acesso completo depois da confirmacao do e-mail.',
        icon: Icons.shield_outlined,
      ),
    ];
  }

  List<Widget> _buildForgotPasswordFields() {
    return [
      AppTextField(
        label: 'E-mail',
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        hintText: 'voce@empresa.com.br',
        prefixIcon: const Icon(Icons.mail_outline_rounded),
      ),
      const SizedBox(height: AppTokens.space4),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: const Icon(Icons.send_rounded),
          label: Text(_submitLabel),
        ),
      ),
      const SizedBox(height: AppTokens.space3),
      TextButton(
        onPressed: _loading ? null : () => _switchTo(_AuthFlow.login),
        child: const Text('Voltar ao login'),
      ),
      const SizedBox(height: AppTokens.space4),
      const AppInfoCallout(
        title: 'Codigo de 6 digitos',
        message:
            'Enviaremos um codigo temporario para o e-mail informado nesta conta.',
        icon: Icons.info_outline_rounded,
        color: AppTokens.warning,
      ),
    ];
  }

  List<Widget> _buildVerifyResetCodeFields() {
    return [
      AppTextField(
        label: 'E-mail',
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        hintText: 'voce@empresa.com.br',
        prefixIcon: const Icon(Icons.mail_outline_rounded),
        enabled: false,
      ),
      const SizedBox(height: AppTokens.space4),
      OtpInputGroup(
        value: _code.text,
        enabled: !_loading,
        onChanged: (value) => _code.text = value,
      ),
      const SizedBox(height: AppTokens.space4),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: Text(_submitLabel),
        ),
      ),
      const SizedBox(height: AppTokens.space3),
      Wrap(
        spacing: 8,
        alignment: WrapAlignment.center,
        children: [
          TextButton(
            onPressed:
                _loading ? null : () => _switchTo(_AuthFlow.forgotPassword),
            child: const Text('Alterar e-mail'),
          ),
          TextButton(
            onPressed: _loading ? null : () => _switchTo(_AuthFlow.login),
            child: const Text('Voltar ao login'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildResetPasswordFields() {
    return [
      AppTextField(
        label: 'Nova senha',
        controller: _newPassword,
        obscureText: _obscureNewPassword,
        hintText: 'Crie uma nova senha',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: () =>
              setState(() => _obscureNewPassword = !_obscureNewPassword),
          icon: Icon(
            _obscureNewPassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      const SizedBox(height: AppTokens.space4),
      AppTextField(
        label: 'Confirmar nova senha',
        controller: _newPasswordConfirm,
        obscureText: _obscureNewPasswordConfirm,
        hintText: 'Repita a nova senha',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: () => setState(
            () => _obscureNewPasswordConfirm = !_obscureNewPasswordConfirm,
          ),
          icon: Icon(
            _obscureNewPasswordConfirm
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      const SizedBox(height: AppTokens.space4),
      _PasswordRulesList(rules: _passwordRules),
      const SizedBox(height: AppTokens.space4),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: Text(_submitLabel),
        ),
      ),
    ];
  }
}

class _AuthBlueHeader extends StatelessWidget {
  const _AuthBlueHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 216,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppTokens.heroGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppTokens.radiusXl),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -28,
            top: 18,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -18,
            bottom: -10,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(40),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space5,
                AppTokens.space5,
                AppTokens.space5,
                AppTokens.space6,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Center(child: BrandLogo(height: 46)),
                  const SizedBox(height: AppTokens.space4),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBackButton extends StatelessWidget {
  const _HeaderBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.space3),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _PasswordRuleState {
  const _PasswordRuleState({
    required this.label,
    required this.ok,
  });

  final String label;
  final bool ok;
}

class _PasswordRulesList extends StatelessWidget {
  const _PasswordRulesList({required this.rules});

  final List<_PasswordRuleState> rules;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rules
          .map(
            (rule) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    rule.ok
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: rule.ok ? AppTokens.success : AppTokens.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rule.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: rule.ok
                                ? AppTokens.success
                                : AppTokens.textMuted,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class OtpInputGroup extends StatefulWidget {
  const OtpInputGroup({
    super.key,
    required this.value,
    required this.onChanged,
    this.length = 6,
    this.enabled = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final int length;
  final bool enabled;

  @override
  State<OtpInputGroup> createState() => _OtpInputGroupState();
}

class _OtpInputGroupState extends State<OtpInputGroup> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.length,
      (_) => TextEditingController(),
    );
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    _syncFromValue(widget.value);
  }

  @override
  void didUpdateWidget(covariant OtpInputGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _syncFromValue(widget.value);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _syncFromValue(String rawValue) {
    final digits = rawValue.replaceAll(RegExp(r'[^0-9]'), '');
    for (var index = 0; index < widget.length; index += 1) {
      _controllers[index].text = index < digits.length ? digits[index] : '';
    }
  }

  void _emitValue() {
    final buffer = StringBuffer();
    for (final controller in _controllers) {
      buffer.write(controller.text);
    }
    widget.onChanged(buffer.toString());
  }

  void _handleChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      _controllers[index].clear();
      _emitValue();
      return;
    }

    if (digits.length > 1) {
      for (var offset = 0; offset < digits.length; offset += 1) {
        final target = index + offset;
        if (target >= widget.length) break;
        _controllers[target].text = digits[offset];
      }
      final nextIndex = (index + digits.length).clamp(0, widget.length - 1);
      _focusNodes[nextIndex].requestFocus();
      _emitValue();
      return;
    }

    _controllers[index].text = digits;
    _emitValue();
    if (index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
    }
  }

  void _handleKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey != LogicalKeyboardKey.backspace) return;
    if (_controllers[index].text.isNotEmpty) {
      _controllers[index].clear();
      _emitValue();
      return;
    }
    if (index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      _emitValue();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        widget.length,
        (index) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == widget.length - 1 ? 0 : AppTokens.space2,
            ),
            child: Focus(
              onKeyEvent: (_, event) {
                _handleKeyEvent(index, event);
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                enabled: widget.enabled,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: Theme.of(context).textTheme.titleLarge,
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '0',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(vertical: 18),
                ),
                onChanged: (value) => _handleChanged(index, value),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

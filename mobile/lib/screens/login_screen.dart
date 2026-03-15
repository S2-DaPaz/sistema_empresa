import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/errors/app_exception.dart';
import '../services/auth_service.dart';
import '../widgets/brand_logo.dart';

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
          : fallback ?? 'Não foi possível concluir a operação no momento.';
    });
  }

  void _validatePasswordConfirmation(
    String password,
    String confirmation,
  ) {
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
        _validatePasswordConfirmation(
          _password.text,
          _passwordConfirm.text,
        );
        final data = await AuthService.instance.register(
          _name.text.trim(),
          _email.text.trim(),
          _password.text,
        );
        setState(() {
          _verificationMeta = _asMap(data['verification']);
          _notice = data['message']?.toString() ??
              'Enviamos um código de verificação para o seu e-mail.';
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
              'Se o e-mail informado estiver cadastrado, você receberá um código para redefinir sua senha.';
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
          _notice = data['message']?.toString() ??
              'Senha redefinida com sucesso.';
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
            data['message']?.toString() ?? 'Enviamos um novo código.';
      });
    } catch (error) {
      _setError(
        error,
        fallback:
            'Não foi possível reenviar o código de verificação no momento.',
      );
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
        return 'Acesse a sua conta';
      case _AuthFlow.register:
        return 'Crie a sua conta';
      case _AuthFlow.verifyEmail:
        return 'Confirme o seu e-mail';
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
        return 'Entre com seu e-mail e senha para continuar.';
      case _AuthFlow.register:
        return 'Cadastre uma nova conta para acessar o sistema.';
      case _AuthFlow.verifyEmail:
        return 'Informe o código enviado para o seu e-mail.';
      case _AuthFlow.forgotPassword:
        return 'Informe o e-mail cadastrado para receber o código de recuperação.';
      case _AuthFlow.verifyResetCode:
        return 'Digite o código recebido para continuar.';
      case _AuthFlow.resetPassword:
        return 'Crie uma nova senha para concluir a recuperação.';
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
        return 'Confirmar e acessar';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final maskedEmail = _verificationMeta?['maskedEmail']?.toString();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark ? const Color(0xFF0F1B2A) : const Color(0xFFF6FAFD),
              isDark ? const Color(0xFF0B1320) : const Color(0xFFEAF2F8),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 300;
                          final brandText = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppConfig.appName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppConfig.appTagline,
                                maxLines: isCompact ? 3 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          );

                          if (isCompact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Align(
                                  alignment: Alignment.centerRight,
                                  child: BrandLogo(height: 40),
                                ),
                                const SizedBox(height: 12),
                                brandText,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              const BrandLogo(height: 44),
                              const SizedBox(width: 12),
                              Expanded(child: brandText),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _subtitle,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
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
                        const SizedBox(height: 16),
                      ],
                      if (_notice != null) ...[
                        _MessageCard(
                          text: _notice!,
                          toneColor: theme.colorScheme.primary,
                          backgroundColor:
                              theme.colorScheme.primary.withValues(alpha: 0.08),
                          borderColor:
                              theme.colorScheme.primary.withValues(alpha: 0.18),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_error != null) ...[
                        _MessageCard(
                          text: _error!,
                          toneColor: theme.colorScheme.error,
                          backgroundColor:
                              theme.colorScheme.error.withValues(alpha: 0.08),
                          borderColor:
                              theme.colorScheme.error.withValues(alpha: 0.18),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_flow == _AuthFlow.register) ...[
                        TextField(
                          controller: _name,
                          textInputAction: TextInputAction.next,
                          decoration:
                              const InputDecoration(labelText: 'Nome completo'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        enabled: ![
                          _AuthFlow.verifyEmail,
                          _AuthFlow.verifyResetCode,
                          _AuthFlow.resetPassword,
                        ].contains(_flow),
                        decoration: const InputDecoration(labelText: 'E-mail'),
                      ),
                      if (_flow == _AuthFlow.login || _flow == _AuthFlow.register) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(labelText: 'Senha'),
                        ),
                      ],
                      if (_flow == _AuthFlow.register) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordConfirm,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          decoration:
                              const InputDecoration(labelText: 'Confirmar senha'),
                        ),
                      ],
                      if (_flow == _AuthFlow.verifyEmail ||
                          _flow == _AuthFlow.verifyResetCode) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _code,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
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
                          decoration: const InputDecoration(
                            labelText: 'Código',
                            hintText: 'Informe o código de 6 dígitos',
                          ),
                        ),
                        if (_flow == _AuthFlow.verifyEmail &&
                            maskedEmail != null &&
                            maskedEmail.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Código enviado para $maskedEmail.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                      if (_flow == _AuthFlow.resetPassword) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _newPassword,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          decoration:
                              const InputDecoration(labelText: 'Nova senha'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _newPasswordConfirm,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Confirmar nova senha',
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: Text(_submitLabel),
                      ),
                      const SizedBox(height: 12),
                      _buildFooterActions(theme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterActions(ThemeData theme) {
    switch (_flow) {
      case _AuthFlow.login:
        return Column(
          children: [
            TextButton(
              onPressed: _loading ? null : () => _switchTo(_AuthFlow.forgotPassword),
              child: const Text('Esqueci minha senha'),
            ),
            Text(
              'A conta precisa estar verificada para liberar o acesso.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        );
      case _AuthFlow.register:
        return Text(
          'Novos cadastros são criados como visitante até a confirmação do e-mail.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        );
      case _AuthFlow.verifyEmail:
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
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

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.text,
    required this.toneColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String text;
  final Color toneColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(color: toneColor),
      ),
    );
  }
}

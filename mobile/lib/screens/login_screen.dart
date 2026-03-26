import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../features/auth/presentation/auth_flow_controller.dart';
import '../theme/app_assets.dart';
import '../theme/app_tokens.dart';
import '../widgets/brand_logo.dart';
import '../widgets/otp_input_group.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const double _authHeaderLogoHeight = 44;

  late final AuthFlowController _authFlowController;

  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _obscureNewPassword = true;
  bool _obscureNewPasswordConfirm = true;

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
    _authFlowController = AuthFlowController();
    _restoreRememberedEmail();
  }

  Future<void> _restoreRememberedEmail() async {
    final rememberedEmail = await _authFlowController.restoreRememberedEmail();
    if (!mounted || rememberedEmail == null || rememberedEmail.isEmpty) return;
    _email.text = rememberedEmail;
  }

  @override
  void dispose() {
    _authFlowController.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _code.dispose();
    _newPassword.dispose();
    _newPasswordConfirm.dispose();
    super.dispose();
  }

  AuthFlowStep get _step => _authFlowController.state.step;

  void _switchTo(AuthFlowStep step) {
    if (step == AuthFlowStep.login || step == AuthFlowStep.register) {
      _code.clear();
    }
    _authFlowController.switchTo(step);
  }

  Future<void> _submit() async {
    try {
      final outcome = await _authFlowController.submit(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        passwordConfirmation: _passwordConfirm.text,
        code: _code.text.trim(),
        newPassword: _newPassword.text,
        newPasswordConfirmation: _newPasswordConfirm.text,
      );
      if (!mounted) return;

      if (outcome.prefillEmail != null && outcome.prefillEmail!.isNotEmpty) {
        _email.text = outcome.prefillEmail!;
      }

      if (outcome.clearSensitiveFields) {
        _password.clear();
        _passwordConfirm.clear();
        _newPassword.clear();
        _newPasswordConfirm.clear();
        _code.clear();
      }
    } catch (_) {
      // O controller ja normaliza e publica a mensagem de erro.
    }
  }

  Future<void> _resendCode() async {
    try {
      await _authFlowController.resendCode(_email.text.trim());
    } catch (_) {
      // O controller ja mantem o feedback amigavel no estado.
    }
  }

  String get _title {
    switch (_step) {
      case AuthFlowStep.login:
        return 'Bem-vindo de volta!';
      case AuthFlowStep.register:
        return 'Criar conta';
      case AuthFlowStep.verifyEmail:
        return 'Verifique seu e-mail';
      case AuthFlowStep.forgotPassword:
        return 'Recuperar senha';
      case AuthFlowStep.verifyResetCode:
        return 'Validar codigo';
      case AuthFlowStep.resetPassword:
        return 'Definir nova senha';
    }
  }

  String get _subtitle {
    switch (_step) {
      case AuthFlowStep.login:
        return 'Acesse sua conta para continuar.';
      case AuthFlowStep.register:
        return 'Vamos comecar com seus dados.';
      case AuthFlowStep.verifyEmail:
        final maskedEmail =
            _authFlowController.state.verificationMeta?.maskedEmail;
        if (maskedEmail != null && maskedEmail.isNotEmpty) {
          return 'Enviamos um codigo de 6 digitos para $maskedEmail.';
        }
        return 'Digite o codigo de 6 digitos enviado para o seu e-mail.';
      case AuthFlowStep.forgotPassword:
        return 'Digite seu e-mail e enviaremos um codigo para redefinir a senha.';
      case AuthFlowStep.verifyResetCode:
        return 'Informe o codigo recebido para continuar a redefinicao.';
      case AuthFlowStep.resetPassword:
        return 'Crie uma nova senha para concluir o processo.';
    }
  }

  String _submitLabel(AuthFlowState state) {
    if (state.loading) return 'Aguarde...';
    switch (state.step) {
      case AuthFlowStep.login:
        return 'Entrar';
      case AuthFlowStep.register:
        return 'Criar conta';
      case AuthFlowStep.verifyEmail:
        return 'Verificar codigo';
      case AuthFlowStep.forgotPassword:
        return 'Enviar codigo';
      case AuthFlowStep.verifyResetCode:
        return 'Validar codigo';
      case AuthFlowStep.resetPassword:
        return 'Salvar nova senha';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authFlowController,
      builder: (context, _) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final state = _authFlowController.state;

        return Scaffold(
          backgroundColor:
              isDark ? AppDarkColors.backgroundBase : AppColors.background,
          body: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? AppGradients.darkScaffold
                        : const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFF7F9FC),
                              Color(0xFFF1F5FA),
                            ],
                          ),
                  ),
                ),
              ),
              if (isDark) ...[
                const Positioned(
                  top: -90,
                  left: -70,
                  child: _AuthBackgroundOrb(
                    size: 220,
                    color: AppDarkColors.glowPrimary,
                    opacity: 0.54,
                  ),
                ),
                const Positioned(
                  top: 60,
                  right: -110,
                  child: _AuthBackgroundOrb(
                    size: 280,
                    color: Color(0x1822B8FF),
                    opacity: 0.3,
                  ),
                ),
                const Positioned(
                  bottom: -110,
                  right: -70,
                  child: _AuthBackgroundOrb(
                    size: 220,
                    color: Color(0x18F4A640),
                    opacity: 0.22,
                  ),
                ),
              ],
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        24 + MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 40,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 8),
                                _buildHeader(state),
                                const SizedBox(height: 20),
                                _AuthCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildVisualLead(state),
                                      const SizedBox(height: 22),
                                      Text(
                                        _title,
                                        style: theme.textTheme.headlineMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _subtitle,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: isDark
                                              ? AppDarkColors.textSecondary
                                              : AppColors.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      if (state.notice != null) ...[
                                        _InlineMessage(
                                          text: state.notice!,
                                          color: isDark
                                              ? AppDarkColors.primarySoft
                                              : AppColors.primary,
                                          background: isDark
                                              ? AppDarkColors.primary
                                                  .withValues(alpha: 0.14)
                                              : AppColors.primarySoft,
                                          borderColor: isDark
                                              ? AppDarkColors.primary
                                                  .withValues(alpha: 0.22)
                                              : Colors.transparent,
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      if (state.error != null) ...[
                                        _InlineMessage(
                                          text: state.error!,
                                          color: isDark
                                              ? const Color(0xFFFFC2CD)
                                              : AppColors.danger,
                                          background: isDark
                                              ? AppDarkColors.error
                                                  .withValues(alpha: 0.14)
                                              : const Color(0xFFFFECEC),
                                          borderColor: isDark
                                              ? AppDarkColors.error
                                                  .withValues(alpha: 0.22)
                                              : Colors.transparent,
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      _buildForm(state),
                                      const SizedBox(height: 18),
                                      ElevatedButton(
                                        onPressed: state.loading ? null : _submit,
                                        child: Text(_submitLabel(state)),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildFooter(state),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(AuthFlowState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (state.step) {
      case AuthFlowStep.verifyEmail:
      case AuthFlowStep.forgotPassword:
      case AuthFlowStep.verifyResetCode:
      case AuthFlowStep.resetPassword:
        return Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              _HeaderActionButton(
                onPressed: () => _switchTo(AuthFlowStep.login),
                icon: Icons.arrow_back_ios_new_rounded,
              ),
              const SizedBox(width: 12),
              BrandLogo(
                height: _authHeaderLogoHeight,
                color: isDark ? Colors.white : null,
              ),
            ],
          ),
        );
      case AuthFlowStep.login:
      case AuthFlowStep.register:
        return Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              if (state.step != AuthFlowStep.login) ...[
                _HeaderActionButton(
                  onPressed: () => _switchTo(AuthFlowStep.login),
                  icon: Icons.arrow_back_ios_new_rounded,
                ),
                const SizedBox(width: 12),
              ],
              BrandLogo(
                height: _authHeaderLogoHeight,
                color: isDark ? Colors.white : null,
              ),
            ],
          ),
        );
    }
  }

  Widget _buildVisualLead(AuthFlowState state) {
    switch (state.step) {
      case AuthFlowStep.verifyEmail:
        return const _TopIllustration(asset: AppAssets.authEmailVerify);
      case AuthFlowStep.verifyResetCode:
        return const _TopIllustration(asset: AppAssets.authCode);
      case AuthFlowStep.forgotPassword:
      case AuthFlowStep.resetPassword:
        return const _TopIllustration(asset: AppAssets.authLock);
      case AuthFlowStep.login:
      case AuthFlowStep.register:
        return const _AuthMonogramHero();
    }
  }

  Widget _buildForm(AuthFlowState state) {
    final theme = Theme.of(context);

    switch (state.step) {
      case AuthFlowStep.login:
        return Column(
          children: [
            _AppInput(
              label: 'E-mail',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.alternate_email_rounded,
            ),
            const SizedBox(height: 12),
            _PasswordInput(
              label: 'Senha',
              controller: _password,
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              onToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: state.rememberMe,
                      onChanged: (value) =>
                          _authFlowController.setRememberMe(value ?? true),
                    ),
                    Text(
                      'Lembrar de mim',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                TextButton(
                  onPressed: state.loading
                      ? null
                      : () => _switchTo(AuthFlowStep.forgotPassword),
                  child: const Text('Esqueci minha senha'),
                ),
              ],
            ),
          ],
        );
      case AuthFlowStep.register:
        return Column(
          children: [
            _AppInput(
              label: 'Nome completo',
              controller: _name,
              prefixIcon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 12),
            _AppInput(
              label: 'E-mail',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.alternate_email_rounded,
            ),
            const SizedBox(height: 12),
            _PasswordInput(
              label: 'Senha',
              controller: _password,
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              onToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            const SizedBox(height: 12),
            _PasswordInput(
              label: 'Confirmar senha',
              controller: _passwordConfirm,
              prefixIcon: Icons.verified_user_outlined,
              obscureText: _obscurePasswordConfirm,
              onToggle: () => setState(
                () => _obscurePasswordConfirm = !_obscurePasswordConfirm,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.82 : 1,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.75),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: state.acceptTerms,
                    onChanged: (value) =>
                        _authFlowController.setAcceptTerms(value ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Eu concordo com os Termos de Uso e a Politica de Privacidade.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case AuthFlowStep.verifyEmail:
      case AuthFlowStep.verifyResetCode:
        return Column(
          children: [
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
              onPressed: state.resendSeconds > 0 ? null : _resendCode,
              child: Text(
                state.resendSeconds > 0
                    ? 'Reenviar codigo (00:${state.resendSeconds.toString().padLeft(2, '0')})'
                    : 'Reenviar codigo',
              ),
            ),
            const SizedBox(height: 8),
            _HintCard(
              text: state.step == AuthFlowStep.verifyEmail
                  ? 'Nao recebeu o codigo? Verifique sua caixa de spam ou solicite um novo envio.'
                  : 'Se o codigo expirou, solicite um novo envio para continuar.',
            ),
          ],
        );
      case AuthFlowStep.forgotPassword:
        return _AppInput(
          label: 'E-mail',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.alternate_email_rounded,
        );
      case AuthFlowStep.resetPassword:
        return Column(
          children: [
            _PasswordInput(
              label: 'Nova senha',
              controller: _newPassword,
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscureNewPassword,
              onToggle: () =>
                  setState(() => _obscureNewPassword = !_obscureNewPassword),
            ),
            const SizedBox(height: 12),
            _PasswordInput(
              label: 'Confirmar nova senha',
              controller: _newPasswordConfirm,
              prefixIcon: Icons.verified_user_outlined,
              obscureText: _obscureNewPasswordConfirm,
              onToggle: () => setState(
                () => _obscureNewPasswordConfirm = !_obscureNewPasswordConfirm,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildFooter(AuthFlowState state) {
    final theme = Theme.of(context);

    switch (state.step) {
      case AuthFlowStep.login:
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            Text('Nao tem uma conta?', style: theme.textTheme.bodySmall),
            TextButton(
              onPressed:
                  state.loading ? null : () => _switchTo(AuthFlowStep.register),
              child: const Text('Criar conta'),
            ),
          ],
        );
      case AuthFlowStep.register:
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            Text('Ja tem uma conta?', style: theme.textTheme.bodySmall),
            TextButton(
              onPressed:
                  state.loading ? null : () => _switchTo(AuthFlowStep.login),
              child: const Text('Entrar'),
            ),
          ],
        );
      case AuthFlowStep.verifyEmail:
      case AuthFlowStep.forgotPassword:
        return TextButton(
          onPressed: state.loading ? null : () => _switchTo(AuthFlowStep.login),
          child: const Text('Voltar para o login'),
        );
      case AuthFlowStep.verifyResetCode:
      case AuthFlowStep.resetPassword:
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton(
              onPressed: state.loading
                  ? null
                  : () => _switchTo(AuthFlowStep.forgotPassword),
              child: const Text('Alterar e-mail'),
            ),
            TextButton(
              onPressed: state.loading
                  ? null
                  : () => _switchTo(AuthFlowStep.login),
              child: const Text('Voltar para o login'),
            ),
          ],
        );
    }
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppDarkColors.surface1.withValues(alpha: 0.9)
            : theme.colorScheme.surface.withValues(alpha: 0.96),
        gradient: isDark ? AppGradients.darkSurface : null,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isDark
              ? AppDarkColors.primary.withValues(alpha: 0.14)
              : theme.colorScheme.outline.withValues(alpha: 0.5),
        ),
        boxShadow: isDark ? AppShadows.darkCard : AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: child,
      ),
    );
  }
}

class _AuthMonogramHero extends StatelessWidget {
  const _AuthMonogramHero();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isDark ? AppGradients.darkPrimaryAction : null,
          color: isDark ? null : AppColors.primarySoft,
          border: Border.all(
            color: isDark
                ? AppDarkColors.primary.withValues(alpha: 0.22)
                : Colors.transparent,
          ),
          boxShadow: isDark ? AppShadows.darkCard : const [],
        ),
        alignment: Alignment.center,
        child: BrandLogo(
          height: 44,
          monogram: true,
          color: isDark ? AppDarkColors.backgroundBase : AppColors.primary,
        ),
      ),
    );
  }
}

class _TopIllustration extends StatelessWidget {
  const _TopIllustration({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        width: 124,
        height: 104,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark
              ? AppDarkColors.surface2.withValues(alpha: 0.92)
              : AppColors.primarySoft,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDark
                ? AppDarkColors.primary.withValues(alpha: 0.18)
                : Colors.transparent,
          ),
          boxShadow: isDark ? AppShadows.darkGlow : const [],
        ),
        child: SvgPicture.asset(asset, fit: BoxFit.contain),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.text,
    required this.color,
    required this.background,
    required this.borderColor,
  });

  final String text;
  final Color color;
  final Color background;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppDarkColors.surface2.withValues(alpha: 0.84)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.8 : 1),
        ),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

class _AppInput extends StatelessWidget {
  const _AppInput({
    required this.label,
    required this.controller,
    required this.prefixIcon,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final IconData prefixIcon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            prefixIcon: Icon(prefixIcon),
          ),
        ),
      ],
    );
  }
}

class _PasswordInput extends StatelessWidget {
  const _PasswordInput({
    required this.label,
    required this.controller,
    required this.prefixIcon,
    required this.obscureText,
    required this.onToggle,
  });

  final String label;
  final TextEditingController controller;
  final IconData prefixIcon;
  final bool obscureText;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            prefixIcon: Icon(prefixIcon),
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

class _AuthBackgroundOrb extends StatelessWidget {
  const _AuthBackgroundOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.onPressed,
    required this.icon,
  });

  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? AppDarkColors.surface2.withValues(alpha: 0.9)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              theme.colorScheme.outline.withValues(alpha: isDark ? 0.76 : 0.6),
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}

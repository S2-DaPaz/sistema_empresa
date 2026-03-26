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
      // O controller já normaliza e publica a mensagem de erro.
    }
  }

  Future<void> _resendCode() async {
    try {
      await _authFlowController.resendCode(_email.text.trim());
    } catch (_) {
      // O controller já mantém o feedback amigável no estado.
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
        return 'Validar código';
      case AuthFlowStep.resetPassword:
        return 'Definir nova senha';
    }
  }

  String get _subtitle {
    switch (_step) {
      case AuthFlowStep.login:
        return 'Acesse sua conta para continuar.';
      case AuthFlowStep.register:
        return 'Vamos começar com seus dados.';
      case AuthFlowStep.verifyEmail:
        final maskedEmail =
            _authFlowController.state.verificationMeta?.maskedEmail;
        if (maskedEmail != null && maskedEmail.isNotEmpty) {
          return 'Enviamos um código de 6 dígitos para $maskedEmail.';
        }
        return 'Digite o código de 6 dígitos enviado para o seu e-mail.';
      case AuthFlowStep.forgotPassword:
        return 'Digite seu e-mail e enviaremos um código para redefinir a senha.';
      case AuthFlowStep.verifyResetCode:
        return 'Informe o código recebido para continuar a redefinição.';
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
        return 'Verificar código';
      case AuthFlowStep.forgotPassword:
        return 'Enviar código';
      case AuthFlowStep.verifyResetCode:
        return 'Validar código';
      case AuthFlowStep.resetPassword:
        return 'Salvar nova senha';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authFlowController,
      builder: (context, _) {
        final state = _authFlowController.state;
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
                        _buildHeader(state),
                        const SizedBox(height: 28),
                        Text(
                          _title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _subtitle,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.muted,
                                  ),
                        ),
                        const SizedBox(height: 24),
                        if (state.notice != null) ...[
                          _InlineMessage(
                            text: state.notice!,
                            color: AppColors.primary,
                            background: AppColors.primarySoft,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (state.error != null) ...[
                          _InlineMessage(
                            text: state.error!,
                            color: AppColors.danger,
                            background: const Color(0xFFFFECEC),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _buildForm(state),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: state.loading ? null : _submit,
                          child: Text(_submitLabel(state)),
                        ),
                        const SizedBox(height: 16),
                        _buildFooter(state),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(AuthFlowState state) {
    switch (state.step) {
      case AuthFlowStep.verifyEmail:
      case AuthFlowStep.forgotPassword:
      case AuthFlowStep.verifyResetCode:
      case AuthFlowStep.resetPassword:
        return Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              IconButton(
                onPressed: () => _switchTo(AuthFlowStep.login),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              const SizedBox(width: 4),
              const BrandLogo(height: 34),
            ],
          ),
        );
      case AuthFlowStep.login:
      case AuthFlowStep.register:
        return Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              if (state.step != AuthFlowStep.login)
                IconButton(
                  onPressed: () => _switchTo(AuthFlowStep.login),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
              const SizedBox(width: 4),
              const BrandLogo(height: 34),
            ],
          ),
        );
    }
  }

  Widget _buildForm(AuthFlowState state) {
    switch (state.step) {
      case AuthFlowStep.login:
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
                  value: state.rememberMe,
                  onChanged: (value) =>
                      _authFlowController.setRememberMe(value ?? true),
                ),
                const Expanded(child: Text('Lembrar de mim')),
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
            _AppInput(label: 'Nome completo', controller: _name),
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
                  value: state.acceptTerms,
                  onChanged: (value) =>
                      _authFlowController.setAcceptTerms(value ?? false),
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
      case AuthFlowStep.verifyEmail:
      case AuthFlowStep.verifyResetCode:
        return Column(
          children: [
            _TopIllustration(
              asset: state.step == AuthFlowStep.verifyEmail
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
              onPressed: state.resendSeconds > 0 ? null : _resendCode,
              child: Text(
                state.resendSeconds > 0
                    ? 'Reenviar código (00:${state.resendSeconds.toString().padLeft(2, '0')})'
                    : 'Reenviar código',
              ),
            ),
            const SizedBox(height: 8),
            _HintCard(
              text: state.step == AuthFlowStep.verifyEmail
                  ? 'Não recebeu o código? Verifique sua caixa de spam ou solicite um novo envio.'
                  : 'Se o código expirou, solicite um novo envio para continuar.',
            ),
          ],
        );
      case AuthFlowStep.forgotPassword:
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
      case AuthFlowStep.resetPassword:
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
                () =>
                    _obscureNewPasswordConfirm = !_obscureNewPasswordConfirm,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildFooter(AuthFlowState state) {
    switch (state.step) {
      case AuthFlowStep.login:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Não tem uma conta?'),
            TextButton(
              onPressed:
                  state.loading ? null : () => _switchTo(AuthFlowStep.register),
              child: const Text('Criar conta'),
            ),
          ],
        );
      case AuthFlowStep.register:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Já tem uma conta?'),
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

import 'package:shared_preferences/shared_preferences.dart';

class RememberedEmailData {
  const RememberedEmailData({
    required this.enabled,
    required this.email,
  });

  final bool enabled;
  final String email;
}

abstract class AuthRememberMeStore {
  Future<RememberedEmailData> load();

  Future<void> save({
    required bool enabled,
    required String email,
  });
}

/// Isola o acesso ao `SharedPreferences` do fluxo de autenticação.
///
/// Isso mantém a tela focada em composição e permite testar o fluxo
/// de login/cadastro sem depender de armazenamento real.
class SharedPrefsAuthRememberMeStore implements AuthRememberMeStore {
  static const _rememberEmailKey = 'auth_remember_email';
  static const _rememberFlagKey = 'auth_remember_enabled';

  @override
  Future<RememberedEmailData> load() async {
    final prefs = await SharedPreferences.getInstance();
    return RememberedEmailData(
      enabled: prefs.getBool(_rememberFlagKey) ?? true,
      email: prefs.getString(_rememberEmailKey) ?? '',
    );
  }

  @override
  Future<void> save({
    required bool enabled,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberFlagKey, enabled);
    if (enabled) {
      await prefs.setString(_rememberEmailKey, email.trim());
    } else {
      await prefs.remove(_rememberEmailKey);
    }
  }
}

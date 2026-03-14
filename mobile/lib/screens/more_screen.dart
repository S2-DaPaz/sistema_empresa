import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../services/auth_service.dart';
import '../services/permissions.dart';
import '../services/theme_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/brand_logo.dart';
import '../widgets/section_header.dart';
import 'error_logs_screen.dart';
import 'event_logs_screen.dart';
import 'products_screen.dart';
import 'task_types_screen.dart';
import 'templates_screen.dart';
import 'users_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Mais',
      body: ValueListenableBuilder<AuthSession?>(
        valueListenable: AuthService.instance.session,
        builder: (context, session, _) {
          final name = session?.user['name']?.toString() ?? 'Visitante';
          final role = session?.user['role_name']?.toString() ??
              session?.user['role']?.toString() ??
              'visitante';
          final canViewUsers =
              AuthService.instance.hasPermission(Permissions.viewUsers);
          final isAdmin = AuthService.instance.isAdmin;

          return ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const BrandLogo(height: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConfig.appName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppConfig.appTagline,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            Text('$name - $role'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const SectionHeader(
                title: 'Preferências',
                subtitle: 'Aparência, tema e opções do app',
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeService.instance.mode,
                    builder: (context, mode, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tema do app',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(
                                value: ThemeMode.system,
                                label: Text('Sistema'),
                                icon: Icon(Icons.brightness_auto_outlined),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                label: Text('Claro'),
                                icon: Icon(Icons.light_mode_outlined),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                label: Text('Escuro'),
                                icon: Icon(Icons.dark_mode_outlined),
                              ),
                            ],
                            selected: {mode},
                            onSelectionChanged: (selection) {
                              ThemeService.instance
                                  .setThemeMode(selection.first);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isAdmin) ...[
                const SectionHeader(
                  title: 'Monitoramento',
                  subtitle: 'Investigação de erros e trilha de auditoria',
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('Logs de erro'),
                    subtitle: const Text('Falhas técnicas e erros reportados'),
                    onTap: () => _open(context, const ErrorLogsScreen()),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.history_toggle_off),
                    title: const Text('Log de eventos'),
                    subtitle: const Text('Rastreabilidade das ações do sistema'),
                    onTap: () => _open(context, const EventLogsScreen()),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SectionHeader(
                title: 'Acesso rapido',
                subtitle: 'Cadastros e configuracoes do sistema',
              ),
              const SizedBox(height: 12),
              if (canViewUsers)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Usuários'),
                    subtitle: const Text('Gestão de usuários do sistema'),
                    onTap: () => _open(context, const UsersScreen()),
                  ),
                ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Produtos'),
                  subtitle: const Text('Cadastro de itens de orçamento'),
                  onTap: () => _open(context, ProductsScreen()),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Tipos de tarefa'),
                  subtitle: const Text('Modelo de relatório por tipo'),
                  onTap: () => _open(context, const TaskTypesScreen()),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Modelos de relatório'),
                  subtitle: const Text('Campos dinâmicos para relatórios'),
                  onTap: () => _open(context, const TemplatesScreen()),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sair'),
                  onTap: () => AuthService.instance.logout(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

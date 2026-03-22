import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../services/auth_service.dart';
import '../services/permissions.dart';
import '../services/theme_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_ui.dart';
import '../widgets/brand_logo.dart';
import 'budgets_screen.dart';
import 'error_logs_screen.dart';
import 'event_logs_screen.dart';
import 'equipments_screen.dart';
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
      subtitle: 'Central de módulos, utilidades e área administrativa',
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

          final tiles = <_HubTile>[
            _HubTile(
              title: 'Produtos',
              subtitle: 'Catálogo e itens de orçamento',
              icon: Icons.inventory_2_outlined,
              color: AppTokens.primaryCyan,
              onTap: () => _open(context, const ProductsScreen()),
            ),
            _HubTile(
              title: 'Equipamentos',
              subtitle: 'Ativos, histórico e vínculo com clientes',
              icon: Icons.precision_manufacturing_outlined,
              color: AppTokens.supportTeal,
              onTap: () => _open(context, const EquipmentsScreen()),
            ),
            _HubTile(
              title: 'Orçamentos',
              subtitle: 'Pipeline comercial e propostas',
              icon: Icons.receipt_long_outlined,
              color: AppTokens.accentBlue,
              onTap: () => _open(context, const BudgetsScreen()),
            ),
            _HubTile(
              title: 'Templates',
              subtitle: 'Padronização de relatórios',
              icon: Icons.description_outlined,
              color: AppTokens.accentBlue,
              onTap: () => _open(context, const TemplatesScreen()),
            ),
            _HubTile(
              title: 'Tipos de tarefa',
              subtitle: 'Fluxos e modelos aplicados',
              icon: Icons.category_outlined,
              color: AppTokens.primaryCyan,
              onTap: () => _open(context, const TaskTypesScreen()),
            ),
            if (canViewUsers)
              _HubTile(
                title: 'Usuários',
                subtitle: 'Papéis, acessos e gestão de pessoas',
                icon: Icons.people_outline_rounded,
                color: const Color(0xFF111827),
                onTap: () => _open(context, const UsersScreen()),
              ),
            if (isAdmin)
              _HubTile(
                title: 'Logs de erro',
                subtitle: 'Falhas técnicas e tratamento',
                icon: Icons.error_outline_rounded,
                color: AppTokens.accentBlue,
                onTap: () => _open(context, const ErrorLogsScreen()),
              ),
            if (isAdmin)
              _HubTile(
                title: 'Log de eventos',
                subtitle: 'Auditoria operacional e rastreabilidade',
                icon: Icons.history_toggle_off_rounded,
                color: AppTokens.primaryCyan,
                onTap: () => _open(context, const EventLogsScreen()),
              ),
          ];

          return ListView(
            children: [
              AppHeroBanner(
                title: 'Hub operacional',
                subtitle: 'Acesso a produtos, equipamentos, templates, usuários, PDFs e monitoramento.',
                trailing: const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0x1FFFFFFF),
                  child: BrandLogo(height: 28),
                ),
                metrics: [
                  AppHeroMetric(label: 'Usuário', value: name.split(' ').first),
                  AppHeroMetric(label: 'Perfil', value: role),
                ],
              ),
              const SizedBox(height: AppTokens.space5),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeService.instance.mode,
                builder: (context, mode, _) {
                  return AppSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preferências do app',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${AppConfig.appName} • tema e acesso desta sessão',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppTokens.space4),
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
                            ThemeService.instance.setThemeMode(selection.first);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: AppTokens.space5),
              const AppSectionBlock(
                title: 'Atalhos',
                subtitle: 'Módulos auxiliares, administração e utilidades do sistema.',
              ),
              const SizedBox(height: AppTokens.space4),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.02,
                ),
                itemCount: tiles.length,
                itemBuilder: (context, index) {
                  final tile = tiles[index];
                  return AppQuickActionCard(
                    title: tile.title,
                    subtitle: tile.subtitle,
                    icon: tile.icon,
                    color: tile.color,
                    onTap: tile.onTap,
                  );
                },
              ),
              const SizedBox(height: AppTokens.space5),
              OutlinedButton.icon(
                onPressed: () => AuthService.instance.logout(),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sair da conta'),
              ),
              const SizedBox(height: 96),
            ],
          );
        },
      ),
    );
  }
}

class _HubTile {
  const _HubTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

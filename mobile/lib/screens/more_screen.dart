import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/permissions.dart';
import '../services/theme_service.dart';
import '../utils/formatters.dart';
import '../utils/label_mappers.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/profile_hero_card.dart';
import '../widgets/section_header.dart';
import '../widgets/status_chip.dart';
import 'budgets_screen.dart';
import 'equipments_screen.dart';
import 'error_logs_screen.dart';
import 'event_logs_screen.dart';
import 'products_screen.dart';
import 'task_types_screen.dart';
import 'templates_screen.dart';
import 'users_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _account = {};
  List<Map<String, dynamic>> _sessions = [];
  Map<String, dynamic> _sessionSummary = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.get('/auth/me') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _account =
            Map<String, dynamic>.from(response['account'] as Map? ?? const {});
        _sessions = List<Map<String, dynamic>>.from(
            response['sessions'] as List? ?? const []);
        _sessionSummary = Map<String, dynamic>.from(
          response['sessionSummary'] as Map? ?? const {},
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _confirmLogoutAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Encerrar todas as sessões'),
        content: const Text(
          'Você será desconectado deste dispositivo e dos demais. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.instance.logoutAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        title: 'Mais',
        showAppBar: false,
        body: LoadingView(message: 'Carregando o perfil...'),
      );
    }

    if (_error != null) {
      return AppScaffold(
        title: 'Mais',
        showAppBar: false,
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }

    final session = AuthService.instance.session.value;
    final user = session?.user ?? const <String, dynamic>{};
    final name = user['name']?.toString() ?? 'Usuário';
    final role = user['role_name']?.toString() ??
        user['role']?.toString() ??
        'visitante';
    final canViewUsers =
        AuthService.instance.hasPermission(Permissions.viewUsers);
    final isAdmin = AuthService.instance.isAdmin;
    final accountStatus = _account['status']?.toString() ?? 'active';

    return AppScaffold(
      title: 'Mais',
      showAppBar: false,
      padding: EdgeInsets.zero,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            ProfileHeroCard(
              name: name,
              subtitle: '$role • ${AppConfig.appName}',
              actions: [
                _HeroStat(
                  label: 'Sessões',
                  value: '${_sessionSummary['active'] ?? 0}',
                ),
                _HeroStat(
                  label: 'Status',
                  value: accountStatusLabel(accountStatus),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: StatusChip(
                    label: accountStatusLabel(accountStatus),
                    tone: _accountStatusTone(accountStatus),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatusChip(
                    label: '${_sessionSummary['active'] ?? 0} sessões ativas',
                    tone: StatusChipTone.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Preferências',
              subtitle: 'Aparência e comportamento do aplicativo',
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
                        Text('Tema do app',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
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
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Sessões',
              subtitle: 'Acompanhe o acesso da sua conta',
              actionLabel: 'Encerrar tudo',
              onAction: _confirmLogoutAll,
            ),
            const SizedBox(height: 12),
            if (_sessions.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhuma sessão registrada até o momento.'),
                ),
              )
            else
              ..._sessions.take(4).map((item) => Card(
                    child: ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.devices_outlined),
                      ),
                      title: Text(
                        item['deviceInfo']?.toString().isNotEmpty == true
                            ? item['deviceInfo'].toString()
                            : (item['platform']?.toString().isNotEmpty == true
                                ? item['platform'].toString()
                                : 'Sessão sem identificação'),
                      ),
                      subtitle: Text(
                        'Último uso: ${_safeDate(item['lastUsedAt']?.toString())}',
                      ),
                      trailing: StatusChip(
                        label: item['isCurrent'] == true ? 'Atual' : 'Ativa',
                        tone: item['isCurrent'] == true
                            ? StatusChipTone.success
                            : StatusChipTone.neutral,
                        compact: true,
                      ),
                    ),
                  )),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Hub operacional',
              subtitle: 'Acesso rápido aos módulos complementares',
            ),
            const SizedBox(height: 12),
            _HubTile(
              icon: Icons.receipt_long_rounded,
              title: 'Orçamentos',
              subtitle: 'Propostas, compartilhamento e acompanhamento',
              onTap: () => _open(const BudgetsScreen()),
            ),
            _HubTile(
              icon: Icons.inventory_2_outlined,
              title: 'Produtos',
              subtitle: 'Itens usados na composição de orçamentos',
              onTap: () => _open(ProductsScreen()),
            ),
            _HubTile(
              icon: Icons.precision_manufacturing_outlined,
              title: 'Equipamentos',
              subtitle: 'Ativos vinculados aos clientes',
              onTap: () => _open(const EquipmentsScreen()),
            ),
            _HubTile(
              icon: Icons.category_outlined,
              title: 'Tipos de tarefa',
              subtitle: 'Classificações operacionais e modelos',
              onTap: () => _open(const TaskTypesScreen()),
            ),
            _HubTile(
              icon: Icons.description_outlined,
              title: 'Templates',
              subtitle: 'Estruturas de relatório e coleta em campo',
              onTap: () => _open(const TemplatesScreen()),
            ),
            if (canViewUsers)
              _HubTile(
                icon: Icons.people_outline_rounded,
                title: 'Usuários',
                subtitle: 'Perfis, papéis e permissões',
                onTap: () => _open(const UsersScreen()),
              ),
            if (isAdmin) ...[
              _HubTile(
                icon: Icons.error_outline_rounded,
                title: 'Logs de erro',
                subtitle: 'Falhas técnicas reportadas pelo sistema',
                onTap: () => _open(const ErrorLogsScreen()),
              ),
              _HubTile(
                icon: Icons.history_edu_outlined,
                title: 'Eventos',
                subtitle: 'Trilha de auditoria e rastreabilidade',
                onTap: () => _open(const EventLogsScreen()),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _confirmLogoutAll,
              child: const Text('Encerrar todas as sessões'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => AuthService.instance.logout(),
              child: const Text('Sair desta sessão'),
            ),
          ],
        ),
      ),
    );
  }

  String _safeDate(String? value) {
    if (value == null || value.isEmpty) return 'Agora';
    return formatDateTime(value);
  }

  StatusChipTone _accountStatusTone(String status) {
    switch (status) {
      case 'blocked':
        return StatusChipTone.danger;
      case 'pending_verification':
        return StatusChipTone.warning;
      default:
        return StatusChipTone.success;
    }
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

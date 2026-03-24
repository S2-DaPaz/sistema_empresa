import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../theme/app_tokens.dart';
import '../utils/contact_utils.dart';
import '../utils/entity_config.dart';
import '../utils/field_config.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/metric_card.dart';
import '../widgets/profile_hero_card.dart';
import '../widgets/section_header.dart';
import '../widgets/status_chip.dart';
import 'entity_form_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({
    super.key,
    required this.client,
  });

  final Map<String, dynamic> client;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _budgets = [];
  late Map<String, dynamic> _client;

  @override
  void initState() {
    super.initState();
    _client = Map<String, dynamic>.from(widget.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final clientId = _client['id'];
      final results = await Future.wait([
        _api.get('/tasks?clientId=$clientId'),
        _api.get('/budgets?clientId=$clientId'),
      ]);
      if (!mounted) return;
      setState(() {
        _tasks = List<Map<String, dynamic>>.from(
          (results[0] as List?) ?? const [],
        );
        _budgets = List<Map<String, dynamic>>.from(
          (results[1] as List?) ?? const [],
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

  Future<void> _editClient() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EntityFormScreen(
          config: _clientConfig,
          item: _client,
        ),
      ),
    );

    if (updated == true && mounted) {
      await _refreshClient();
      await _load();
    }
  }

  Future<void> _refreshClient() async {
    final id = _client['id'];
    final payload = await _api.get('/clients/$id') as Map<String, dynamic>;
    if (!mounted) return;
    setState(() {
      _client = Map<String, dynamic>.from(payload);
    });
  }

  Future<void> _openUri(String value, String prefix) async {
    if (value.isEmpty) return;
    final uri = Uri.parse(prefix + value);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final email = extractEmail(_client['contact']?.toString());
    final phone = extractPhone(_client['contact']?.toString());
    final activeTasks = _tasks
        .where((task) => task['status']?.toString() != 'concluida')
        .length;
    final totalBudget = _budgets.fold<double>(
      0,
      (sum, budget) => sum + ((budget['total'] as num?)?.toDouble() ?? 0),
    );

    if (_loading) {
      return const AppScaffold(
        title: 'Detalhes do cliente',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return AppScaffold(
        title: 'Detalhes do cliente',
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }

    return AppScaffold(
      title: 'Detalhes do cliente',
      actions: [
        IconButton(
          tooltip: 'Editar cliente',
          onPressed: _editClient,
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
      body: ListView(
        children: [
          ProfileHeroCard(
            name: _client['name']?.toString() ?? 'Cliente',
            subtitle: _client['cnpj']?.toString().isNotEmpty == true
                ? _client['cnpj'].toString()
                : 'Cadastro comercial',
            actions: [
              _QuickAction(
                label: 'E-mail',
                icon: Icons.email_outlined,
                onTap: email.isEmpty ? null : () => _openUri(email, 'mailto:'),
              ),
              _QuickAction(
                label: 'Ligar',
                icon: Icons.call_outlined,
                onTap: phone.isEmpty
                    ? null
                    : () => _openUri(
                        phone.replaceAll(RegExp(r'[^0-9]'), ''), 'tel:'),
              ),
              _QuickAction(
                label: 'WhatsApp',
                icon: Icons.chat_bubble_outline_rounded,
                onTap: phone.isEmpty
                    ? null
                    : () => _openUri(
                          phone.replaceAll(RegExp(r'[^0-9]'), ''),
                          'https://wa.me/',
                        ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.24,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              MetricCard(
                title: 'Tarefas',
                value: '${_tasks.length}',
                subtitle: '$activeTasks em andamento',
                icon: Icons.task_alt_rounded,
              ),
              MetricCard(
                title: 'Orçamentos',
                value: '${_budgets.length}',
                subtitle: formatCurrency(totalBudget),
                icon: Icons.receipt_long_rounded,
                accentColor: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(
            title: 'Informações',
            subtitle: 'Dados comerciais e de contato',
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                      label: 'E-mail',
                      value: email.isEmpty ? 'Não informado' : email),
                  _InfoRow(
                      label: 'Telefone',
                      value: phone.isEmpty ? 'Não informado' : phone),
                  _InfoRow(
                    label: 'Endereço',
                    value: _client['address']?.toString().isNotEmpty == true
                        ? _client['address'].toString()
                        : 'Não informado',
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(
            title: 'Visão rápida',
            subtitle: 'Atividade e status relacionados a este cliente',
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_tasks.isEmpty && _budgets.isEmpty)
            const EmptyState(
              title: 'Sem histórico vinculado',
              message:
                  'Quando o cliente receber tarefas ou orçamentos eles aparecem aqui.',
              icon: Icons.history_toggle_off_rounded,
            )
          else ...[
            if (_tasks.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Últimas tarefas',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      ..._tasks.take(3).map((task) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                      task['title']?.toString() ?? 'Tarefa'),
                                ),
                                StatusChip(
                                  label: _taskStatusLabel(
                                      task['status']?.toString()),
                                  compact: true,
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            if (_budgets.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Últimos orçamentos',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      ..._budgets.take(3).map((budget) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('ORÇ #${budget['id']}'),
                                ),
                                StatusChip(
                                  label: _budgetStatusLabel(
                                      budget['status']?.toString()),
                                  compact: true,
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _taskStatusLabel(String? value) {
    switch (value) {
      case 'em_andamento':
        return 'Em andamento';
      case 'concluida':
        return 'Concluída';
      default:
        return 'Aberta';
    }
  }

  String _budgetStatusLabel(String? value) {
    switch (value) {
      case 'aprovado':
        return 'Aprovado';
      case 'recusado':
        return 'Recusado';
      default:
        return 'Em andamento';
    }
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

final EntityConfig _clientConfig = EntityConfig(
  title: 'Cliente',
  endpoint: '/clients',
  primaryField: 'name',
  fields: [
    FieldConfig(name: 'name', label: 'Nome', type: FieldType.text),
    FieldConfig(name: 'cnpj', label: 'CPF/CNPJ', type: FieldType.text),
    FieldConfig(name: 'address', label: 'Endereço', type: FieldType.textarea),
    FieldConfig(name: 'contact', label: 'Contato', type: FieldType.text),
  ],
);

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/brand_logo.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/section_header.dart';

enum DashboardShortcut { clients, tasks, products, budgets }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.onOpenShortcut,
  });

  final ValueChanged<DashboardShortcut>? onOpenShortcut;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _summary = {};
  List<dynamic> _reports = [];

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
      final payload = Map<String, dynamic>.from(
        await _api.get('/summary') as Map,
      );
      final summary = Map<String, dynamic>.from(
        payload['summary'] as Map? ?? const {},
      );
      final recentReports = List<dynamic>.from(
        payload['recentReports'] as List? ?? const [],
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _summary = summary;
        _reports = recentReports.take(4).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Não foi possível carregar os dados do painel.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(title: 'Painel', body: LoadingView());
    }

    if (_error != null) {
      return AppScaffold(
        title: 'Painel',
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }

    return AppScaffold(
      title: 'Painel',
      body: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const BrandLogo(height: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RV TecnoCare',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Assistência técnica e orçamentos',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    tooltip: 'Atualizar',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(
            title: 'Visão geral',
            subtitle: 'Números principais desta operação',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryCard(
                title: 'Clientes',
                value: _summary['clients'],
                icon: Icons.people_alt_outlined,
                onTap: () =>
                    widget.onOpenShortcut?.call(DashboardShortcut.clients),
              ),
              _SummaryCard(
                title: 'Tarefas',
                value: _summary['tasks'],
                icon: Icons.task_alt,
                onTap: () => widget.onOpenShortcut?.call(DashboardShortcut.tasks),
              ),
              _SummaryCard(
                title: 'Produtos',
                value: _summary['products'],
                icon: Icons.inventory_2_outlined,
                onTap: () =>
                    widget.onOpenShortcut?.call(DashboardShortcut.products),
              ),
              _SummaryCard(
                title: 'Orçamentos',
                value: _summary['budgets'],
                icon: Icons.receipt_long,
                onTap: () =>
                    widget.onOpenShortcut?.call(DashboardShortcut.budgets),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(
            title: 'Últimos relatórios',
            subtitle: 'Acompanhe as atividades mais recentes',
          ),
          const SizedBox(height: 12),
          if (_reports.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhum relatório cadastrado.'),
              ),
            ),
          ..._reports.map((report) {
            final map = Map<String, dynamic>.from(report as Map);
            final title = map['title'] ?? map['template_name'] ?? 'Relatório';
            final created = map['created_at']?.toString() ?? '';

            return Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(title.toString()),
                subtitle: Text(
                  '${map['client_name'] ?? 'Sem cliente'} • ${formatDate(created)}',
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String title;
  final dynamic value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 164,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Total cadastrado',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Chip(label: Text('${value ?? 0}')),
                const SizedBox(height: 10),
                Text(
                  'Toque para abrir',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

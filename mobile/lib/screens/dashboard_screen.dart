import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/brand_logo.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/section_header.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

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
      final summary = await _api.get('/summary') as Map<String, dynamic>;
      final reports = await _api.get('/reports') as List<dynamic>;
      setState(() {
        _summary = summary;
        _reports = reports.take(4).toList();
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      setState(() => _loading = false);
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
              ),
              _SummaryCard(
                title: 'Tarefas',
                value: _summary['tasks'],
                icon: Icons.task_alt,
              ),
              _SummaryCard(
                title: 'Relatórios',
                value: _summary['reports'],
                icon: Icons.description_outlined,
              ),
              _SummaryCard(
                title: 'Orçamentos',
                value: _summary['budgets'],
                icon: Icons.receipt_long,
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
            final map = report as Map<String, dynamic>;
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
  });

  final String title;
  final dynamic value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 164,
      child: Card(
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
            ],
          ),
        ),
      ),
    );
  }
}

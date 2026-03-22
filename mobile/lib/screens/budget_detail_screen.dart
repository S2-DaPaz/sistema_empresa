import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_ui.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';

class BudgetDetailScreen extends StatefulWidget {
  const BudgetDetailScreen({
    super.key,
    required this.budgetId,
  });

  final int budgetId;

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  bool _updatingStatus = false;
  bool _sharing = false;
  String? _error;
  Map<String, dynamic> _budget = {};
  Map<String, dynamic> _client = {};

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
      final budget = Map<String, dynamic>.from(
          await _api.get('/budgets/${widget.budgetId}') as Map);
      Map<String, dynamic> client = {};
      if (budget['client_id'] != null) {
        client = Map<String, dynamic>.from(
          await _api.get('/clients/${budget['client_id']}') as Map,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _budget = budget;
        _client = client;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Nao foi possivel carregar o orcamento agora.';
        _loading = false;
      });
    }
  }

  String _statusLabel(String? value) {
    switch (value) {
      case 'aprovado':
        return 'Aprovado';
      case 'recusado':
        return 'Recusado';
      default:
        return 'Aguardando aprovacao';
    }
  }

  Color _statusColor(String? value) {
    switch (value) {
      case 'aprovado':
        return AppTokens.supportTeal;
      case 'recusado':
        return AppTokens.danger;
      default:
        return AppTokens.warning;
    }
  }

  String _initials() {
    final name = _client['name']?.toString().trim() ??
        _budget['client_name']?.toString().trim() ??
        'Cliente';
    final parts =
        name.split(RegExp(r'\s+')).where((item) => item.isNotEmpty).toList();
    if (parts.isEmpty) return 'CL';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String? _extractPhone() {
    final source = _client['contact']?.toString() ?? '';
    final digits = source.replaceAll(RegExp(r'[^\d]'), '');
    return digits.length < 10 ? null : digits;
  }

  Future<void> _callClient() async {
    final phone = _extractPhone();
    if (phone == null) return;
    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<String?> _publicLink() async {
    final response = Map<String, dynamic>.from(
        await _api.post('/budgets/${widget.budgetId}/public-link', {}));
    final url = response['url']?.toString();
    if (url == null || url.isEmpty) {
      return null;
    }
    return url;
  }

  Future<void> _shareOnWhatsApp() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final url = await _publicLink();
      if (url == null) return;
      final clientName = _client['name']?.toString() ??
          _budget['client_name']?.toString() ??
          'cliente';
      final message = Uri.encodeComponent(
        'Ola, $clientName. Segue o orcamento #${widget.budgetId}: $url',
      );
      await launchUrl(
        Uri.parse('https://wa.me/?text=$message'),
        mode: LaunchMode.externalApplication,
      );
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    if (_updatingStatus) return;
    setState(() => _updatingStatus = true);
    try {
      await _api.put('/budgets/${widget.budgetId}', {
        ..._budget,
        'status': status,
      });
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel atualizar o status do orcamento.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingStatus = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(title: 'Orcamento', body: LoadingView());
    }

    if (_error != null) {
      return AppScaffold(
        title: 'Orcamento',
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }

    final items = List<Map<String, dynamic>>.from(
        (_budget['items'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map)));
    final status = _budget['status']?.toString();

    return AppScaffold(
      title: 'Orcamento #${widget.budgetId}',
      subtitle: _budget['client_name']?.toString() ?? 'Detalhe comercial',
      showLogo: false,
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: ListView(
        children: [
          Row(
            children: [
              AppStatusPill(
                label: _statusLabel(status),
                color: _statusColor(status),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space4),
          AppSurface(
            child: Row(
              children: [
                AppAvatarInitials(
                  initials: _initials(),
                  backgroundColor:
                      AppTokens.primaryBlue.withValues(alpha: 0.12),
                ),
                const SizedBox(width: AppTokens.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _client['name']?.toString() ??
                            _budget['client_name']?.toString() ??
                            'Cliente',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _client['contact']?.toString() ??
                            'Contato nao informado',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                AppActionChip(
                  label: 'Ligar',
                  icon: Icons.call_outlined,
                  color: AppTokens.supportTeal,
                  onTap: _callClient,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          const AppSectionBlock(
            title: 'Itens do orcamento',
            subtitle: 'Composicao comercial vinculada a esta proposta.',
          ),
          const SizedBox(height: AppTokens.space4),
          if (items.isEmpty)
            const EmptyStateCard(
              title: 'Sem itens cadastrados',
              subtitle: 'Os itens desta proposta ainda nao foram informados.',
            ),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppSurface(
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTokens.primaryBlue.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusSm),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: AppTokens.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: AppTokens.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['description']?.toString() ?? 'Item',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item['qty'] ?? 0} x ${formatCurrency(item['unit_price'] ?? 0)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatCurrency(item['total'] ?? 0),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: AppTokens.space4),
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumo financeiro',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.space4),
                _BudgetSummaryRow(
                  label: 'Subtotal',
                  value: formatCurrency(_budget['subtotal'] ?? 0),
                ),
                _BudgetSummaryRow(
                  label: 'Desconto',
                  value: formatCurrency(_budget['discount'] ?? 0),
                  valueColor: AppTokens.supportTeal,
                ),
                _BudgetSummaryRow(
                  label: 'Mao de obra / taxa',
                  value: formatCurrency(_budget['tax'] ?? 0),
                ),
                const Divider(height: 24),
                _BudgetSummaryRow(
                  label: 'Total',
                  value: formatCurrency(_budget['total'] ?? 0),
                  valueColor: AppTokens.primaryBlue,
                  emphasize: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          AppInfoCallout(
            title: 'Validade da proposta',
            message: _budget['proposal_validity']
                        ?.toString()
                        .trim()
                        .isNotEmpty ==
                    true
                ? 'Esta proposta e valida ate ${_budget['proposal_validity']}.'
                : 'Defina a validade comercial desta proposta para evitar divergencias.',
            icon: Icons.schedule_rounded,
            color: AppTokens.warning,
          ),
          const SizedBox(height: AppTokens.space5),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _updatingStatus ? null : () => _updateStatus('aprovado'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.supportTeal,
                  ),
                  child: Text(_updatingStatus ? 'Salvando...' : 'Aprovar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _updatingStatus ? null : () => _updateStatus('recusado'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTokens.danger,
                  ),
                  child: const Text('Recusar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sharing ? null : _shareOnWhatsApp,
              icon: const Icon(Icons.chat_rounded),
              label: Text(_sharing ? 'Preparando...' : 'Enviar WhatsApp'),
            ),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}

class _BudgetSummaryRow extends StatelessWidget {
  const _BudgetSummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasize
                  ? Theme.of(context).textTheme.titleSmall
                  : Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: (emphasize
                    ? Theme.of(context).textTheme.titleMedium
                    : Theme.of(context).textTheme.labelLarge)
                ?.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/entity_refresh_service.dart';
import '../services/permissions.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_ui.dart';
import '../widgets/error_view.dart';
import '../widgets/form_fields.dart';
import '../widgets/loading_view.dart';

class EquipmentsScreen extends StatefulWidget {
  const EquipmentsScreen({super.key});

  @override
  State<EquipmentsScreen> createState() => _EquipmentsScreenState();
}

class _EquipmentsScreenState extends State<EquipmentsScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<String>? _entityRefreshSubscription;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _equipments = [];
  List<Map<String, dynamic>> _clients = [];
  String _query = '';
  _EquipmentFilter _filter = _EquipmentFilter.all;
  int? _selectedEquipmentId;

  bool get _canView =>
      AuthService.instance.hasPermission(Permissions.viewTasks);
  bool get _canManage =>
      AuthService.instance.hasPermission(Permissions.manageTasks);

  Map<String, dynamic>? get _selectedEquipment {
    if (_selectedEquipmentId == null) {
      return _filteredEquipments.isEmpty ? null : _filteredEquipments.first;
    }
    for (final equipment in _filteredEquipments) {
      if (equipment['id'] == _selectedEquipmentId) {
        return equipment;
      }
    }
    return _filteredEquipments.isEmpty ? null : _filteredEquipments.first;
  }

  List<Map<String, dynamic>> get _filteredEquipments {
    final normalizedQuery = _query.trim().toLowerCase();
    return _equipments.where((equipment) {
      if (_filter == _EquipmentFilter.withClient &&
          equipment['client_id'] == null) {
        return false;
      }
      if (_filter == _EquipmentFilter.withoutClient &&
          equipment['client_id'] != null) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      final searchable = [
        equipment['name'],
        equipment['model'],
        equipment['serial'],
        _clientName(equipment['client_id'] as int?),
      ].join(' ').toLowerCase();
      return searchable.contains(normalizedQuery);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _entityRefreshSubscription = EntityRefreshService.instance.listen(
      const ['/equipments', '/clients'],
      (_) => _load(),
    );
    _load();
  }

  @override
  void dispose() {
    _entityRefreshSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_canView) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.get('/equipments'),
        _api.get('/clients'),
      ]);
      final equipments = (results[0] as List?) ?? [];
      final clients = (results[1] as List?) ?? [];

      if (!mounted) {
        return;
      }

      setState(() {
        _equipments = equipments.cast<Map<String, dynamic>>();
        _clients = clients.cast<Map<String, dynamic>>();
        if (_selectedEquipmentId == null && _equipments.isNotEmpty) {
          _selectedEquipmentId = _equipments.first['id'] as int?;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Não foi possível carregar os equipamentos agora.';
        _loading = false;
      });
    }
  }

  String _clientName(int? id) {
    if (id == null) {
      return 'Sem cliente vinculado';
    }
    final match = _clients.firstWhere(
      (client) => client['id'] == id,
      orElse: () => {},
    );
    return match['name']?.toString() ?? 'Sem cliente vinculado';
  }

  String _statusLabel(Map<String, dynamic> equipment) {
    final hasClient = equipment['client_id'] != null;
    final hasSerial = (equipment['serial']?.toString().trim() ?? '').isNotEmpty;
    if (!hasClient) {
      return 'pendência';
    }
    if (!hasSerial) {
      return 'atenção';
    }
    return 'ok';
  }

  Color _statusColor(Map<String, dynamic> equipment) {
    switch (_statusLabel(equipment)) {
      case 'pendência':
        return AppTokens.warning;
      case 'atenção':
        return AppTokens.primaryCyan;
      default:
        return AppTokens.supportTeal;
    }
  }

  Future<void> _openForm({Map<String, dynamic>? equipment}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EquipmentFormScreen(
          equipment: equipment,
          clients: _clients,
        ),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _deleteEquipment(Map<String, dynamic> equipment) async {
    final id = equipment['id'];
    if (id == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover equipamento'),
        content: const Text('Deseja remover este equipamento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _api.delete('/equipments/$id');
      EntityRefreshService.instance.notifyChanged('/equipments');
      await _load();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível remover o equipamento agora.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        title: 'Equipamentos',
        subtitle: 'Ativos vinculados a clientes e histórico técnico',
        showLogo: false,
        body: LoadingView(),
      );
    }

    if (_error != null) {
      return AppScaffold(
        title: 'Equipamentos',
        subtitle: 'Ativos vinculados a clientes e histórico técnico',
        showLogo: false,
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }

    if (!_canView) {
      return const AppScaffold(
        title: 'Equipamentos',
        subtitle: 'Ativos vinculados a clientes e histórico técnico',
        showLogo: false,
        body: EmptyStateCard(
          title: 'Acesso indisponível',
          subtitle: 'Você não possui permissão para visualizar os equipamentos.',
        ),
      );
    }

    final equipments = _filteredEquipments;
    final selected = _selectedEquipment;

    return AppScaffold(
      title: 'Equipamentos',
      subtitle: 'Ativos vinculados a clientes e histórico técnico',
      showLogo: false,
      floatingActionButton: _canManage
          ? FloatingActionButton(
              heroTag: 'fab-equipments',
              onPressed: () => _openForm(),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            AppSearchField(
              controller: _searchController,
              hintText: 'Buscar por cliente, número de série ou modelo',
              onChanged: (value) => setState(() => _query = value),
              trailing: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            const SizedBox(height: AppTokens.space4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _filter == _EquipmentFilter.all,
                  onSelected: (_) => setState(() => _filter = _EquipmentFilter.all),
                ),
                ChoiceChip(
                  label: const Text('Com cliente'),
                  selected: _filter == _EquipmentFilter.withClient,
                  onSelected: (_) =>
                      setState(() => _filter = _EquipmentFilter.withClient),
                ),
                ChoiceChip(
                  label: const Text('Sem cliente'),
                  selected: _filter == _EquipmentFilter.withoutClient,
                  onSelected: (_) =>
                      setState(() => _filter = _EquipmentFilter.withoutClient),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space5),
            if (equipments.isEmpty)
              EmptyStateCard(
                title: 'Nenhum equipamento encontrado',
                subtitle: _equipments.isEmpty
                    ? 'Cadastre o primeiro equipamento para iniciar o histórico técnico.'
                    : 'Ajuste os filtros para localizar outro ativo.',
                action: _canManage
                    ? ElevatedButton(
                        onPressed: () => _openForm(),
                        child: const Text('Novo equipamento'),
                      )
                    : null,
              ),
            ...equipments.map((equipment) {
              final statusLabel = _statusLabel(equipment);
              final clientName =
                  _clientName(equipment['client_id'] as int?);
              final isSelected = selected?['id'] == equipment['id'];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppSurface(
                  onTap: () => setState(
                    () => _selectedEquipmentId = equipment['id'] as int?,
                  ),
                  backgroundColor: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.surface,
                  borderColor: isSelected
                      ? AppTokens.accentBlue.withValues(alpha: 0.28)
                      : Theme.of(context).colorScheme.outlineVariant,
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTokens.accentBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.precision_manufacturing_outlined,
                          color: AppTokens.accentBlue,
                        ),
                      ),
                      const SizedBox(width: AppTokens.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              equipment['name']?.toString() ?? 'Equipamento',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                clientName,
                                if ((equipment['model']?.toString().trim() ?? '')
                                    .isNotEmpty)
                                  equipment['model'].toString(),
                              ].join(' • '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppTokens.space3),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AppStatusPill(
                            label: statusLabel,
                            color: _statusColor(equipment),
                          ),
                          if (_canManage)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _openForm(equipment: equipment);
                                } else if (value == 'delete') {
                                  _deleteEquipment(equipment);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Remover'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (selected != null) ...[
              const SizedBox(height: AppTokens.space5),
              AppSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ficha rápida',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTokens.space4),
                    _QuickInfoRow(
                      label: 'Modelo',
                      value: selected['model']?.toString().trim().isNotEmpty == true
                          ? selected['model'].toString()
                          : 'Não informado',
                    ),
                    _QuickInfoRow(
                      label: 'S/N',
                      value: selected['serial']?.toString().trim().isNotEmpty == true
                          ? selected['serial'].toString()
                          : 'Não informado',
                    ),
                    _QuickInfoRow(
                      label: 'Cliente',
                      value: _clientName(selected['client_id'] as int?),
                    ),
                    if ((selected['description']?.toString().trim() ?? '').isNotEmpty)
                      _QuickInfoRow(
                        label: 'Descrição',
                        value: selected['description'].toString(),
                      ),
                  ],
                ),
              ),
              if (_canManage) ...[
                const SizedBox(height: AppTokens.space4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openForm(equipment: selected),
                        child: const Text('Editar cadastro'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _openForm(),
                        child: const Text('Novo equipamento'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}

class EquipmentFormScreen extends StatefulWidget {
  const EquipmentFormScreen({super.key, this.equipment, required this.clients});

  final Map<String, dynamic>? equipment;
  final List<Map<String, dynamic>> clients;

  @override
  State<EquipmentFormScreen> createState() => _EquipmentFormScreenState();
}

class _EquipmentFormScreenState extends State<EquipmentFormScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  int? _clientId;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.equipment?['id'] != null;

  @override
  void initState() {
    super.initState();
    final equipment = widget.equipment;
    if (equipment != null) {
      _nameController.text = equipment['name']?.toString() ?? '';
      _modelController.text = equipment['model']?.toString() ?? '';
      _serialController.text = equipment['serial']?.toString() ?? '';
      _descriptionController.text = equipment['description']?.toString() ?? '';
      _clientId = equipment['client_id'] as int?;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  List<DropdownMenuItem<int>> _clientItems() {
    return widget.clients
        .map(
          (client) => DropdownMenuItem<int>(
            value: client['id'] as int?,
            child: Text(client['name']?.toString() ?? 'Cliente'),
          ),
        )
        .toList();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    if (_clientId == null) {
      setState(() {
        _saving = false;
        _error = 'Selecione um cliente antes de salvar.';
      });
      return;
    }

    final payload = {
      'client_id': _clientId,
      'name': _nameController.text.trim(),
      'model': _modelController.text.trim(),
      'serial': _serialController.text.trim(),
      'description': _descriptionController.text.trim(),
    };

    try {
      if (_isEdit) {
        await _api.put('/equipments/${widget.equipment?['id']}', payload);
      } else {
        await _api.post('/equipments', payload);
      }
      EntityRefreshService.instance.notifyChanged('/equipments');
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      setState(() {
        _error = 'Não foi possível salvar o equipamento agora.';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Editar equipamento' : 'Novo equipamento',
      subtitle: 'Cadastro técnico vinculado ao cliente',
      showLogo: false,
      body: ListView(
        children: [
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ficha principal',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.space4),
                AppDropdownField<int>(
                  label: 'Cliente',
                  value: _clientId,
                  items: _clientItems(),
                  onChanged: (value) => setState(() => _clientId = value),
                ),
                const SizedBox(height: AppTokens.space4),
                AppTextField(
                  label: 'Nome do equipamento',
                  controller: _nameController,
                ),
                const SizedBox(height: AppTokens.space4),
                AppTextField(
                  label: 'Modelo',
                  controller: _modelController,
                ),
                const SizedBox(height: AppTokens.space4),
                AppTextField(
                  label: 'Número de série',
                  controller: _serialController,
                ),
                const SizedBox(height: AppTokens.space4),
                AppTextField(
                  label: 'Descrição',
                  controller: _descriptionController,
                  maxLines: 4,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppTokens.space4),
            AppMessageBanner(
              message: _error!,
              icon: Icons.error_outline_rounded,
              toneColor: Theme.of(context).colorScheme.error,
            ),
          ],
          const SizedBox(height: AppTokens.space5),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Salvando...' : 'Salvar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickInfoRow extends StatelessWidget {
  const _QuickInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

enum _EquipmentFilter {
  all,
  withClient,
  withoutClient,
}

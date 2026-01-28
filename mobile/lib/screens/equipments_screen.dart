import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/permissions.dart';
import '../widgets/app_scaffold.dart';
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
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _equipments = [];
  List<Map<String, dynamic>> _clients = [];

  bool get _canView => AuthService.instance.hasPermission(Permissions.viewTasks);
  bool get _canManage => AuthService.instance.hasPermission(Permissions.manageTasks);

  @override
  void initState() {
    super.initState();
    _load();
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
      setState(() {
        _equipments = equipments.cast<Map<String, dynamic>>();
        _clients = clients.cast<Map<String, dynamic>>();
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  String _clientName(int? id) {
    if (id == null) return 'Sem cliente';
    final match = _clients.firstWhere(
      (client) => client['id'] == id,
      orElse: () => {},
    );
    return match['name']?.toString() ?? 'Sem cliente';
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
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover equipamento'),
        content: const Text('Deseja remover este equipamento?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.delete('/equipments/$id');
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(title: 'Equipamentos', body: LoadingView());
    }
    if (_error != null) {
      return AppScaffold(
        title: 'Equipamentos',
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }
    if (!_canView) {
      return AppScaffold(
        title: 'Equipamentos',
        body: const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Você não possui permissão para visualizar equipamentos.'),
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'Equipamentos',
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: () => _openForm(),
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            if (_equipments.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhum equipamento cadastrado.'),
                ),
              ),
            ..._equipments.map((equipment) {
              final clientId = equipment['client_id'] as int?;
              final name = equipment['name']?.toString() ?? 'Equipamento';
              final model = equipment['model']?.toString() ?? '';
              final serial = equipment['serial']?.toString() ?? '';
              final subtitleParts = <String>[
                'Cliente: ${_clientName(clientId)}',
                if (model.isNotEmpty) 'Modelo: $model',
                if (serial.isNotEmpty) 'Série: $serial',
              ];
              return Card(
                child: ListTile(
                  title: Text(name),
                  subtitle: Text(subtitleParts.join(' | ')),
                  onTap: _canManage ? () => _openForm(equipment: equipment) : null,
                  trailing: _canManage
                      ? PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _openForm(equipment: equipment);
                            if (value == 'delete') _deleteEquipment(equipment);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Editar')),
                            PopupMenuItem(value: 'delete', child: Text('Remover')),
                          ],
                        )
                      : null,
                ),
              );
            }),
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
        _error = 'Selecione um cliente.';
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
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Editar equipamento' : 'Novo equipamento',
      body: ListView(
        children: [
          AppDropdownField<int>(
            label: 'Cliente',
            value: _clientId,
            items: _clientItems(),
            onChanged: (value) => setState(() => _clientId = value),
          ),
          AppTextField(label: 'Nome', controller: _nameController),
          AppTextField(label: 'Modelo', controller: _modelController),
          AppTextField(label: 'Série', controller: _serialController),
          AppTextField(label: 'Descrição', controller: _descriptionController, maxLines: 3),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/entity_config.dart';
import '../utils/field_config.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/section_header.dart';
import 'entity_form_screen.dart';

class EntityListScreen extends StatefulWidget {
  const EntityListScreen({super.key, required this.config});

  final EntityConfig config;

  @override
  State<EntityListScreen> createState() => _EntityListScreenState();
}

class _EntityListScreenState extends State<EntityListScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];

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
      final data = await _api.get(widget.config.endpoint);
      setState(() => _items = data as List<dynamic>);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Map<String, dynamic>? item}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntityFormScreen(config: widget.config, item: item),
      ),
    );
    await _load();
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover registro'),
        content: const Text('Deseja remover este item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.delete('${widget.config.endpoint}/$id');
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  String _buildSubtitle(Map<String, dynamic> item) {
    final parts = <String>[];
    for (final field in widget.config.fields) {
      if (field.name == widget.config.primaryField) continue;
      final value = item[field.name];
      if (value == null || value.toString().isEmpty) continue;
      if (field.type == FieldType.select && field.options.isNotEmpty) {
        final match = field.options.firstWhere(
          (option) => option.value.toString() == value.toString(),
          orElse: () => FieldOption(value: value, label: value.toString()),
        );
        final formatted = field.formatter?.call(match.label) ?? match.label;
        parts.add(formatted.toString());
      } else {
        final formatted = field.formatter?.call(value) ?? value;
        parts.add(formatted.toString());
      }
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AppScaffold(title: widget.config.title, body: const LoadingView());
    }
    if (_error != null) {
      return AppScaffold(
        title: widget.config.title,
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }

    return AppScaffold(
      title: widget.config.title,
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-entity-${widget.config.endpoint}',
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          if (widget.config.hint != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(widget.config.hint!),
              ),
            ),
          const SizedBox(height: 12),
          SectionHeader(
            title: 'Registros',
            subtitle: widget.config.emptyMessage ?? 'Nenhum registro.',
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(widget.config.emptyMessage ?? 'Nenhum registro.'),
              ),
            ),
          ..._items.map((item) {
            final map = item as Map<String, dynamic>;
            return Card(
              child: ListTile(
                title: Text(map[widget.config.primaryField]?.toString() ?? 'Sem título'),
                subtitle: Text(_buildSubtitle(map)),
                onTap: () => _openForm(item: map),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _openForm(item: map);
                    if (value == 'delete') _deleteItem(map);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Remover')),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

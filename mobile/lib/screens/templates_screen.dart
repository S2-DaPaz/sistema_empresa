import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/section_header.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _templates = [];

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
      final data = await _api.get('/report-templates') as List<dynamic>;
      setState(() => _templates = data.cast<Map<String, dynamic>>());
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openEditor({Map<String, dynamic>? template}) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => TemplateEditorScreen(template: template)))
        .then((_) => _load());
  }

  Future<void> _deleteTemplate(Map<String, dynamic> template) async {
    final id = template['id'];
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover modelo'),
        content: const Text('Deseja remover este modelo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _api.delete('/report-templates/$id');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(title: 'Modelos', body: LoadingView());
    }
    if (_error != null) {
      return AppScaffold(
        title: 'Modelos',
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }

    return AppScaffold(
      title: 'Modelos',
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-templates',
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          const SectionHeader(
            title: 'Modelos de relatório',
            subtitle: 'Crie layouts personalizados por tipo de atendimento.',
          ),
          const SizedBox(height: 12),
          if (_templates.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhum modelo cadastrado.'),
              ),
            ),
          ..._templates.map((template) => Card(
                child: ListTile(
                  title: Text(template['name']?.toString() ?? 'Modelo'),
                  subtitle: Text(template['description']?.toString() ?? 'Sem descrição'),
                  onTap: () => _openEditor(template: template),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteTemplate(template),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class TemplateEditorScreen extends StatefulWidget {
  const TemplateEditorScreen({super.key, this.template});

  final Map<String, dynamic>? template;

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  final ApiService _api = ApiService();
  late final TextEditingController _name;
  late final TextEditingController _description;
  String _sectionColumns = '1';
  String _fieldColumns = '1';
  List<Map<String, dynamic>> _sections = [];
  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.template?['id'] != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.template?['name']?.toString() ?? '');
    _description = TextEditingController(text: widget.template?['description']?.toString() ?? '');

    final structure = widget.template?['structure'] as Map<String, dynamic>? ?? {};
    final layout = structure['layout'] as Map<String, dynamic>? ?? {};
    _sectionColumns = layout['sectionColumns']?.toString() ?? '1';
    _fieldColumns = layout['fieldColumns']?.toString() ?? '1';
    final rawSections = structure['sections'] as List<dynamic>? ?? [];
    _sections = rawSections.cast<Map<String, dynamic>>();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  String _uid() => DateTime.now().microsecondsSinceEpoch.toString();

  void _addSection() {
    setState(() {
      _sections.add({
        'id': _uid(),
        'title': '',
        'fields': <Map<String, dynamic>>[],
      });
    });
  }

  void _removeSection(Map<String, dynamic> section) {
    setState(() => _sections.remove(section));
  }

  void _addField(Map<String, dynamic> section) {
    final fields = (section['fields'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    fields.add({
      'id': _uid(),
      'label': '',
      'type': 'text',
      'required': false,
      'options': <String>[],
    });
    setState(() => section['fields'] = fields);
  }

  void _removeField(Map<String, dynamic> section, Map<String, dynamic> field) {
    final fields = (section['fields'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    fields.remove(field);
    setState(() => section['fields'] = fields);
  }

  void _addOption(Map<String, dynamic> field, String value) {
    final options = (field['options'] as List<dynamic>? ?? []).cast<String>();
    options.add(value);
    setState(() => field['options'] = options);
  }

  void _removeOption(Map<String, dynamic> field, String value) {
    final options = (field['options'] as List<dynamic>? ?? []).cast<String>();
    options.remove(value);
    setState(() => field['options'] = options);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = {
      'name': _name.text,
      'description': _description.text,
      'structure': {
        'sections': _sections,
        'layout': {
          'sectionColumns': int.tryParse(_sectionColumns) ?? 1,
          'fieldColumns': int.tryParse(_fieldColumns) ?? 1,
        },
      },
    };

    try {
      if (_isEdit) {
        await _api.put('/report-templates/${widget.template?['id']}', payload);
      } else {
        await _api.post('/report-templates', payload);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Editar modelo' : 'Novo modelo',
      body: ListView(
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Descrição'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(_sectionColumns),
            initialValue: _sectionColumns,
            decoration: const InputDecoration(labelText: 'Colunas das seções'),
            items: const [
              DropdownMenuItem(value: '1', child: Text('1 coluna')),
              DropdownMenuItem(value: '2', child: Text('2 colunas')),
              DropdownMenuItem(value: '3', child: Text('3 colunas')),
            ],
            onChanged: (value) => setState(() => _sectionColumns = value ?? '1'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(_fieldColumns),
            initialValue: _fieldColumns,
            decoration: const InputDecoration(labelText: 'Colunas dos campos'),
            items: const [
              DropdownMenuItem(value: '1', child: Text('1 coluna')),
              DropdownMenuItem(value: '2', child: Text('2 colunas')),
              DropdownMenuItem(value: '3', child: Text('3 colunas')),
            ],
            onChanged: (value) => setState(() => _fieldColumns = value ?? '1'),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Seções', style: Theme.of(context).textTheme.titleSmall),
              OutlinedButton(onPressed: _addSection, child: const Text('Adicionar seção')),
            ],
          ),
          const SizedBox(height: 8),
          if (_sections.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Adicione Seções e campos para o Relatório.'),
              ),
            ),
          ..._sections.map((section) {
            final sectionTitle = section['title']?.toString() ?? '';
            final fields = (section['fields'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: sectionTitle,
                            decoration: const InputDecoration(labelText: 'Título da seção'),
                            onChanged: (value) => section['title'] = value,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeSection(section),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Campos', style: Theme.of(context).textTheme.titleSmall),
                        OutlinedButton(
                          onPressed: () => _addField(section),
                          child: const Text('Adicionar campo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (fields.isEmpty)
                      const Text('Adicione campos a esta seção.'),
                    ...fields.map((field) {
                      final fieldLabel = field['label']?.toString() ?? '';
                      final fieldType = field['type']?.toString() ?? 'text';
                      final required = field['required'] == true;
                      final options = (field['options'] as List<dynamic>? ?? []).cast<String>();
                      final optionController = TextEditingController();
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              TextFormField(
                                initialValue: fieldLabel,
                                decoration: const InputDecoration(labelText: 'Label'),
                                onChanged: (value) => field['label'] = value,
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                key: ValueKey(fieldType),
                                initialValue: fieldType,
                                decoration: const InputDecoration(labelText: 'Tipo'),
                                items: const [
                                  DropdownMenuItem(value: 'text', child: Text('Texto curto')),
                                  DropdownMenuItem(value: 'textarea', child: Text('Texto longo')),
                                  DropdownMenuItem(value: 'number', child: Text('Número')),
                                  DropdownMenuItem(value: 'date', child: Text('Data')),
                                  DropdownMenuItem(value: 'select', child: Text('Seleção')),
                                  DropdownMenuItem(value: 'yesno', child: Text('Sim ou não')),
                                  DropdownMenuItem(value: 'checkbox', child: Text('Caixa de Seleção')),
                                ],
                                onChanged: (value) => setState(() => field['type'] = value ?? 'text'),
                              ),
                              SwitchListTile(
                                value: required,
                                title: const Text('Obrigatório'),
                                onChanged: (value) => setState(() => field['required'] = value),
                              ),
                              if (fieldType == 'select')
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: optionController,
                                            decoration: const InputDecoration(labelText: 'Adicionar opção'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton(
                                          onPressed: () {
                                            final value = optionController.text.trim();
                                            if (value.isEmpty) return;
                                            _addOption(field, value);
                                            optionController.clear();
                                          },
                                          child: const Text('Incluir'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (options.isEmpty) const Text('Nenhuma opção adicionada.'),
                                    ...options.map(
                                      (option) => Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(option),
                                          IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: () => _removeOption(field, option),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton(
                                  onPressed: () => _removeField(section, field),
                                  child: const Text('Remover campo'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Salvando...' : 'Salvar modelo'),
          ),
        ],
      ),
    );
  }
}


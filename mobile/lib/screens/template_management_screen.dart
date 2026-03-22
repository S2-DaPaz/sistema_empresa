import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_tokens.dart';
import '../utils/entity_config.dart';
import '../utils/field_config.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_ui.dart';
import '../widgets/form_fields.dart';
import '../widgets/loading_view.dart';
import 'entity_form_screen.dart';

enum TemplateTab {
  templates,
  taskTypes,
}

class TemplateManagementScreen extends StatefulWidget {
  const TemplateManagementScreen({
    super.key,
    required this.initialTab,
  });

  final TemplateTab initialTab;

  @override
  State<TemplateManagementScreen> createState() =>
      _TemplateManagementScreenState();
}

class _TemplateManagementScreenState extends State<TemplateManagementScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  late TemplateTab _tab;
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _taskTypes = [];
  String _query = '';
  int? _selectedTemplateId;
  int? _selectedTaskTypeId;

  EntityConfig get _taskTypeConfig => EntityConfig(
        title: 'Tipos de tarefa',
        endpoint: '/task-types',
        primaryField: 'name',
        hint: 'Padronize os fluxos e vincule o template correto a cada tipo.',
        fields: [
          FieldConfig(name: 'name', label: 'Nome', type: FieldType.text),
          FieldConfig(
            name: 'description',
            label: 'Descrição',
            type: FieldType.textarea,
          ),
          FieldConfig(
            name: 'report_template_id',
            label: 'Template de relatório',
            type: FieldType.select,
            options: _templates
                .map(
                  (item) => FieldOption(
                    value: item['id'],
                    label: item['name']?.toString() ?? 'Template',
                  ),
                )
                .toList(),
          ),
        ],
      );

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.get('/report-templates'),
        _api.get('/task-types'),
      ]);

      if (!mounted) {
        return;
      }

      final templates =
          (results[0] as List<dynamic>).cast<Map<String, dynamic>>();
      final taskTypes =
          (results[1] as List<dynamic>).cast<Map<String, dynamic>>();

      setState(() {
        _templates = templates;
        _taskTypes = taskTypes;
        _selectedTemplateId ??=
            templates.isEmpty ? null : templates.first['id'] as int?;
        _selectedTaskTypeId ??=
            taskTypes.isEmpty ? null : taskTypes.first['id'] as int?;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Não foi possível carregar os templates e tipos agora.';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredTemplates {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return _templates;
    }
    return _templates.where((item) {
      final searchable = [
        item['name'],
        item['description'],
      ].map((value) => value?.toString() ?? '').join(' ').toLowerCase();
      return searchable.contains(normalizedQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredTaskTypes {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return _taskTypes;
    }
    return _taskTypes.where((item) {
      final searchable = [
        item['name'],
        item['description'],
        _templateName(item['report_template_id']),
      ].map((value) => value?.toString() ?? '').join(' ').toLowerCase();
      return searchable.contains(normalizedQuery);
    }).toList();
  }

  Map<String, dynamic>? get _selectedTemplate {
    for (final item in _filteredTemplates) {
      if (item['id'] == _selectedTemplateId) {
        return item;
      }
    }
    return _filteredTemplates.isEmpty ? null : _filteredTemplates.first;
  }

  Map<String, dynamic>? get _selectedTaskType {
    for (final item in _filteredTaskTypes) {
      if (item['id'] == _selectedTaskTypeId) {
        return item;
      }
    }
    return _filteredTaskTypes.isEmpty ? null : _filteredTaskTypes.first;
  }

  String _templateName(dynamic id) {
    final match = _templates.firstWhere(
      (item) => item['id']?.toString() == id?.toString(),
      orElse: () => {},
    );
    return match['name']?.toString() ?? 'Sem template vinculado';
  }

  Future<void> _openTemplateEditor({Map<String, dynamic>? template}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemplateEditorScreen(template: template),
      ),
    );
    await _load();
  }

  Future<void> _openTaskTypeForm({Map<String, dynamic>? item}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntityFormScreen(config: _taskTypeConfig, item: item),
      ),
    );
    await _load();
  }

  Future<void> _deleteTemplate(Map<String, dynamic> template) async {
    final id = template['id'];
    if (id == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover template'),
        content: const Text('Deseja remover este template de relatório?'),
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
    await _api.delete('/report-templates/$id');
    await _load();
  }

  Future<void> _deleteTaskType(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover tipo de tarefa'),
        content: const Text('Deseja remover este tipo de tarefa?'),
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
    await _api.delete('/task-types/$id');
    await _load();
  }

  Future<void> _duplicateCurrentItem() async {
    if (_tab == TemplateTab.templates) {
      final current = _selectedTemplate;
      if (current == null) {
        return;
      }
      final copy = Map<String, dynamic>.from(current)
        ..remove('id')
        ..['name'] = 'Cópia de ${current['name']}';
      await _openTemplateEditor(template: copy);
      return;
    }

    final current = _selectedTaskType;
    if (current == null) {
      return;
    }
    final copy = Map<String, dynamic>.from(current)
      ..remove('id')
      ..['name'] = 'Cópia de ${current['name']}';
    await _openTaskTypeForm(item: copy);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        title: 'Templates e tipos',
        subtitle: 'Padronização do processo',
        showLogo: false,
        body: LoadingView(),
      );
    }

    if (_error != null) {
      return AppScaffold(
        title: 'Templates e tipos',
        subtitle: 'Padronização do processo',
        showLogo: false,
        body: AppMessageBanner(
          message: _error!,
          icon: Icons.error_outline_rounded,
          toneColor: Theme.of(context).colorScheme.error,
        ),
      );
    }

    final templates = _filteredTemplates;
    final taskTypes = _filteredTaskTypes;
    final selectedTemplate = _selectedTemplate;
    final selectedTaskType = _selectedTaskType;

    return AppScaffold(
      title: 'Templates e tipos',
      subtitle: 'Padronização do processo',
      showLogo: false,
      body: ListView(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Templates'),
                selected: _tab == TemplateTab.templates,
                onSelected: (_) => setState(() => _tab = TemplateTab.templates),
              ),
              ChoiceChip(
                label: const Text('Tipos de tarefa'),
                selected: _tab == TemplateTab.taskTypes,
                onSelected: (_) => setState(() => _tab = TemplateTab.taskTypes),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space5),
          AppSearchField(
            controller: _searchController,
            hintText: _tab == TemplateTab.templates
                ? 'Buscar por nome ou descrição'
                : 'Buscar por nome, descrição ou template',
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
          const SizedBox(height: AppTokens.space5),
          if (_tab == TemplateTab.templates && selectedTemplate != null)
            AppSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Template destacado',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppTokens.space3),
                  Text(
                    selectedTemplate['name']?.toString() ?? 'Template',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedTemplate['description']?.toString().trim().isNotEmpty ==
                            true
                        ? selectedTemplate['description'].toString()
                        : 'Campos de checklist, fotos, observações e exportação técnica.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          if (_tab == TemplateTab.taskTypes && selectedTaskType != null)
            AppSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tipo destacado',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppTokens.space3),
                  Text(
                    selectedTaskType['name']?.toString() ?? 'Tipo',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedTaskType['description']?.toString().trim().isNotEmpty ==
                            true
                        ? selectedTaskType['description'].toString()
                        : 'Fluxo operacional vinculado a um template específico.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  AppStatusPill(
                    label: _templateName(selectedTaskType['report_template_id']),
                    color: AppTokens.primaryCyan,
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppTokens.space5),
          if (_tab == TemplateTab.templates && _templates.isEmpty)
            EmptyStateCard(
              title: 'Nenhum template cadastrado',
              subtitle: 'Crie o primeiro template para padronizar os relatórios técnicos.',
              action: ElevatedButton(
                onPressed: () => _openTemplateEditor(),
                child: const Text('Criar template'),
              ),
            ),
          if (_tab == TemplateTab.taskTypes && _taskTypes.isEmpty)
            EmptyStateCard(
              title: 'Nenhum tipo de tarefa cadastrado',
              subtitle: 'Crie o primeiro tipo para organizar os fluxos operacionais.',
              action: ElevatedButton(
                onPressed: () => _openTaskTypeForm(),
                child: const Text('Criar tipo'),
              ),
            ),
          if (_tab == TemplateTab.templates &&
              _templates.isNotEmpty &&
              templates.isEmpty)
            const EmptyStateCard(
              title: 'Nenhum template encontrado',
              subtitle: 'Ajuste a busca para localizar outro padrão de relatório.',
            ),
          if (_tab == TemplateTab.taskTypes &&
              _taskTypes.isNotEmpty &&
              taskTypes.isEmpty)
            const EmptyStateCard(
              title: 'Nenhum tipo encontrado',
              subtitle: 'Ajuste a busca para localizar outro fluxo de tarefa.',
            ),
          if (_tab == TemplateTab.templates)
            ...templates.map(_buildTemplateTile),
          if (_tab == TemplateTab.taskTypes)
            ...taskTypes.map(_buildTaskTypeTile),
          const SizedBox(height: AppTokens.space4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      (_tab == TemplateTab.templates && _selectedTemplate == null) ||
                              (_tab == TemplateTab.taskTypes &&
                                  _selectedTaskType == null)
                          ? null
                          : _duplicateCurrentItem,
                  child: const Text('Duplicar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_tab == TemplateTab.templates) {
                      _openTemplateEditor();
                    } else {
                      _openTaskTypeForm();
                    }
                  },
                  child: Text(
                    _tab == TemplateTab.templates ? 'Criar novo' : 'Criar tipo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildTemplateTile(Map<String, dynamic> template) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurface(
        onTap: () => setState(
          () => _selectedTemplateId = template['id'] as int?,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTokens.accentBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: AppTokens.accentBlue,
              ),
            ),
            const SizedBox(width: AppTokens.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template['name']?.toString() ?? 'Template',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template['description']?.toString().trim().isNotEmpty == true
                        ? template['description'].toString()
                        : 'Template sem descrição detalhada.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const AppStatusPill(label: 'template'),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _openTemplateEditor(template: template);
                } else if (value == 'delete') {
                  _deleteTemplate(template);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Remover')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTypeTile(Map<String, dynamic> taskType) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurface(
        onTap: () => setState(
          () => _selectedTaskTypeId = taskType['id'] as int?,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTokens.primaryCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.category_outlined,
                color: AppTokens.primaryCyan,
              ),
            ),
            const SizedBox(width: AppTokens.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    taskType['name']?.toString() ?? 'Tipo',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    taskType['description']?.toString().trim().isNotEmpty == true
                        ? taskType['description'].toString()
                        : _templateName(taskType['report_template_id']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const AppStatusPill(label: 'tipo'),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _openTaskTypeForm(item: taskType);
                } else if (value == 'delete') {
                  _deleteTaskType(taskType);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Remover')),
              ],
            ),
          ],
        ),
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
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  String _sectionColumns = '1';
  String _fieldColumns = '1';
  List<Map<String, dynamic>> _sections = [];
  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.template?['id'] != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.template?['name']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.template?['description']?.toString() ?? '',
    );

    final structure =
        Map<String, dynamic>.from(widget.template?['structure'] as Map? ?? {});
    final layout =
        Map<String, dynamic>.from(structure['layout'] as Map? ?? {});
    _sectionColumns = layout['sectionColumns']?.toString() ?? '1';
    _fieldColumns = layout['fieldColumns']?.toString() ?? '1';
    _sections = (structure['sections'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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
    final fields = (section['fields'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
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
    final fields = (section['fields'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    fields.remove(field);
    setState(() => section['fields'] = fields);
  }

  Future<String?> _promptOptionValue() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar opção'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Opção'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> _addOption(Map<String, dynamic> field) async {
    final option = await _promptOptionValue();
    if (option == null) {
      return;
    }
    final options = (field['options'] as List<dynamic>? ?? []).cast<String>();
    options.add(option);
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
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
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
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    } catch (_) {
      setState(() {
        _error = 'Não foi possível salvar o template agora.';
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
      title: _isEdit ? 'Editar template' : 'Novo template',
      subtitle: 'Padronização do relatório técnico',
      showLogo: false,
      body: ListView(
        children: [
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dados principais',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.space4),
                AppTextField(
                  label: 'Nome do template',
                  controller: _nameController,
                ),
                const SizedBox(height: AppTokens.space4),
                AppTextField(
                  label: 'Descrição',
                  controller: _descriptionController,
                  maxLines: 4,
                ),
                const SizedBox(height: AppTokens.space4),
                AppDropdownField<String>(
                  label: 'Colunas das seções',
                  value: _sectionColumns,
                  items: const [
                    DropdownMenuItem(value: '1', child: Text('1 coluna')),
                    DropdownMenuItem(value: '2', child: Text('2 colunas')),
                    DropdownMenuItem(value: '3', child: Text('3 colunas')),
                  ],
                  onChanged: (value) =>
                      setState(() => _sectionColumns = value ?? '1'),
                ),
                const SizedBox(height: AppTokens.space4),
                AppDropdownField<String>(
                  label: 'Colunas dos campos',
                  value: _fieldColumns,
                  items: const [
                    DropdownMenuItem(value: '1', child: Text('1 coluna')),
                    DropdownMenuItem(value: '2', child: Text('2 colunas')),
                    DropdownMenuItem(value: '3', child: Text('3 colunas')),
                  ],
                  onChanged: (value) =>
                      setState(() => _fieldColumns = value ?? '1'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Seções do template',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              OutlinedButton(
                onPressed: _addSection,
                child: const Text('Adicionar seção'),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space4),
          if (_sections.isEmpty)
            const EmptyStateCard(
              title: 'Nenhuma seção criada',
              subtitle: 'Adicione as seções e campos que compõem o relatório.',
            ),
          ..._sections.map(_buildSectionCard),
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
                  child: Text(_saving ? 'Salvando...' : 'Salvar template'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionCard(Map<String, dynamic> section) {
    final fields = (section['fields'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (section['title']?.toString().trim() ?? '').isNotEmpty
                        ? section['title'].toString()
                        : 'Nova seção',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: () => _removeSection(section),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space2),
            AppTextField(
              label: 'Título da seção',
              initialValue: section['title']?.toString() ?? '',
              onChanged: (value) => section['title'] = value,
            ),
            const SizedBox(height: AppTokens.space4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Campos',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                TextButton(
                  onPressed: () => _addField(section),
                  child: const Text('Adicionar campo'),
                ),
              ],
            ),
            if (fields.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Adicione o primeiro campo para começar a estrutura.',
                ),
              ),
            ...fields.map((field) => _buildFieldCard(section, field)),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldCard(
    Map<String, dynamic> section,
    Map<String, dynamic> field,
  ) {
    final options = (field['options'] as List<dynamic>? ?? []).cast<String>();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppSurface(
        backgroundColor: AppTokens.bgSoft,
        shadow: const [],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'Label do campo',
              initialValue: field['label']?.toString() ?? '',
              onChanged: (value) => field['label'] = value,
            ),
            const SizedBox(height: AppTokens.space4),
            AppDropdownField<String>(
              label: 'Tipo',
              value: field['type']?.toString() ?? 'text',
              items: const [
                DropdownMenuItem(value: 'text', child: Text('Texto curto')),
                DropdownMenuItem(value: 'textarea', child: Text('Texto longo')),
                DropdownMenuItem(value: 'number', child: Text('Número')),
                DropdownMenuItem(value: 'date', child: Text('Data')),
                DropdownMenuItem(value: 'select', child: Text('Seleção')),
                DropdownMenuItem(value: 'yesno', child: Text('Sim ou não')),
                DropdownMenuItem(
                  value: 'checkbox',
                  child: Text('Caixa de seleção'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => field['type'] = value ?? 'text'),
            ),
            const SizedBox(height: AppTokens.space4),
            AppCheckboxField(
              label: 'Campo obrigatório',
              value: field['required'] == true,
              onChanged: (value) =>
                  setState(() => field['required'] = value == true),
            ),
            if (field['type'] == 'select') ...[
              const SizedBox(height: AppTokens.space4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Opções',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  TextButton(
                    onPressed: () => _addOption(field),
                    child: const Text('Adicionar opção'),
                  ),
                ],
              ),
              if (options.isEmpty) const Text('Nenhuma opção adicionada.'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options
                    .map(
                      (option) => InputChip(
                        label: Text(option),
                        onDeleted: () => _removeOption(field, option),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: AppTokens.space3),
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
  }
}

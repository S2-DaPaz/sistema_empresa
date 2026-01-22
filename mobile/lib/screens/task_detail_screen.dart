import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import '../utils/report_text.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/budget_form.dart';
import '../widgets/brand_logo.dart';
import '../widgets/form_fields.dart';
import '../widgets/loading_view.dart';
import '../widgets/signature_pad.dart';
import 'pdf_viewer_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, this.taskId});

  final int? taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> with TickerProviderStateMixin {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  String? _error;

  int? _taskId;
  String _status = 'aberta';
  String _priority = 'media';
  int? _clientId;
  int? _userId;
  int? _taskTypeId;

  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _startDate = TextEditingController();
  final TextEditingController _dueDate = TextEditingController();

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _equipments = [];
  List<Map<String, dynamic>> _taskEquipments = [];

  List<Map<String, dynamic>> _reports = [];
  int? _activeReportId;
  List<Map<String, dynamic>> _reportSections = [];
  Map<String, dynamic> _reportAnswers = {};
  List<Map<String, dynamic>> _reportPhotos = [];
  String _reportStatus = 'rascunho';
  String? _reportMessage;

  List<Map<String, dynamic>> _budgets = [];

  String _signatureMode = 'none';
  String _signatureScope = 'last_page';
  String _signatureClient = '';
  String _signatureTech = '';
  Map<String, dynamic> _signaturePages = {};

  int? _selectedEquipmentId;
  final TextEditingController _equipmentName = TextEditingController();
  final TextEditingController _equipmentModel = TextEditingController();
  final TextEditingController _equipmentSerial = TextEditingController();
  final TextEditingController _equipmentDescription = TextEditingController();

  @override
  void initState() {
    super.initState();
    _taskId = widget.taskId;
    _loadAll();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _startDate.dispose();
    _dueDate.dispose();
    _equipmentName.dispose();
    _equipmentModel.dispose();
    _equipmentSerial.dispose();
    _equipmentDescription.dispose();
    super.dispose();
  }

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return {};
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final clients = await _api.get('/clients') as List<dynamic>;
      final users = AuthService.instance.isAdmin
          ? await _api.get('/users') as List<dynamic>
          : <dynamic>[];
      final types = await _api.get('/task-types') as List<dynamic>;
      final templates = await _api.get('/report-templates') as List<dynamic>;
      final products = await _api.get('/products') as List<dynamic>;

      _clients = clients.cast<Map<String, dynamic>>();
      _users = users.cast<Map<String, dynamic>>();
      _types = types.cast<Map<String, dynamic>>();
      _templates = templates.cast<Map<String, dynamic>>();
      _products = products.cast<Map<String, dynamic>>();

      if (_taskId != null) {
        final task = await _api.get('/tasks/$_taskId') as Map<String, dynamic>;
        _title.text = task['title']?.toString() ?? '';
        _description.text = task['description']?.toString() ?? '';
        _clientId = task['client_id'] as int?;
        _userId = task['user_id'] as int?;
        _taskTypeId = task['task_type_id'] as int?;
        _status = task['status']?.toString() ?? 'aberta';
        _priority = task['priority']?.toString() ?? 'media';
        _startDate.text = task['start_date']?.toString() ?? '';
        _dueDate.text = task['due_date']?.toString() ?? '';
        _signatureMode = task['signature_mode']?.toString() ?? 'none';
        _signatureScope = task['signature_scope']?.toString() ?? 'last_page';
        _signatureClient = task['signature_client']?.toString() ?? '';
        _signatureTech = task['signature_tech']?.toString() ?? '';
        _signaturePages = _safeMap(task['signature_pages']);

        await _loadReports(_taskTypeId);
        await _loadBudgets(_reports);
        await _loadTaskEquipments();
      }

      await _loadClientEquipments();
    } catch (error) {
      _error = error.toString();
    } finally {
      setState(() => _loading = false);
    }
  }
  Future<void> _loadClientEquipments() async {
    if (_clientId == null) {
      setState(() => _equipments = []);
      return;
    }
    final data = await _api.get('/equipments?clientId=$_clientId') as List<dynamic>;
    setState(() => _equipments = data.cast<Map<String, dynamic>>());
  }

  Future<void> _loadReports(int? taskTypeId) async {
    if (_taskId == null) return;
    final data = await _api.get('/reports?taskId=$_taskId') as List<dynamic>;
    final nextReports = data.cast<Map<String, dynamic>>();
    final defaultReport = nextReports.firstWhere(
      (item) => item['equipment_id'] == null,
      orElse: () => nextReports.isNotEmpty ? nextReports.first : <String, dynamic>{},
    );
    final nextActiveId = defaultReport['id'] as int?;
    setState(() {
      _reports = nextReports;
      _activeReportId = nextActiveId;
      if (nextActiveId != null) {
        _applyReportData(defaultReport, taskTypeId);
      }
    });
  }

  Future<void> _loadBudgets(List<Map<String, dynamic>> reportList) async {
    if (_taskId == null) return;
    final byTaskRaw = await _api.get('/budgets?taskId=$_taskId&includeItems=1');
    final byTask = byTaskRaw is List ? byTaskRaw : <dynamic>[];
    final reportIds = reportList.map((report) => report['id']).whereType<int>().toList();
    final byReports = await Future.wait(
      reportIds.map((id) => _api.get('/budgets?reportId=$id&includeItems=1')),
    );

    final merged = <int, Map<String, dynamic>>{};
    for (final item in byTask) {
      if (item is Map<String, dynamic> && item['id'] != null) {
        merged[item['id'] as int] = item;
      }
    }
    for (final list in byReports) {
      if (list is! List) continue;
      for (final item in list) {
        if (item is Map<String, dynamic> && item['id'] != null) {
          merged[item['id'] as int] = item;
        }
      }
    }

    setState(() => _budgets = merged.values.toList());
  }

  Future<void> _editBudget(Map<String, dynamic> budget) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          minChildSize: 0.6,
          maxChildSize: 0.98,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: BudgetForm(
                  initialBudget: budget,
                  clients: _clients,
                  products: _products,
                  clientId: _clientId ?? budget['client_id'] as int?,
                  taskId: budget['task_id'] as int? ?? _taskId,
                  reportId: budget['report_id'] as int?,
                  onSaved: () => Navigator.pop(context, true),
                ),
              ),
            );
          },
        );
      },
    );

    if (updated == true) {
      await _loadBudgets(_reports);
    }
  }

  Future<void> _deleteBudget(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover orçamento'),
        content: const Text('Deseja remover este orçamento?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.delete('/budgets/$id');
      await _loadBudgets(_reports);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _loadTaskEquipments() async {
    if (_taskId == null) return;
    final data = await _api.get('/tasks/$_taskId/equipments') as List<dynamic>;
    setState(() => _taskEquipments = data.cast<Map<String, dynamic>>());
  }

  void _applyReportData(Map<String, dynamic> report, int? taskTypeId) {
    final content = report['content'] as Map<String, dynamic>? ?? {};
    var sections = (content['sections'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    if (sections.isEmpty && taskTypeId != null) {
      final type = _types.firstWhere(
        (item) => item['id'] == taskTypeId,
        orElse: () => <String, dynamic>{},
      );
      final templateId = type['report_template_id'];
      final template = _templates.firstWhere(
        (item) => item['id'] == templateId,
        orElse: () => <String, dynamic>{},
      );
      final structure = template['structure'] as Map<String, dynamic>? ?? {};
      sections = (structure['sections'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    }

    _reportSections = sections;
    _reportAnswers = content['answers'] as Map<String, dynamic>? ?? {};
    _reportPhotos = (content['photos'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    _reportStatus = report['status']?.toString() ?? 'rascunho';
  }

  Map<String, dynamic>? get _activeReport {
    return _reports.firstWhere(
      (item) => item['id'] == _activeReportId,
      orElse: () => <String, dynamic>{},
    );
  }

  Map<String, dynamic>? get _selectedTemplate {
    final type = _types.firstWhere(
      (item) => item['id'] == _taskTypeId,
      orElse: () => <String, dynamic>{},
    );
    final templateId = type['report_template_id'];
    if (templateId == null) return null;
    return _templates.firstWhere(
      (item) => item['id'] == templateId,
      orElse: () => <String, dynamic>{},
    );
  }
  Future<void> _saveTask() async {
    setState(() => _error = null);
    final payload = {
      'title': _title.text,
      'description': _description.text,
      'client_id': _clientId,
      'user_id': _userId,
      'task_type_id': _taskTypeId,
      'status': _status,
      'priority': _priority,
      'start_date': _startDate.text,
      'due_date': _dueDate.text,
      'signature_mode': _signatureMode,
      'signature_scope': _signatureScope,
      'signature_client': _signatureClient.isEmpty ? null : _signatureClient,
      'signature_tech': _signatureTech.isEmpty ? null : _signatureTech,
      'signature_pages': _signaturePages,
    };

    try {
      if (_taskId == null) {
        final saved = await _api.post('/tasks', payload) as Map<String, dynamic>;
        _taskId = saved['id'] as int?;
      } else {
        await _api.put('/tasks/$_taskId', payload);
      }
      await _loadReports(_taskTypeId);
      await _loadBudgets(_reports);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _saveReport() async {
    if (_activeReportId == null) {
      setState(() => _reportMessage = 'Salve a tarefa para gerar o relatório.');
      return;
    }

    final templateId = _activeReport?['template_id'] ?? _selectedTemplate?['id'];
    final payload = {
      'title': _activeReport?['title'] ?? _title.text,
      'task_id': _taskId,
      'client_id': _clientId,
      'template_id': templateId,
      'equipment_id': _activeReport?['equipment_id'],
      'status': _reportStatus,
      'content': {
        'sections': _reportSections,
        'layout': _activeReport?['content']?['layout'] ?? _selectedTemplate?['structure']?['layout'],
        'answers': _reportAnswers,
        'photos': _reportPhotos,
      },
    };

    try {
      await _api.put('/reports/$_activeReportId', payload);
      setState(() => _reportMessage = 'Relatório salvo com sucesso.');
      await _loadReports(_taskTypeId);
    } catch (error) {
      setState(() => _reportMessage = error.toString());
    }
  }

  Future<void> _createReport() async {
    if (_taskId == null) return;
    if (_clientId == null) {
      setState(() => _reportMessage = 'Selecione um cliente antes de criar o relatório.');
      return;
    }
    final template = _selectedTemplate;
    if (template == null) {
      setState(() => _reportMessage = 'Este tipo de tarefa não possui modelo de relatório.');
      return;
    }

    final payload = {
      'title': 'Relatório adicional',
      'task_id': _taskId,
      'client_id': _clientId,
      'template_id': template['id'],
      'equipment_id': null,
      'status': 'rascunho',
      'content': {
        'sections': template['structure']?['sections'] ?? [],
        'layout': template['structure']?['layout'] ?? {'sectionColumns': 1, 'fieldColumns': 1},
        'answers': {},
        'photos': [],
      },
    };

    try {
      final created = await _api.post('/reports', payload) as Map<String, dynamic>;
      await _loadReports(_taskTypeId);
      setState(() {
        _activeReportId = created['id'] as int?;
        _reportMessage = 'Relatório criado com sucesso.';
      });
    } catch (error) {
      setState(() => _reportMessage = error.toString());
    }
  }

  Future<void> _deleteReport() async {
    if (_activeReportId == null) return;
    final report = _activeReport;
    if (report == null || report['equipment_id'] != null) {
      setState(() => _reportMessage = 'Remova o equipamento para excluir este relatório.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir relatório'),
        content: const Text('Deseja excluir este relatório?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _api.delete('/reports/$_activeReportId');
    await _loadReports(_taskTypeId);
    await _loadBudgets(_reports);
  }

  Future<void> _addPhotos() async {
    final files = await _picker.pickMultiImage();
    if (files.isEmpty) return;
    final newPhotos = <Map<String, dynamic>>[];
    for (final file in files) {
      final bytes = await File(file.path).readAsBytes();
      final mime = _inferMime(file.path);
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      newPhotos.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'name': path.basename(file.path),
        'dataUrl': dataUrl,
      });
    }
    setState(() => _reportPhotos = [..._reportPhotos, ...newPhotos]);
  }

  String _inferMime(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    if (ext == '.png') return 'image/png';
    if (ext == '.webp') return 'image/webp';
    return 'image/jpeg';
  }

  void _removePhoto(String photoId) {
    setState(() => _reportPhotos.removeWhere((photo) => photo['id'] == photoId));
  }

  Future<void> _attachEquipment() async {
    if (_taskId == null || _selectedEquipmentId == null) return;
    await _api.post('/tasks/$_taskId/equipments', {'equipment_id': _selectedEquipmentId});
    await _loadTaskEquipments();
    await _loadReports(_taskTypeId);
  }

  Future<void> _createEquipment() async {
    if (_clientId == null || _taskId == null) return;
    final payload = {
      'client_id': _clientId,
      'name': _equipmentName.text,
      'model': _equipmentModel.text,
      'serial': _equipmentSerial.text,
      'description': _equipmentDescription.text,
    };
    final created = await _api.post('/equipments', payload) as Map<String, dynamic>;
    _selectedEquipmentId = created['id'] as int?;
    await _attachEquipment();
    _equipmentName.clear();
    _equipmentModel.clear();
    _equipmentSerial.clear();
    _equipmentDescription.clear();
  }

  Future<void> _detachEquipment(int equipmentId) async {
    if (_taskId == null) return;
    await _api.delete('/tasks/$_taskId/equipments/$equipmentId');
    await _loadTaskEquipments();
    await _loadReports(_taskTypeId);
  }

  void _openEquipmentReport(int equipmentId) {
    final report = _reports.firstWhere(
      (item) => item['equipment_id'] == equipmentId,
      orElse: () => <String, dynamic>{},
    );
    if (report['id'] == null) return;
    setState(() {
      _activeReportId = report['id'] as int?;
      _applyReportData(report, _taskTypeId);
    });
  }

  Future<void> _exportTaskPdf() async {
    if (_taskId == null) return;
    if (!ApiConfig.pdfEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exportação de PDF indisponível na API atual.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          title: 'PDF da tarefa',
          pdfFetcher: () => _api.getBytes('/tasks/$_taskId/pdf'),
        ),
      ),
    );
  }

  Future<void> _shareTaskPdf() async {
    if (_taskId == null) return;
    if (!ApiConfig.pdfEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exportação de PDF indisponível na API atual.')),
      );
      return;
    }
    try {
      final bytes = Uint8List.fromList(await _api.getBytes('/tasks/$_taskId/pdf'));
      final file = XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: 'tarefa_$_taskId.pdf',
      );
      await Share.shareXFiles([file], text: 'Tarefa #$_taskId');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _sendReportEmail() async {
    if (_activeReport == null) return;
    final client = _clients.firstWhere(
      (item) => item['id'] == _clientId,
      orElse: () => <String, dynamic>{},
    );
    final emailMatch = RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false)
        .firstMatch(client['contact']?.toString() ?? '');
    final email = emailMatch?.group(0) ?? '';
    final body = buildReportText(
      reportTitle: _activeReport?['title']?.toString() ?? '',
      taskTitle: _title.text,
      clientName: client['name']?.toString(),
      equipmentName: _activeReport?['equipment_name']?.toString(),
      sections: _reportSections,
      answers: _reportAnswers,
    );
    final subject = 'Relatório - ${_title.text}';
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );
    await launchUrl(uri);
  }

  void _updateSignaturePage(String key, String role, String value) {
    final page = Map<String, dynamic>.from(_signaturePages[key] as Map<String, dynamic>? ?? {});
    page[role] = value;
    setState(() => _signaturePages[key] = page);
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDate: now,
    );
    if (selected == null) return;
    controller.text =
        '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    setState(() {});
  }
  Widget _buildDetailsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppTextField(label: 'Título', controller: _title),
        const SizedBox(height: 8),
        AppDropdownField<String>(
          label: 'Status',
          value: _status,
          items: const [
            DropdownMenuItem(value: 'aberta', child: Text('Aberta')),
            DropdownMenuItem(value: 'em_andamento', child: Text('Em andamento')),
            DropdownMenuItem(value: 'concluida', child: Text('Concluída')),
          ],
          onChanged: (value) => setState(() => _status = value ?? 'aberta'),
        ),
        const SizedBox(height: 8),
        AppDropdownField<String>(
          label: 'Prioridade',
          value: _priority,
          items: const [
            DropdownMenuItem(value: 'alta', child: Text('Alta')),
            DropdownMenuItem(value: 'media', child: Text('Media')),
            DropdownMenuItem(value: 'baixa', child: Text('Baixa')),
          ],
          onChanged: (value) => setState(() => _priority = value ?? 'media'),
        ),
        const SizedBox(height: 8),
        AppDropdownField<int>(
          label: 'Cliente',
          value: _clientId,
          items: _clients
              .map((client) => DropdownMenuItem<int>(
                    value: client['id'] as int?,
                    child: Text(client['name']?.toString() ?? 'Cliente'),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() => _clientId = value);
            _loadClientEquipments();
          },
        ),
        const SizedBox(height: 8),
        if (_users.isNotEmpty) ...[
          AppDropdownField<int>(
            label: 'Responsavel',
            value: _userId,
            items: _users
                .map((user) => DropdownMenuItem<int>(
                      value: user['id'] as int?,
                      child: Text(user['name']?.toString() ?? 'Usuário'),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _userId = value),
          ),
          const SizedBox(height: 8),
        ],
        AppDropdownField<int>(
          label: 'Tipo de tarefa',
          value: _taskTypeId,
          items: _types
              .map((type) => DropdownMenuItem<int>(
                    value: type['id'] as int?,
                    child: Text(type['name']?.toString() ?? 'Tipo'),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _taskTypeId = value),
        ),
        const SizedBox(height: 8),
        AppDateField(
          key: ValueKey(_startDate.text),
          label: 'Inicio',
          value: _startDate.text,
          onTap: () => _pickDate(_startDate),
        ),
        const SizedBox(height: 8),
        AppDateField(
          key: ValueKey(_dueDate.text),
          label: 'Fim',
          value: _dueDate.text,
          onTap: () => _pickDate(_dueDate),
        ),
        const SizedBox(height: 8),
        AppTextField(label: 'Descrição', controller: _description, maxLines: 3),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _saveTask,
          child: Text(_taskId == null ? 'Salvar tarefa' : 'Atualizar tarefa'),
        ),
      ],
    );
  }

  Widget _buildReportTab() {
    final reportOptions = _reports
        .map((report) => DropdownMenuItem<int>(
              value: report['id'] as int?,
              child: Text(
                report['title']?.toString() ??
                    (report['equipment_name'] != null
                        ? 'Relatório - ${report['equipment_name']}'
                        : 'Relatório'),
              ),
            ))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_taskId == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Salve a tarefa para habilitar o relatório.'),
            ),
          ),
        if (_taskId != null && _selectedTemplate == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Este tipo de tarefa não possui modelo de relatório.'),
            ),
          ),
        if (_taskId != null && _selectedTemplate != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Relatórios da tarefa', style: Theme.of(context).textTheme.titleSmall),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(onPressed: _createReport, child: const Text('Adicionar')),
                          OutlinedButton(onPressed: _deleteReport, child: const Text('Excluir')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AppDropdownField<int>(
                    label: 'Relatório',
                    value: _activeReportId,
                    items: reportOptions,
                    onChanged: (value) {
                      final report = _reports.firstWhere(
                        (item) => item['id'] == value,
                        orElse: () => <String, dynamic>{},
                      );
                      setState(() {
                        _activeReportId = value;
                        _applyReportData(report, _taskTypeId);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  AppDropdownField<String>(
                    label: 'Status',
                    value: _reportStatus,
                    items: const [
                      DropdownMenuItem(value: 'rascunho', child: Text('Rascunho')),
                      DropdownMenuItem(value: 'enviado', child: Text('Enviado')),
                      DropdownMenuItem(value: 'finalizado', child: Text('Finalizado')),
                    ],
                    onChanged: (value) => setState(() => _reportStatus = value ?? 'rascunho'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Fotos', style: Theme.of(context).textTheme.titleSmall),
                      OutlinedButton(onPressed: _addPhotos, child: const Text('Adicionar')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_reportPhotos.isEmpty) const Text('Sem fotos anexadas.'),
                  if (_reportPhotos.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _reportPhotos
                          .map((photo) => SizedBox(
                                width: 120,
                                child: Column(
                                  children: [
                                    Image.memory(
                                      base64Decode(photo['dataUrl'].toString().split(',').last),
                                      height: 90,
                                      fit: BoxFit.cover,
                                    ),
                                    TextButton(
                                      onPressed: () => _removePhoto(photo['id'].toString()),
                                      child: const Text('Remover'),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 12),
                  Text('Formulario', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (_reportSections.isEmpty) const Text('Este modelo ainda não possui campos.'),
                  ..._reportSections.map((section) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(section['title']?.toString() ?? 'Seção',
                                  style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 8),
                              ..._buildReportFields(section),
                            ],
                          ),
                        ),
                      )),
                  if (_reportMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_reportMessage!, style: const TextStyle(color: Colors.blueGrey)),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(onPressed: _saveReport, child: const Text('Salvar relatório')),
                      OutlinedButton(onPressed: _sendReportEmail, child: const Text('Enviar e-mail')),
                      if (ApiConfig.pdfEnabled)
                        OutlinedButton(onPressed: _exportTaskPdf, child: const Text('Exportar PDF')),
                      if (ApiConfig.pdfEnabled)
                        OutlinedButton(onPressed: _shareTaskPdf, child: const Text('Compartilhar')),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildReportFields(Map<String, dynamic> section) {
    final fields = (section['fields'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return fields.map((field) {
      final fieldId = field['id']?.toString() ?? '';
      final label = field['label']?.toString() ?? 'Campo';
      final type = field['type']?.toString() ?? 'text';
      final value = _reportAnswers[fieldId];

      if (type == 'textarea') {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppTextField(
            key: ValueKey('field-${_activeReportId ?? "new"}-$fieldId'),
            label: label,
            initialValue: value?.toString() ?? '',
            maxLines: 3,
            onChanged: (val) => setState(() => _reportAnswers[fieldId] = val),
          ),
        );
      }
      if (type == 'select') {
        final options = (field['options'] as List<dynamic>? ?? [])
            .map((option) => DropdownMenuItem<String>(
                  value: option.toString(),
                  child: Text(
                    option.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppDropdownField<String>(
            label: label,
            value: value?.toString(),
            items: options,
            onChanged: (val) => setState(() => _reportAnswers[fieldId] = val),
          ),
        );
      }
      if (type == 'yesno') {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppDropdownField<String>(
            label: label,
            value: value?.toString(),
            items: const [
              DropdownMenuItem(value: 'sim', child: Text('Sim')),
              DropdownMenuItem(value: 'nao', child: Text('Não')),
            ],
            onChanged: (val) => setState(() => _reportAnswers[fieldId] = val),
          ),
        );
      }
      if (type == 'checkbox') {
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: value == true,
          onChanged: (val) => setState(() => _reportAnswers[fieldId] = val),
        );
      }
      if (type == 'date') {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppDateField(
            key: ValueKey('date-${_activeReportId ?? "new"}-$fieldId-${value ?? ""}'),
            label: label,
            value: value?.toString() ?? '',
            onTap: () async {
              final now = DateTime.now();
              final selected = await showDatePicker(
                context: context,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 5),
                initialDate: now,
              );
              if (selected == null) return;
              final formatted =
                  '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
              setState(() => _reportAnswers[fieldId] = formatted);
            },
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppTextField(
          key: ValueKey('field-${_activeReportId ?? "new"}-$fieldId'),
          label: label,
          initialValue: value?.toString() ?? '',
          onChanged: (val) => setState(() => _reportAnswers[fieldId] = val),
        ),
      );
    }).toList();
  }

  Widget _buildBudgetsTab() {
    final generalReport = _reports.firstWhere(
      (item) => item['equipment_id'] == null,
      orElse: () => <String, dynamic>{},
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_taskId == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Salve a tarefa para liberar os orçamentos.'),
            ),
          ),
        if (_taskId != null) ...[
          BudgetForm(
            clientId: _clientId,
            taskId: _taskId,
            reportId: generalReport['id'] as int?,
            products: _products,
            onSaved: () => _loadBudgets(_reports),
          ),
          const SizedBox(height: 12),
          ..._budgets.map((budget) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Orçamento #${budget['id']}', style: Theme.of(context).textTheme.titleSmall),
                        Row(
                          children: [
                            Chip(label: Text(budget['status']?.toString() ?? 'rascunho')),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editBudget(budget);
                                } else if (value == 'delete') {
                                  _deleteBudget(budget['id'] as int);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 'edit', child: Text('Editar')),
                                PopupMenuItem(value: 'delete', child: Text('Remover')),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Total: ${formatCurrency(budget['total'] ?? 0)}'),
                    const SizedBox(height: 8),
                    ...(budget['items'] as List<dynamic>? ?? [])
                        .cast<Map<String, dynamic>>()
                        .map((item) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(item['description']?.toString() ?? 'Item')),
                                Text(formatCurrency(item['total'] ?? 0)),
                              ],
                            )),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildEquipmentTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_taskId == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Salve a tarefa para adicionar equipamentos.'),
            ),
          ),
        if (_taskId != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Equipamentos da tarefa', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (_taskEquipments.isEmpty) const Text('Nenhum equipamento vinculado.'),
                  ..._taskEquipments.map((equipment) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(equipment['name']?.toString() ?? 'Equipamento'),
                              Text('Modelo: ${equipment['model'] ?? 'Sem modelo'}'),
                              Text('Serie: ${equipment['serial'] ?? '-'}'),
                              if (equipment['description'] != null)
                                Text(equipment['description'].toString()),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => _openEquipmentReport(equipment['id'] as int),
                                    child: const Text('Abrir relatório'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _detachEquipment(equipment['id'] as int),
                                    child: const Text('Remover'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vincular equipamento existente', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  AppDropdownField<int>(
                    label: 'Equipamento',
                    value: _selectedEquipmentId,
                    items: _equipments
                        .map((item) => DropdownMenuItem<int>(
                              value: item['id'] as int?,
                              child: Text(item['name']?.toString() ?? 'Equipamento'),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedEquipmentId = value),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _attachEquipment, child: const Text('Vincular')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cadastrar novo equipamento', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  AppTextField(label: 'Nome', controller: _equipmentName),
                  const SizedBox(height: 8),
                  AppTextField(label: 'Modelo', controller: _equipmentModel),
                  const SizedBox(height: 8),
                  AppTextField(label: 'Serie', controller: _equipmentSerial),
                  const SizedBox(height: 8),
                  AppTextField(label: 'Descrição', controller: _equipmentDescription, maxLines: 3),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _createEquipment, child: const Text('Cadastrar e vincular')),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSignatureTab() {
    final signaturePageItems = [
      ..._reports.map((report) => {
            'key': 'report:${report['id']}',
            'label': report['title']?.toString() ??
                (report['equipment_name'] != null
                    ? 'Relatório - ${report['equipment_name']}'
                    : 'Relatório'),
          }),
      ..._budgets.map((budget) => {
            'key': 'budget:${budget['id']}',
            'label': 'Orçamento #${budget['id']}',
          }),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_taskId == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Salve a tarefa para configurar assinaturas.'),
            ),
          ),
        if (_taskId != null) ...[
          AppDropdownField<String>(
            label: 'Assinaturas',
            value: _signatureMode,
            items: const [
              DropdownMenuItem(value: 'none', child: Text('Sem assinatura')),
              DropdownMenuItem(value: 'client', child: Text('Cliente')),
              DropdownMenuItem(value: 'tech', child: Text('Técnico')),
              DropdownMenuItem(value: 'both', child: Text('Cliente e técnico')),
            ],
            onChanged: (value) => setState(() => _signatureMode = value ?? 'none'),
          ),
          const SizedBox(height: 8),
          AppDropdownField<String>(
            label: 'Aplicação',
            value: _signatureScope,
            items: const [
              DropdownMenuItem(value: 'all_pages', child: Text('Assinar todas as páginas')),
              DropdownMenuItem(value: 'last_page', child: Text('Assinar apenas no final')),
            ],
            onChanged: (value) => setState(() => _signatureScope = value ?? 'last_page'),
          ),
          const SizedBox(height: 12),
          if (_signatureScope == 'last_page') ...[
            if (_signatureMode == 'client' || _signatureMode == 'both')
              SignaturePadField(
                label: 'Assinatura do cliente*',
                value: _signatureClient,
                onChanged: (value) => setState(() => _signatureClient = value),
              ),
            const SizedBox(height: 12),
            if (_signatureMode == 'tech' || _signatureMode == 'both')
              SignaturePadField(
                label: 'Assinatura do técnico*',
                value: _signatureTech,
                onChanged: (value) => setState(() => _signatureTech = value),
              ),
          ],
          if (_signatureScope == 'all_pages' && _signatureMode != 'none') ...[
            ...signaturePageItems.map((page) {
              final key = page['key'] as String;
              final label = page['label'] as String;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      if (_signatureMode == 'client' || _signatureMode == 'both')
                        SignaturePadField(
                          label: 'Assinatura do cliente*',
                          value: (_signaturePages[key] as Map<String, dynamic>? ?? {})['client']?.toString() ?? '',
                          onChanged: (value) => _updateSignaturePage(key, 'client', value),
                        ),
                      const SizedBox(height: 12),
                      if (_signatureMode == 'tech' || _signatureMode == 'both')
                        SignaturePadField(
                          label: 'Assinatura do técnico*',
                          value: (_signaturePages[key] as Map<String, dynamic>? ?? {})['tech']?.toString() ?? '',
                          onChanged: (value) => _updateSignaturePage(key, 'tech', value),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _saveTask, child: const Text('Salvar assinaturas')),
        ],
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(title: 'Tarefa', body: LoadingView());
    }
    if (_error != null) {
      return AppScaffold(title: 'Tarefa', body: Center(child: Text(_error!)));
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const BrandLogo(height: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _taskId == null ? 'Nova tarefa' : 'Tarefa #$_taskId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Detalhes'),
              Tab(text: 'Relatório'),
              Tab(text: 'Orçamentos'),
              Tab(text: 'Equipamentos'),
              Tab(text: 'Assinaturas'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF6F9FC), Color(0xFFEEF3F7)],
            ),
          ),
          child: TabBarView(
            children: [
              _buildDetailsTab(),
              _buildReportTab(),
              _buildBudgetsTab(),
              _buildEquipmentTab(),
              _buildSignatureTab(),
            ],
          ),
        ),
      ),
    );
  }
}

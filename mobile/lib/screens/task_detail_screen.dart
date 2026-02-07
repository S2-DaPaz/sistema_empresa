import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

enum _PhotoSourceOption { camera, gallery }

const int _maxPhotoDimension = 1024;
const int _photoJpegQuality = 60;

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, this.taskId});

  final int? taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> with TickerProviderStateMixin {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();
  late final TabController _tabController;

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
  bool _equipmentsLoading = false;
  String? _equipmentsError;
  int? _reportEquipmentId;

  List<Map<String, dynamic>> _reports = [];
  int? _activeReportId;
  List<Map<String, dynamic>> _reportSections = [];
  Map<String, dynamic> _reportAnswers = {};
  List<Map<String, dynamic>> _reportPhotos = [];
  String _reportStatus = 'rascunho';
  String? _reportMessage;
  Timer? _reportAutosaveTimer;
  bool _reportAutosaving = false;
  bool _reportDirty = false;
  int _reportAutosaveSeq = 0;

  List<Map<String, dynamic>> _budgets = [];

  String _signatureMode = 'none';
  String _signatureScope = 'last_page';
  String _signatureClient = '';
  String _signatureTech = '';
  Map<String, dynamic> _signaturePages = {};

  @override
  void initState() {
    super.initState();
    _taskId = widget.taskId;
    _tabController = TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _reportAutosaveTimer?.cancel();
    _tabController.dispose();
    _title.dispose();
    _description.dispose();
    _startDate.dispose();
    _dueDate.dispose();
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
        _startDate.text = formatDateInput(task['start_date']?.toString());
        _dueDate.text = formatDateInput(task['due_date']?.toString());
        _signatureMode = task['signature_mode']?.toString() ?? 'none';
        _signatureScope = task['signature_scope']?.toString() ?? 'last_page';
        _signatureClient = task['signature_client']?.toString() ?? '';
        _signatureTech = task['signature_tech']?.toString() ?? '';
        _signaturePages = _safeMap(task['signature_pages']);

        await _loadReports(_taskTypeId);
        await _loadBudgets(_reports);
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
      setState(() {
        _equipments = [];
        _equipmentsError = null;
        _equipmentsLoading = false;
        _reportEquipmentId = null;
      });
      return;
    }
    setState(() {
      _equipmentsLoading = true;
      _equipmentsError = null;
    });
    try {
      final data = await _api.get('/equipments?clientId=$_clientId') as List<dynamic>;
      setState(() {
        _equipments = data.cast<Map<String, dynamic>>();
        if (_reportEquipmentId != null &&
            !_equipments.any((item) => item['id'] == _reportEquipmentId)) {
          _reportEquipmentId = null;
        }
      });
    } catch (error) {
      setState(() => _equipmentsError = error.toString());
    } finally {
      setState(() => _equipmentsLoading = false);
    }
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
      } else {
        _reportSections = [];
        _reportAnswers = {};
        _reportPhotos = [];
        _reportStatus = 'rascunho';
        _reportDirty = false;
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
      if (!mounted) return;
      DefaultTabController.of(context)?.animateTo(1);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
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
    _reportEquipmentId = report['equipment_id'] as int?;
    _reportDirty = false;
    _reportAutosaveTimer?.cancel();
    _reportAutosaveTimer = null;
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
      'start_date': parseDateBrToIso(_startDate.text),
      'due_date': parseDateBrToIso(_dueDate.text),
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
      if (!mounted) return;
      _tabController.animateTo(1);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }
  Map<String, dynamic> _normalizeReportAnswers() {
    final normalized = Map<String, dynamic>.from(_reportAnswers);
    for (final section in _reportSections) {
      final fields = section['fields'] as List<dynamic>? ?? [];
      for (final field in fields) {
        if (field is! Map<String, dynamic>) continue;
        final type = field['type']?.toString();
        if (type != 'date') continue;
        final fieldId = field['id']?.toString();
        if (fieldId == null || fieldId.isEmpty) continue;
        final raw = normalized[fieldId];
        if (raw == null || raw.toString().isEmpty) continue;
        normalized[fieldId] = parseDateBrToIso(raw.toString());
      }
    }
    return normalized;
  }
  Future<void> _saveReport({bool silent = false, bool skipReload = false}) async {
    if (_activeReportId == null) {
      setState(() => _reportMessage = 'Salve a tarefa para gerar o Relatório.');
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
        'answers': _normalizeReportAnswers(),
        'photos': _reportPhotos,
      },
    };

    try {
      await _api.put('/reports/$_activeReportId', payload);
      _reportDirty = false;
      if (silent && skipReload) {
        return;
      }
      setState(() => _reportMessage = 'Relatório salvo com sucesso.');
      await _loadReports(_taskTypeId);
    } catch (error) {
      if (silent) return;
      setState(() => _reportMessage = error.toString());
    }
  }

  void _markReportDirty({Duration delay = const Duration(milliseconds: 1500)}) {
    _reportDirty = true;
    _reportAutosaveTimer?.cancel();
    if (_activeReportId == null) return;
    final seq = ++_reportAutosaveSeq;
    _reportAutosaveTimer = Timer(delay, () {
      _runReportAutosave(seq);
    });
  }

  Future<void> _runReportAutosave(int seq) async {
    if (_activeReportId == null || !_reportDirty) return;
    if (_reportAutosaving) {
      _markReportDirty(delay: const Duration(milliseconds: 800));
      return;
    }
    _reportAutosaving = true;
    try {
      await _saveReport(silent: true, skipReload: true);
      if (seq == _reportAutosaveSeq) {
        _reportDirty = false;
      }
    } catch (_) {
      // Auto-save não deve bloquear o usuário.
    } finally {
      _reportAutosaving = false;
    }
  }

  Future<void> _flushReportAutosave() async {
    if (_activeReportId == null || !_reportDirty) return;
    _reportAutosaveTimer?.cancel();
    await _runReportAutosave(_reportAutosaveSeq);
  }

  Future<void> _handleActiveReportChange(int? value) async {
    // Antes de trocar de Relatório, tentamos salvar o atual em segundo plano.
    await _flushReportAutosave();
    final report = _reports.firstWhere(
      (item) => item['id'] == value,
      orElse: () => <String, dynamic>{},
    );
    if (!mounted) return;
    setState(() {
      _activeReportId = value;
      _applyReportData(report, _taskTypeId);
    });
  }

  Future<void> _updateReportEquipment(int? equipmentId) async {
    if (_activeReportId == null) return;
    try {
      await _api.put('/reports/$_activeReportId', {'equipment_id': equipmentId});
      final equipmentName = _equipments
          .firstWhere(
            (item) => item['id'] == equipmentId,
            orElse: () => <String, dynamic>{},
          )['name']
          ?.toString();
      setState(() {
        _reportEquipmentId = equipmentId;
        final reportIndex = _reports.indexWhere((item) => item['id'] == _activeReportId);
        if (reportIndex != -1) {
          _reports[reportIndex] = {
            ..._reports[reportIndex],
            'equipment_id': equipmentId,
            'equipment_name': equipmentName,
          };
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _createReport() async {
    if (_taskId == null) return;
    if (_clientId == null) {
      setState(() => _reportMessage = 'Selecione um cliente antes de criar o Relatório.');
      return;
    }
    final template = _selectedTemplate;
    if (template == null) {
      setState(() => _reportMessage = 'Este tipo de tarefa não possui modelo de Relatório.');
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Relatório'),
        content: const Text('Deseja excluir este Relatório?'),
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
    final option = await showModalBottomSheet<_PhotoSourceOption>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto agora'),
              onTap: () => Navigator.pop(context, _PhotoSourceOption.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(context, _PhotoSourceOption.gallery),
            ),
          ],
        ),
      ),
    );
    if (option == null) return;

    final files = <XFile>[];
    if (option == _PhotoSourceOption.camera) {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: _photoJpegQuality,
        maxWidth: _maxPhotoDimension.toDouble(),
        maxHeight: _maxPhotoDimension.toDouble(),
      );
      if (file != null) files.add(file);
    } else {
      final galleryFiles = await _picker.pickMultiImage(
        imageQuality: _photoJpegQuality,
        maxWidth: _maxPhotoDimension.toDouble(),
        maxHeight: _maxPhotoDimension.toDouble(),
      );
      files.addAll(galleryFiles);
    }

    if (files.isEmpty) return;
    await _appendPhotos(files);
  }

  Future<void> _appendPhotos(List<XFile> files) async {
    final newPhotos = <Map<String, dynamic>>[];
    for (final file in files) {
      final bytes = await File(file.path).readAsBytes();
      final optimizedBytes = _optimizeImageBytes(bytes);
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(optimizedBytes)}';
      newPhotos.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'name': _asJpegName(path.basename(file.path)),
        'dataUrl': dataUrl,
      });
    }
    if (!mounted) return;
    setState(() => _reportPhotos = [..._reportPhotos, ...newPhotos]);
    _markReportDirty();
  }

  String _asJpegName(String original) {
    final ext = path.extension(original);
    if (ext.isEmpty) return '$original.jpg';
    return original.replaceRange(original.length - ext.length, original.length, '.jpg');
  }

  Uint8List _optimizeImageBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final maxDimension = decoded.width > decoded.height ? decoded.width : decoded.height;
    img.Image processed = decoded;

    if (maxDimension > _maxPhotoDimension) {
      final scale = _maxPhotoDimension / maxDimension;
      final targetWidth = (decoded.width * scale).round();
      final targetHeight = (decoded.height * scale).round();
      processed = img.copyResize(
        decoded,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    final encoded = img.encodeJpg(processed, quality: _photoJpegQuality);
    return Uint8List.fromList(encoded);
  }

    void _removePhoto(String photoId) {
    setState(() => _reportPhotos.removeWhere((photo) => photo['id'] == photoId));
    _markReportDirty();
  }

  Future<String?> _getTaskPublicLink() async {
    if (_taskId == null) return null;
    await _flushReportAutosave();
    if (!mounted) return null;
    final response = await _api.post('/tasks/$_taskId/public-link', {});
    final url = response is Map<String, dynamic> ? response['url']?.toString() ?? '' : '';
    if (url.isEmpty) {
      throw Exception('Link publico nao retornado pela API');
    }
    return url;
  }

  Future<void> _shareTaskPublicLink() async {
    if (_taskId == null) return;
    try {
      final url = await _getTaskPublicLink();
      if (url == null) return;
      await Share.share('Relatorio da tarefa #$_taskId: $url');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _openTaskPublicPage() async {
    if (_taskId == null) return;
    try {
      final url = await _getTaskPublicLink();
      if (url == null) return;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
      controller.text = formatDateFromDate(selected);
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
          onChanged: (value) async {
            setState(() {
              _clientId = value;
              _reportEquipmentId = null;
            });
            await _loadClientEquipments();
            if (_taskId != null) {
              await _loadReports(_taskTypeId);
              await _loadBudgets(_reports);
            }
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
                      child: Text(user['name']?.toString() ?? 'usuário'),
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
          value: formatDateInput(_startDate.text),
          onTap: () => _pickDate(_startDate),
        ),
        const SizedBox(height: 8),
        AppDateField(
          key: ValueKey(_dueDate.text),
          label: 'Fim',
          value: formatDateInput(_dueDate.text),
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
              child: Text('Salve a tarefa para habilitar o Relatório.'),
            ),
          ),
        if (_taskId != null && _selectedTemplate == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Este tipo de tarefa não possui modelo de Relatório.'),
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
                    onChanged: (value) => _handleActiveReportChange(value),
                  ),
                  const SizedBox(height: 8),
                  _buildEquipmentField(),
                  const SizedBox(height: 8),
                  AppDropdownField<String>(
                    label: 'Status',
                    value: _reportStatus,
                    items: const [
                      DropdownMenuItem(value: 'rascunho', child: Text('Rascunho')),
                      DropdownMenuItem(value: 'enviado', child: Text('Enviado')),
                      DropdownMenuItem(value: 'finalizado', child: Text('Finalizado')),
                    ],
                    onChanged: (value) {
                      setState(() => _reportStatus = value ?? 'rascunho');
                      _markReportDirty();
                    },
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
                      ElevatedButton(onPressed: _saveReport, child: const Text('Salvar Relatório')),
                      OutlinedButton(onPressed: _sendReportEmail, child: const Text('Enviar e-mail')),
                      OutlinedButton(
                        onPressed: _shareTaskPublicLink,
                        child: const Text('Compartilhar link'),
                      ),
                      OutlinedButton(
                        onPressed: _openTaskPublicPage,
                        child: const Text('Abrir PDF'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEquipmentField() {
    final shouldDisable = _clientId == null || _equipmentsLoading || _equipmentsError != null;
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('Sem equipamento')),
      ..._equipments.map(
        (equipment) => DropdownMenuItem<int?>(
          value: equipment['id'] as int?,
          child: Text(equipment['name']?.toString() ?? 'Equipamento'),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: shouldDisable ? 0.55 : 1,
          child: AbsorbPointer(
            absorbing: shouldDisable || _activeReportId == null,
            child: AppDropdownField<int?>(
              label: 'Equipamento',
              value: _reportEquipmentId,
              items: items,
              onChanged: (value) => _updateReportEquipment(value),
            ),
          ),
        ),
        if (_clientId == null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Selecione um cliente primeiro.'),
          ),
        if (_activeReportId == null && _clientId != null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Selecione um relatório para vincular o equipamento.'),
          ),
        if (_equipmentsLoading)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: LinearProgressIndicator(),
          ),
        if (_clientId != null && !_equipmentsLoading && _equipmentsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Expanded(child: Text('Erro ao carregar equipamentos.')),
                TextButton(
                  onPressed: _loadClientEquipments,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        if (_clientId != null &&
            !_equipmentsLoading &&
            _equipmentsError == null &&
            _equipments.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Nenhum equipamento encontrado para este cliente.'),
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
            onChanged: (val) {
              setState(() => _reportAnswers[fieldId] = val);
              _markReportDirty();
            },
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
            onChanged: (val) {
              setState(() => _reportAnswers[fieldId] = val);
              _markReportDirty();
            },
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
              DropdownMenuItem(value: 'nao', child: Text('não')),
            ],
            onChanged: (val) {
              setState(() => _reportAnswers[fieldId] = val);
              _markReportDirty();
            },
          ),
        );
      }
      if (type == 'checkbox') {
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: value == true,
          onChanged: (val) {
            setState(() => _reportAnswers[fieldId] = val);
            _markReportDirty();
          },
        );
      }
      if (type == 'date') {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppDateField(
            key: ValueKey('date-${_activeReportId ?? "new"}-$fieldId-${value ?? ""}'),
            label: label,
            value: formatDateInput(value?.toString()),
            onTap: () async {
              final now = DateTime.now();
              final selected = await showDatePicker(
                context: context,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 5),
                initialDate: now,
              );
              if (selected == null) return;
              final formatted = formatDateFromDate(selected);
              setState(() => _reportAnswers[fieldId] = formatted);
              _markReportDirty();
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
          onChanged: (val) {
            setState(() => _reportAnswers[fieldId] = val);
            _markReportDirty();
          },
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
              child: Text('Salve a tarefa para liberar os Orçamentos.'),
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
                        Text('orçamento #${budget['id']}', style: Theme.of(context).textTheme.titleSmall),
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
            'label': 'orçamento #${budget['id']}',
          }),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_taskId == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Salve a tarefa para configurar Assinaturas.'),
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
              DropdownMenuItem(value: 'both', child: Text('Cliente e Técnico')),
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
            if (_signatureMode == 'client' || _signatureMode == 'both')
              if (_signatureClient.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _signatureClient = ''),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remover assinatura'),
                  ),
                ),
            const SizedBox(height: 12),
            if (_signatureMode == 'tech' || _signatureMode == 'both')
              SignaturePadField(
                label: 'Assinatura do técnico*',
                value: _signatureTech,
                onChanged: (value) => setState(() => _signatureTech = value),
              ),
            if (_signatureMode == 'tech' || _signatureMode == 'both')
              if (_signatureTech.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _signatureTech = ''),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remover assinatura'),
                  ),
                ),
          ],
          if (_signatureScope == 'all_pages' && _signatureMode != 'none') ...[
            ...signaturePageItems.map((page) {
              final key = page['key'] as String;
              final label = page['label'] as String;
              final pageSignatures = _signaturePages[key] as Map<String, dynamic>? ?? {};
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
                          value: pageSignatures['client']?.toString() ?? '',
                          onChanged: (value) => _updateSignaturePage(key, 'client', value),
                        ),
                      if (_signatureMode == 'client' || _signatureMode == 'both')
                        if ((pageSignatures['client']?.toString() ?? '').isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _updateSignaturePage(key, 'client', ''),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remover assinatura'),
                            ),
                          ),
                      const SizedBox(height: 12),
                      if (_signatureMode == 'tech' || _signatureMode == 'both')
                        SignaturePadField(
                          label: 'Assinatura do técnico*',
                          value: pageSignatures['tech']?.toString() ?? '',
                          onChanged: (value) => _updateSignaturePage(key, 'tech', value),
                        ),
                      if (_signatureMode == 'tech' || _signatureMode == 'both')
                        if ((pageSignatures['tech']?.toString() ?? '').isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _updateSignaturePage(key, 'tech', ''),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remover assinatura'),
                            ),
                          ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _saveTask, child: const Text('Salvar Assinaturas')),
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

    return Scaffold(
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Detalhes'),
            Tab(text: 'Relatório'),
            Tab(text: 'Orçamentos'),
            Tab(text: 'Assinaturas'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(context).brightness == Brightness.dark
                ? const [Color(0xFF0F1B2A), Color(0xFF0B1320)]
                : const [Color(0xFFF6FAFD), Color(0xFFEAF2F8)],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildDetailsTab(),
            _buildReportTab(),
            _buildBudgetsTab(),
            _buildSignatureTab(),
          ],
        ),
      ),
    );
  }
}







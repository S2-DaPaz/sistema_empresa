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

import '../core/errors/app_exception.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/permissions.dart';
import '../theme/app_tokens.dart';
import '../utils/contact_utils.dart';
import '../utils/formatters.dart';
import '../utils/report_text.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/avatar_initials.dart';
import '../widgets/budget_form.dart';
import '../widgets/empty_state.dart';
import '../widgets/form_fields.dart';
import '../widgets/loading_view.dart';
import '../widgets/section_header.dart';
import '../widgets/signature_pad.dart';
import '../widgets/status_chip.dart';
import 'task_detail_options.dart';

enum _PhotoSourceOption { camera, gallery }

const int _maxPhotoDimension = 1024;
const int _photoJpegQuality = 60;

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, this.taskId});

  final int? taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen>
    with TickerProviderStateMixin {
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _setStateIfMounted(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _openReportTab() {
    if (!mounted) return;
    if (_tabController.length <= 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_tabController.index != 1) {
        _tabController.animateTo(1);
      }
    });
  }

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
    _setStateIfMounted(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.get('/clients'),
        AuthService.instance.hasPermission(Permissions.viewUsers)
            ? _api.get('/users')
            : Future.value(<dynamic>[]),
        _api.get('/task-types'),
        _api.get('/report-templates'),
        _api.get('/products'),
        if (_taskId != null) _api.get('/tasks/$_taskId'),
      ]);

      _clients = ((results[0] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      _users = ((results[1] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      _types = ((results[2] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      _templates = ((results[3] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      _products = ((results[4] as List?) ?? const [])
          .cast<Map<String, dynamic>>();

      if (_taskId != null) {
        const taskIndex = 5;
        final task = Map<String, dynamic>.from(
          results[taskIndex] as Map? ?? const {},
        );
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
      }
    } catch (error) {
      _setStateIfMounted(() {
        _error = error.toString();
        _loading = false;
      });
      return;
    }

    _setStateIfMounted(() => _loading = false);
    unawaited(_loadDeferredTaskData());
  }

  Future<void> _loadDeferredTaskData() async {
    try {
      if (_taskId != null) {
        await _loadReports(_taskTypeId);
        await _loadBudgets(_reports);
      }
      await _loadClientEquipments();
    } catch (_) {
      _showMessage(
        'Não foi possível atualizar todos os dados complementares da tarefa.',
      );
    }
  }

  Future<void> _loadClientEquipments() async {
    if (_clientId == null) {
      _setStateIfMounted(() {
        _equipments = [];
        _equipmentsError = null;
        _equipmentsLoading = false;
        _reportEquipmentId = null;
      });
      return;
    }
    _setStateIfMounted(() {
      _equipmentsLoading = true;
      _equipmentsError = null;
    });
    try {
      final data =
          await _api.get('/equipments?clientId=$_clientId') as List<dynamic>;
      _setStateIfMounted(() {
        _equipments = data.cast<Map<String, dynamic>>();
        if (_reportEquipmentId != null &&
            !_equipments.any((item) => item['id'] == _reportEquipmentId)) {
          _reportEquipmentId = null;
        }
      });
    } catch (error) {
      _setStateIfMounted(() => _equipmentsError = error.toString());
    } finally {
      _setStateIfMounted(() => _equipmentsLoading = false);
    }
  }

  Future<void> _loadReports(int? taskTypeId, {int? preferredReportId}) async {
    if (_taskId == null) return;
    final data = await _api.get('/reports?taskId=$_taskId') as List<dynamic>;
    final nextReports = data.cast<Map<String, dynamic>>();
    final preservedReport = nextReports.firstWhere(
      (item) => item['id'] == (preferredReportId ?? _activeReportId),
      orElse: () => <String, dynamic>{},
    );
    final defaultReport = preservedReport.isNotEmpty
        ? preservedReport
        : nextReports.firstWhere(
            (item) => item['equipment_id'] == null,
            orElse: () => nextReports.isNotEmpty
                ? nextReports.first
                : <String, dynamic>{},
          );
    final nextActiveId = defaultReport['id'] as int?;
    _setStateIfMounted(() {
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
    final byTaskRaw = await _api.get('/budgets?taskId=$_taskId');
    final byTask = byTaskRaw is List ? byTaskRaw : <dynamic>[];
    final reportIds =
        reportList.map((report) => report['id']).whereType<int>().toList();
    final byReports = await Future.wait(
      reportIds.map((id) => _api.get('/budgets?reportId=$id')),
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

    _setStateIfMounted(() => _budgets = merged.values.toList());
  }

  Future<void> _editBudget(Map<String, dynamic> budget) async {
    Map<String, dynamic> initialBudget = budget;
    if (budget['id'] != null && budget['items'] == null) {
      try {
        final detail = await _api.get('/budgets/${budget['id']}');
        if (detail is Map<String, dynamic>) {
          initialBudget = Map<String, dynamic>.from(detail);
        }
      } catch (_) {
        _showMessage('Não foi possível carregar os itens deste orçamento.');
      }
    }
    if (!mounted) return;

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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
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
                  initialBudget: initialBudget,
                  clients: _clients,
                  products: _products,
                  clientId: _clientId ?? initialBudget['client_id'] as int?,
                  taskId: initialBudget['task_id'] as int? ?? _taskId,
                  reportId: initialBudget['report_id'] as int?,
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.delete('/budgets/$id');
      await _loadBudgets(_reports);
      _openReportTab();
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  void _applyReportData(Map<String, dynamic> report, int? taskTypeId) {
    final content = report['content'] as Map<String, dynamic>? ?? {};
    var sections = (content['sections'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

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
      sections = (structure['sections'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
    }

    _reportSections = sections;
    _reportAnswers = content['answers'] as Map<String, dynamic>? ?? {};
    _reportPhotos = (content['photos'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
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
    _setStateIfMounted(() => _error = null);
    final previousActiveReportId = _activeReportId;
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

    final isEditing = _taskId != null;

    try {
      if (_taskId == null) {
        final saved =
            await _api.post('/tasks', payload) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _taskId = saved['id'] as int?;
        });
        _openReportTab();
      } else {
        await _api.put('/tasks/$_taskId', payload);
        _openReportTab();
      }
    } catch (error) {
      _showMessage(error.toString());
      return;
    }

    Object? refreshError;
    try {
      await _loadClientEquipments();
      await _loadReports(
        _taskTypeId,
        preferredReportId: previousActiveReportId,
      );
      await _loadBudgets(_reports);
    } catch (error) {
      refreshError = error;
    }

    _openReportTab();

    if (refreshError != null) {
      _showMessage(
        'Tarefa salva, mas houve uma falha ao atualizar a aba de relatório: $refreshError',
      );
      return;
    }

    _showMessage(
      isEditing
          ? 'Tarefa atualizada com sucesso.'
          : 'Tarefa salva com sucesso.',
    );
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

  Future<void> _saveReport(
      {bool silent = false, bool skipReload = false}) async {
    if (_activeReportId == null) {
      _setStateIfMounted(
        () => _reportMessage = 'Salve a tarefa para gerar o Relatório.',
      );
      return;
    }
    final previousActiveReportId = _activeReportId;

    final templateId =
        _activeReport?['template_id'] ?? _selectedTemplate?['id'];
    final payload = {
      'title': _activeReport?['title'] ?? _title.text,
      'task_id': _taskId,
      'client_id': _clientId,
      'template_id': templateId,
      'equipment_id': _activeReport?['equipment_id'],
      'status': _reportStatus,
      'content': {
        'sections': _reportSections,
        'layout': _activeReport?['content']?['layout'] ??
            _selectedTemplate?['structure']?['layout'],
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
      _setStateIfMounted(
        () => _reportMessage = 'Relatório salvo com sucesso.',
      );
      await _loadReports(
        _taskTypeId,
        preferredReportId: previousActiveReportId,
      );
    } catch (error) {
      if (silent) return;
      _setStateIfMounted(() => _reportMessage = error.toString());
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
      await _api
          .put('/reports/$_activeReportId', {'equipment_id': equipmentId});
      final equipmentName = _equipments
          .firstWhere(
            (item) => item['id'] == equipmentId,
            orElse: () => <String, dynamic>{},
          )['name']
          ?.toString();
      _setStateIfMounted(() {
        _reportEquipmentId = equipmentId;
        final reportIndex =
            _reports.indexWhere((item) => item['id'] == _activeReportId);
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
      _setStateIfMounted(() {
        _reportMessage = 'Selecione um cliente antes de criar o Relatório.';
      });
      return;
    }
    final template = _selectedTemplate;
    if (template == null) {
      _setStateIfMounted(() {
        _reportMessage = 'Este tipo de tarefa não possui modelo de Relatório.';
      });
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
        'layout': template['structure']?['layout'] ??
            {'sectionColumns': 1, 'fieldColumns': 1},
        'answers': {},
        'photos': [],
      },
    };

    try {
      final created =
          await _api.post('/reports', payload) as Map<String, dynamic>;
      await _loadReports(_taskTypeId);
      _setStateIfMounted(() {
        _activeReportId = created['id'] as int?;
        _reportMessage = 'Relatório criado com sucesso.';
      });
    } catch (error) {
      _setStateIfMounted(() => _reportMessage = error.toString());
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir')),
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
    return original.replaceRange(
        original.length - ext.length, original.length, '.jpg');
  }

  Uint8List _optimizeImageBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final maxDimension =
        decoded.width > decoded.height ? decoded.width : decoded.height;
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
    setState(
        () => _reportPhotos.removeWhere((photo) => photo['id'] == photoId));
    _markReportDirty();
  }

  Future<String?> _getTaskPublicLink() async {
    if (_taskId == null) return null;
    await _flushReportAutosave();
    if (!mounted) return null;
    final response = await _api.post('/tasks/$_taskId/public-link', {});
    final url = response is Map<String, dynamic>
        ? response['url']?.toString() ?? ''
        : '';
    if (url.isEmpty) {
      throw AppException(
        message: 'Não foi possível gerar o link público agora.',
        category: 'unexpected_error',
        code: 'public_link_missing',
        technicalMessage: 'Public link response without url.',
      );
    }
    return url;
  }

  Future<void> _shareTaskPublicLink() async {
    if (_taskId == null) return;
    try {
      final url = await _getTaskPublicLink();
      if (url == null) return;
      await Share.share('Relatório da tarefa #$_taskId: $url');
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
    final emailMatch =
        RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false)
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
    final page = Map<String, dynamic>.from(
        _signaturePages[key] as Map<String, dynamic>? ?? {});
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

  Map<String, dynamic>? get _selectedClient {
    for (final client in _clients) {
      if (client['id'] == _clientId) {
        return client;
      }
    }
    return null;
  }

  List<Map<String, String>> _progressItems() {
    final hasTask = _taskId != null;
    final hasReport = _reports.isNotEmpty;
    final hasBudget = _budgets.isNotEmpty;
    final hasSignature = _signatureMode != 'none' &&
        ((_signatureClient.isNotEmpty || _signatureTech.isNotEmpty) ||
            _signaturePages.isNotEmpty);

    return [
      {'title': 'Tarefa criada', 'status': hasTask ? 'Concluído' : 'Pendente'},
      {
        'title': 'Relatório iniciado',
        'status': hasReport ? 'Concluído' : 'Pendente'
      },
      {
        'title': 'Orçamento vinculado',
        'status': hasBudget ? 'Concluído' : 'Pendente'
      },
      {
        'title': 'Assinaturas',
        'status': hasSignature ? 'Concluído' : 'Pendente'
      },
    ];
  }

  Future<void> _launchContact(String scheme, String value) async {
    if (value.isEmpty) return;
    await launchUrl(
      Uri.parse(scheme + value),
      mode: LaunchMode.externalApplication,
    );
  }

  Widget _buildDetailsTab() {
    final client = _selectedClient;
    final clientName = client?['name']?.toString() ?? 'Sem cliente';
    final clientEmail = extractEmail(client?['contact']?.toString());
    final clientPhone = extractPhone(client?['contact']?.toString());
    final clientAddress = client?['address']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusChip(
                      label: _taskId == null
                          ? 'Nova tarefa'
                          : '#${_taskId ?? '--'}',
                      compact: true,
                    ),
                    StatusChip(
                      label: _status == 'em_andamento'
                          ? 'Em andamento'
                          : _status == 'concluida'
                              ? 'Concluída'
                              : 'Aberta',
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _title.text.isEmpty ? 'Nova tarefa' : _title.text,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${formatDateInput(_startDate.text).isEmpty ? 'Sem início' : formatDateInput(_startDate.text)} • ${formatDateInput(_dueDate.text).isEmpty ? 'Sem prazo' : formatDateInput(_dueDate.text)}',
                      ),
                    ),
                  ],
                ),
                if (clientAddress.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(clientAddress)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AvatarInitials(name: clientName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(clientName,
                              style: Theme.of(context).textTheme.titleMedium),
                          if (clientEmail.isNotEmpty)
                            Text(clientEmail,
                                style: Theme.of(context).textTheme.bodySmall),
                          if (clientPhone.isNotEmpty)
                            Text(clientPhone,
                                style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: clientPhone.isEmpty
                          ? null
                          : () => _launchContact(
                                'tel:',
                                clientPhone.replaceAll(RegExp(r'[^0-9]'), ''),
                              ),
                      child: const Text('Ligar'),
                    ),
                    OutlinedButton(
                      onPressed: clientEmail.isEmpty
                          ? null
                          : () => _launchContact('mailto:', clientEmail),
                      child: const Text('E-mail'),
                    ),
                    OutlinedButton(
                      onPressed: clientPhone.isEmpty
                          ? null
                          : () => _launchContact(
                                'https://wa.me/',
                                clientPhone.replaceAll(RegExp(r'[^0-9]'), ''),
                              ),
                      child: const Text('WhatsApp'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SectionHeader(
          title: 'Progresso',
          subtitle: 'Etapas ligadas à execução da tarefa',
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: _progressItems()
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(
                              item['status'] == 'Concluído'
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: item['status'] == 'Concluído'
                                  ? AppColors.success
                                  : AppColors.muted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(item['title'] ?? 'Etapa')),
                            StatusChip(
                              label: item['status'] ?? 'Pendente',
                              compact: true,
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SectionHeader(
          title: 'Editar tarefa',
          subtitle: 'Ajuste as informações operacionais',
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AppTextField(label: 'Título', controller: _title),
                const SizedBox(height: 8),
                AppDropdownField<String>(
                  label: 'Status',
                  value: _status,
                  items: TaskDetailOptions.taskStatusItems,
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'aberta'),
                ),
                const SizedBox(height: 8),
                AppDropdownField<String>(
                  label: 'Prioridade',
                  value: _priority,
                  items: TaskDetailOptions.taskPriorityItems,
                  onChanged: (value) =>
                      setState(() => _priority = value ?? 'media'),
                ),
                const SizedBox(height: 8),
                AppDropdownField<int>(
                  label: 'Cliente',
                  value: _clientId,
                  items: _clients
                      .map((client) => DropdownMenuItem<int>(
                            value: client['id'] as int?,
                            child:
                                Text(client['name']?.toString() ?? 'Cliente'),
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
                    label: 'Responsável',
                    value: _userId,
                    items: _users
                        .map((user) => DropdownMenuItem<int>(
                              value: user['id'] as int?,
                              child:
                                  Text(user['name']?.toString() ?? 'Usuário'),
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
                Row(
                  children: [
                    Expanded(
                      child: AppDateField(
                        key: ValueKey(_startDate.text),
                        label: 'Data inicial',
                        value: formatDateInput(_startDate.text),
                        onTap: () => _pickDate(_startDate),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppDateField(
                        key: ValueKey(_dueDate.text),
                        label: 'Prazo',
                        value: formatDateInput(_dueDate.text),
                        onTap: () => _pickDate(_dueDate),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AppTextField(
                    label: 'Descrição', controller: _description, maxLines: 4),
              ],
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child:
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ),
        const SizedBox(height: 12),
        if (_taskId == null &&
            _title.text.isEmpty &&
            _clientId == null &&
            _description.text.isEmpty)
          const EmptyState(
            title: 'Preencha os dados principais',
            message:
                'Assim que salvar a tarefa você libera relatório, orçamento e assinaturas.',
            icon: Icons.assignment_outlined,
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _taskId != null && _status != 'em_andamento'
                    ? () {
                        setState(() => _status = 'em_andamento');
                        _saveTask();
                      }
                    : null,
                child: const Text('Iniciar trabalho'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _saveTask,
                child: Text(
                    _taskId == null ? 'Salvar tarefa' : 'Atualizar tarefa'),
              ),
            ),
          ],
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
              child:
                  Text('Este tipo de tarefa não possui modelo de Relatório.'),
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
                      Text('Relatórios da tarefa',
                          style: Theme.of(context).textTheme.titleSmall),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                              onPressed: _createReport,
                              child: const Text('Adicionar')),
                          OutlinedButton(
                              onPressed: _deleteReport,
                              child: const Text('Excluir')),
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
                    items: TaskDetailOptions.reportStatusItems,
                    onChanged: (value) {
                      setState(() => _reportStatus = value ?? 'rascunho');
                      _markReportDirty();
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Fotos',
                          style: Theme.of(context).textTheme.titleSmall),
                      OutlinedButton(
                          onPressed: _addPhotos,
                          child: const Text('Adicionar')),
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
                                      base64Decode(photo['dataUrl']
                                          .toString()
                                          .split(',')
                                          .last),
                                      height: 90,
                                      fit: BoxFit.cover,
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          _removePhoto(photo['id'].toString()),
                                      child: const Text('Remover'),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 12),
                  Text('Formulario',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (_reportSections.isEmpty)
                    const Text('Este modelo ainda não possui campos.'),
                  ..._reportSections.map((section) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(section['title']?.toString() ?? 'Seção',
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 8),
                              ..._buildReportFields(section),
                            ],
                          ),
                        ),
                      )),
                  if (_reportMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_reportMessage!,
                          style: const TextStyle(color: Colors.blueGrey)),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                          onPressed: _saveReport,
                          child: const Text('Salvar Relatório')),
                      OutlinedButton(
                          onPressed: _sendReportEmail,
                          child: const Text('Enviar e-mail')),
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
    final shouldDisable =
        _clientId == null || _equipmentsLoading || _equipmentsError != null;
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
        if (_clientId != null &&
            !_equipmentsLoading &&
            _equipmentsError != null)
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
    final fields = (section['fields'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
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
            key: ValueKey(
                'date-${_activeReportId ?? "new"}-$fieldId-${value ?? ""}'),
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
                        Text('orçamento #${budget['id']}',
                            style: Theme.of(context).textTheme.titleSmall),
                        Row(
                          children: [
                            Chip(
                                label: Text(budget['status']?.toString() ??
                                    'rascunho')),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editBudget(budget);
                                } else if (value == 'delete') {
                                  _deleteBudget(budget['id'] as int);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                    value: 'edit', child: Text('Editar')),
                                PopupMenuItem(
                                    value: 'delete', child: Text('Remover')),
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
                                Expanded(
                                    child: Text(
                                        item['description']?.toString() ??
                                            'Item')),
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
            items: TaskDetailOptions.signatureModeItems,
            onChanged: (value) =>
                setState(() => _signatureMode = value ?? 'none'),
          ),
          const SizedBox(height: 8),
          AppDropdownField<String>(
            label: 'Aplicação',
            value: _signatureScope,
            items: TaskDetailOptions.signatureScopeItems,
            onChanged: (value) =>
                setState(() => _signatureScope = value ?? 'last_page'),
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
              final pageSignatures =
                  _signaturePages[key] as Map<String, dynamic>? ?? {};
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      if (_signatureMode == 'client' ||
                          _signatureMode == 'both')
                        SignaturePadField(
                          label: 'Assinatura do cliente*',
                          value: pageSignatures['client']?.toString() ?? '',
                          onChanged: (value) =>
                              _updateSignaturePage(key, 'client', value),
                        ),
                      if (_signatureMode == 'client' ||
                          _signatureMode == 'both')
                        if ((pageSignatures['client']?.toString() ?? '')
                            .isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () =>
                                  _updateSignaturePage(key, 'client', ''),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remover assinatura'),
                            ),
                          ),
                      const SizedBox(height: 12),
                      if (_signatureMode == 'tech' || _signatureMode == 'both')
                        SignaturePadField(
                          label: 'Assinatura do técnico*',
                          value: pageSignatures['tech']?.toString() ?? '',
                          onChanged: (value) =>
                              _updateSignaturePage(key, 'tech', value),
                        ),
                      if (_signatureMode == 'tech' || _signatureMode == 'both')
                        if ((pageSignatures['tech']?.toString() ?? '')
                            .isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () =>
                                  _updateSignaturePage(key, 'tech', ''),
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
          ElevatedButton(
            onPressed: _saveTask,
            child: const Text('Salvar assinaturas'),
          ),
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
        title: Text(
          _taskId == null ? 'Nova tarefa' : 'Detalhes da tarefa',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

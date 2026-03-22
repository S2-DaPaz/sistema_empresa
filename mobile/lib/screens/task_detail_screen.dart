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
import 'task_detail/budgets_tab.dart';
import 'task_detail/details_tab.dart';
import 'task_detail/report_tab.dart';
import 'task_detail/signatures_tab.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/offline_task_draft_service.dart';
import '../services/permissions.dart';
import '../utils/formatters.dart';
import '../utils/report_text.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_ui.dart';
import '../widgets/budget_form.dart';
import '../widgets/brand_logo.dart';
import '../widgets/form_fields.dart';
import '../widgets/loading_view.dart';

enum _PhotoSourceOption { camera, gallery }

const int _maxPhotoDimension = 1024;
const int _photoJpegQuality = 60;

/// Tela de detalhe da tarefa.
///
/// Além dos campos principais da tarefa, ela também coordena relatórios,
/// orçamentos, assinaturas e equipamentos relacionados. Concentramos esse
/// fluxo aqui porque as operações compartilham o mesmo contexto de tarefa e
/// exigem sincronização de estado após cada alteração.
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
  final TaskOfflineDraftStore _offlineDraftStore = TaskOfflineDraftStore.instance;
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
  late String _offlineDraftId;
  Timer? _offlineDraftTimer;
  bool _offlineSyncPending = false;
  bool _loadingFromOfflineDraft = false;
  bool _syncingOfflineDraft = false;
  bool _taskDraftDirty = false;
  bool _reportDraftDirty = false;
  bool _trackingPaused = false;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
    _offlineDraftId = TaskOfflineDraftStore.buildDraftId(_taskId);
    _tabController = TabController(length: 4, vsync: this);
    _title.addListener(_handleTaskFieldEdited);
    _description.addListener(_handleTaskFieldEdited);
    _startDate.addListener(_handleTaskFieldEdited);
    _dueDate.addListener(_handleTaskFieldEdited);
    _loadAll();
  }

  @override
  void dispose() {
    _reportAutosaveTimer?.cancel();
    _offlineDraftTimer?.cancel();
    _tabController.dispose();
    _title.removeListener(_handleTaskFieldEdited);
    _title.dispose();
    _description.removeListener(_handleTaskFieldEdited);
    _description.dispose();
    _startDate.removeListener(_handleTaskFieldEdited);
    _startDate.dispose();
    _dueDate.removeListener(_handleTaskFieldEdited);
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

  dynamic _cloneJson(dynamic value) {
    if (value == null) {
      return null;
    }
    return jsonDecode(jsonEncode(value));
  }

  void _handleTaskFieldEdited() {
    _markTaskDraftDirty();
  }

  void _markTaskDraftDirty() {
    if (_trackingPaused) return;
    _taskDraftDirty = true;
    _scheduleOfflineDraftSave();
  }

  void _markTaskDraftSynced() {
    _taskDraftDirty = false;
  }

  void _markReportDraftSynced() {
    _reportDraftDirty = false;
  }

  void _markReportDraftDirty({
    Duration localDelay = const Duration(milliseconds: 500),
    Duration autosaveDelay = const Duration(milliseconds: 1500),
  }) {
    if (_trackingPaused) return;
    _reportDraftDirty = true;
    _scheduleOfflineDraftSave(delay: localDelay);
    _markReportDirty(delay: autosaveDelay);
  }

  void _syncActiveReportIntoCollection() {
    if (_activeReportId == null) {
      return;
    }

    final templateId = _activeReport?['template_id'] ?? _selectedTemplate?['id'];
    final reportSnapshot = {
      ..._safeMap(_activeReport),
      'id': _activeReportId,
      'title': _activeReport?['title']?.toString() ?? _title.text,
      'task_id': _taskId,
      'client_id': _clientId,
      'template_id': templateId,
      'equipment_id': _reportEquipmentId,
      'status': _reportStatus,
      'content': {
        'sections': _cloneJson(_reportSections),
        'layout': _cloneJson(
          _activeReport?['content']?['layout'] ??
              _selectedTemplate?['structure']?['layout'],
        ),
        'answers': _cloneJson(_normalizeReportAnswers()),
        'photos': _cloneJson(_reportPhotos),
      },
    };

    final index = _reports.indexWhere((item) => item['id'] == _activeReportId);
    if (index == -1) {
      _reports = [..._reports, Map<String, dynamic>.from(reportSnapshot)];
      return;
    }

    _reports[index] = Map<String, dynamic>.from(reportSnapshot);
  }

  TaskOfflineDraft _buildOfflineDraft({bool? pendingSync}) {
    _syncActiveReportIntoCollection();

    return TaskOfflineDraft(
      draftId: _offlineDraftId,
      taskId: _taskId,
      activeReportId: _activeReportId,
      reportEquipmentId: _reportEquipmentId,
      updatedAt: DateTime.now().toIso8601String(),
      pendingSync: pendingSync ?? _offlineSyncPending,
      lookups: {
        'clients': _cloneJson(_clients),
        'users': _cloneJson(_users),
        'types': _cloneJson(_types),
        'templates': _cloneJson(_templates),
        'products': _cloneJson(_products),
        'equipments': _cloneJson(_equipments),
      },
      task: {
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
        'signature_client': _signatureClient,
        'signature_tech': _signatureTech,
        'signature_pages': _cloneJson(_signaturePages),
      },
      reports: _reports.map((item) => Map<String, dynamic>.from(_cloneJson(item) as Map)).toList(),
      budgets: _budgets.map((item) => Map<String, dynamic>.from(_cloneJson(item) as Map)).toList(),
    );
  }

  Future<void> _persistOfflineDraft({bool? pendingSync}) async {
    final draft = _buildOfflineDraft(pendingSync: pendingSync);
    await _offlineDraftStore.save(draft);
    if (!mounted) return;
    setState(() {
      _offlineSyncPending = draft.pendingSync;
    });
  }

  void _scheduleOfflineDraftSave({
    Duration delay = const Duration(milliseconds: 500),
    bool? pendingSync,
  }) {
    if (_trackingPaused) return;
    _offlineDraftTimer?.cancel();
    _offlineDraftTimer = Timer(delay, () {
      _persistOfflineDraft(pendingSync: pendingSync).catchError((_) {});
    });
  }

  Future<void> _clearOfflineDraft() async {
    await _offlineDraftStore.delete(_offlineDraftId);
    if (!mounted) return;
    setState(() {
      _offlineSyncPending = false;
      _loadingFromOfflineDraft = false;
    });
  }

  Future<void> _reconcileOfflineDraftAfterSync() async {
    if (_taskDraftDirty || _reportDraftDirty) {
      await _persistOfflineDraft(pendingSync: false);
      return;
    }
    await _clearOfflineDraft();
  }

  void _applyOfflineDraft(
    TaskOfflineDraft draft, {
    required bool replaceLookups,
  }) {
    _runWithoutDraftTracking(() {
      if (replaceLookups) {
        _clients = (draft.lookups['clients'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
        _users = (draft.lookups['users'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
        _types = (draft.lookups['types'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
        _templates = (draft.lookups['templates'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
        _products = (draft.lookups['products'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
        _equipments = (draft.lookups['equipments'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
      }

      final task = draft.task;
      _taskId = draft.taskId ?? _taskId;
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

      _reports = draft.reports.map(Map<String, dynamic>.from).toList();
      _budgets = draft.budgets.map(Map<String, dynamic>.from).toList();
      _activeReportId = draft.activeReportId;
      _reportEquipmentId = draft.reportEquipmentId;

      final report = _reports.firstWhere(
        (item) => item['id'] == _activeReportId,
        orElse: () => _reports.isNotEmpty ? _reports.first : <String, dynamic>{},
      );

      if (report.isNotEmpty) {
        _activeReportId = report['id'] as int?;
        _applyReportData(report, _taskTypeId);
      } else {
        _reportSections = [];
        _reportAnswers = {};
        _reportPhotos = [];
        _reportStatus = 'rascunho';
      }
    });

    _offlineSyncPending = draft.pendingSync;
    _loadingFromOfflineDraft = draft.pendingSync;
  }

  // Carrega o contexto completo necessário para editar uma tarefa. A chamada
  // para `/users` respeita a permissão do usuário logado para não depender
  // apenas do backend na experiência da interface.
  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final offlineDraft = await _offlineDraftStore.read(_offlineDraftId);
    try {
      final clients = await _api.get('/clients') as List<dynamic>;
      final users = AuthService.instance.hasPermission(Permissions.viewUsers)
          ? await _api.get('/users') as List<dynamic>
          : <dynamic>[];
      final types = await _api.get('/task-types') as List<dynamic>;
      final templates = await _api.get('/report-templates') as List<dynamic>;
      final products = await _api.get('/products') as List<dynamic>;

      _runWithoutDraftTracking(() {
        _clients = clients.cast<Map<String, dynamic>>();
        _users = users.cast<Map<String, dynamic>>();
        _types = types.cast<Map<String, dynamic>>();
        _templates = templates.cast<Map<String, dynamic>>();
        _products = products.cast<Map<String, dynamic>>();
      });

      if (_taskId != null) {
        final task = await _api.get('/tasks/$_taskId') as Map<String, dynamic>;
        _runWithoutDraftTracking(() {
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
        });

        await _loadReports(_taskTypeId);
        await _loadBudgets(_reports);
      }

      await _loadClientEquipments();

      if (offlineDraft != null) {
        _applyOfflineDraft(offlineDraft, replaceLookups: false);
      }

      _taskDraftDirty = false;
      _reportDraftDirty = false;
    } catch (error) {
      if (_isConnectionError(error) && offlineDraft != null) {
        _applyOfflineDraft(offlineDraft, replaceLookups: true);
      } else {
        _error = error.toString();
      }
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
      final data =
          await _api.get('/equipments?clientId=$_clientId') as List<dynamic>;
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

  // Sempre tentamos manter o relatório ativo selecionado após reload. Isso
  // evita a sensação de que o app "trocou" de relatório sozinho depois de um
  // save ou de uma atualização de tarefa.
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
            orElse: () =>
                nextReports.isNotEmpty ? nextReports.first : <String, dynamic>{},
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
    final reportIds =
        reportList.map((report) => report['id']).whereType<int>().toList();
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
    _reportDraftDirty = false;
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

  // Salvar a tarefa pode atualizar o relatório geral no backend. Guardamos o
  // relatório ativo antes do PUT para conseguir reconstruir a aba de relatório
  // sem perder o contexto do usuário.
  Map<String, dynamic> _buildTaskPayload() {
    return {
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
  }

  Map<String, dynamic> _buildReportPayloadFromReport(
    Map<String, dynamic> report, {
    int? taskIdOverride,
  }) {
    final content = _safeMap(report['content']);
    final templateId = report['template_id'] ?? _selectedTemplate?['id'];
    return {
      'title': report['title']?.toString() ?? _title.text,
      'task_id': taskIdOverride ?? report['task_id'] ?? _taskId,
      'client_id': report['client_id'] ?? _clientId,
      'template_id': templateId,
      'equipment_id': report['equipment_id'],
      'status': report['status']?.toString() ?? 'rascunho',
      'content': {
        'sections': _cloneJson(content['sections'] ?? const []),
        'layout': _cloneJson(
          content['layout'] ?? _selectedTemplate?['structure']?['layout'],
        ),
        'answers': _cloneJson(content['answers'] ?? const {}),
        'photos': _cloneJson(content['photos'] ?? const []),
      },
    };
  }

  Future<int?> _pushTaskToServer() async {
    final payload = _buildTaskPayload();
    if (_taskId == null) {
      final saved = await _api.post('/tasks', payload) as Map<String, dynamic>;
      final createdId = saved['id'] as int?;
      final previousDraftId = _offlineDraftId;
      _taskId = createdId;
      _offlineDraftId = TaskOfflineDraftStore.buildDraftId(createdId);
      if (previousDraftId != _offlineDraftId) {
        await _offlineDraftStore.delete(previousDraftId);
      }
      return createdId;
    }

    await _api.put('/tasks/$_taskId', payload);
    return _taskId;
  }

  Future<void> _saveTaskOffline() async {
    await _persistOfflineDraft(pendingSync: true);
    if (!mounted) return;
    setState(() {
      _offlineSyncPending = true;
      _loadingFromOfflineDraft = true;
    });
    _showMessage(
      _taskId == null
          ? 'Sem conexão. A nova tarefa foi salva como rascunho local.'
          : 'Sem conexão. As alterações da tarefa foram salvas neste aparelho.',
    );
  }

  Future<void> _saveTask() async {
    setState(() => _error = null);
    final previousActiveReportId = _activeReportId;
    final isEditing = _taskId != null;

    try {
      final createdId = await _pushTaskToServer();
      if (createdId != null && mounted) {
        setState(() => _taskId = createdId);
      }
      _markTaskDraftSynced();
    } catch (error) {
      if (_isConnectionError(error)) {
        await _saveTaskOffline();
      } else {
        _showMessage(error.toString());
      }
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
    await _reconcileOfflineDraftAfterSync();
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

  // O relatório pode ser salvo manualmente ou por auto-save. Nos dois casos,
  // a regra é a mesma: persistir o conteúdo atual sem trocar o relatório ativo
  // que o usuário estava editando.
  Future<void> _saveReport(
      {bool silent = false, bool skipReload = false}) async {
    if (_activeReportId == null) {
      setState(() => _reportMessage = 'Salve a tarefa para gerar o Relatório.');
      return;
    }
    var preferredReportId = _activeReportId;

    _syncActiveReportIntoCollection();
    final report = _reports.firstWhere(
      (item) => item['id'] == _activeReportId,
      orElse: () => <String, dynamic>{},
    );
    final payload = _buildReportPayloadFromReport(report);

    try {
      if ((_activeReportId ?? 0) < 0) {
        final created = await _api.post('/reports', payload) as Map<String, dynamic>;
        final createdId = created['id'] as int?;
        if (createdId != null) {
          final reportIndex = _reports.indexWhere((item) => item['id'] == _activeReportId);
          if (reportIndex != -1) {
            _reports[reportIndex] = {
              ...Map<String, dynamic>.from(_reports[reportIndex]),
              'id': createdId,
              'task_id': _taskId,
            };
          }
          _activeReportId = createdId;
          preferredReportId = createdId;
        }
      } else {
        await _api.put('/reports/$_activeReportId', payload);
      }
    _reportDirty = false;
    _reportDraftDirty = false;
      _markReportDraftSynced();
      if (silent && skipReload) {
        await _reconcileOfflineDraftAfterSync();
        return;
      }
      setState(() => _reportMessage = 'Relatório salvo com sucesso.');
      await _loadReports(
        _taskTypeId,
        preferredReportId: preferredReportId,
      );
      await _reconcileOfflineDraftAfterSync();
    } catch (error) {
      if (_isConnectionError(error)) {
        await _persistOfflineDraft(pendingSync: true);
        if (silent) return;
        setState(() {
          _offlineSyncPending = true;
          _loadingFromOfflineDraft = true;
          _reportMessage =
              'Sem conexão. O relatório foi salvo localmente e será sincronizado depois.';
        });
        return;
      }
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

  // O auto-save é propositalmente discreto: ele protege o trabalho do usuário
  // sem bloquear a edição nem exibir erro técnico em fluxo normal.
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
    final equipmentName = _equipments
        .firstWhere(
          (item) => item['id'] == equipmentId,
          orElse: () => <String, dynamic>{},
        )['name']
        ?.toString();

    setState(() {
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
    _markReportDraftDirty(
      localDelay: const Duration(milliseconds: 250),
      autosaveDelay: const Duration(milliseconds: 900),
    );

    try {
      if ((_activeReportId ?? 0) > 0) {
        await _api.put('/reports/$_activeReportId', {'equipment_id': equipmentId});
      }
    } catch (error) {
      if (_isConnectionError(error)) {
        await _persistOfflineDraft(pendingSync: true);
        if (!mounted) return;
        setState(() {
          _offlineSyncPending = true;
          _loadingFromOfflineDraft = true;
        });
        _showMessage(
          'Sem conexão. O equipamento do relatório foi salvo localmente.',
        );
        return;
      }
      _showMessage(error.toString());
    }
  }

  void _createLocalReport() {
    final template = _selectedTemplate;
    if (template == null) {
      setState(() => _reportMessage =
          'Este tipo de tarefa não possui modelo de Relatório.');
      return;
    }

    final localId = -DateTime.now().microsecondsSinceEpoch;
    final localReport = <String, dynamic>{
      'id': localId,
      'title': 'Relatório adicional',
      'task_id': _taskId,
      'client_id': _clientId,
      'template_id': template['id'],
      'equipment_id': null,
      'status': 'rascunho',
      'content': {
        'sections': _cloneJson(template['structure']?['sections'] ?? const []),
        'layout': _cloneJson(
          template['structure']?['layout'] ??
              {'sectionColumns': 1, 'fieldColumns': 1},
        ),
        'answers': <String, dynamic>{},
        'photos': <Map<String, dynamic>>[],
      },
    };

    setState(() {
      _reports = [..._reports, localReport];
      _activeReportId = localId;
      _applyReportData(localReport, _taskTypeId);
      _reportMessage =
          'Sem conexão. O novo relatório foi criado apenas neste aparelho.';
      _offlineSyncPending = true;
      _loadingFromOfflineDraft = true;
    });
    _reportDraftDirty = true;
    _scheduleOfflineDraftSave(pendingSync: true);
  }

  Future<void> _createReport() async {
    if (_taskId == null) return;
    if (_clientId == null) {
      setState(() =>
          _reportMessage = 'Selecione um cliente antes de criar o Relatório.');
      return;
    }
    final template = _selectedTemplate;
    if (template == null) {
      setState(() => _reportMessage =
          'Este tipo de tarefa não possui modelo de Relatório.');
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
      setState(() {
        _activeReportId = created['id'] as int?;
        _reportMessage = 'Relatório criado com sucesso.';
      });
    } catch (error) {
      if (_isConnectionError(error)) {
        _createLocalReport();
        return;
      }
      setState(() => _reportMessage = error.toString());
    }
  }

  Future<void> _deleteReport() async {
    if (_activeReportId == null) return;
    if ((_activeReportId ?? 0) < 0) {
      setState(() {
        _reports.removeWhere((item) => item['id'] == _activeReportId);
        _activeReportId = _reports.isNotEmpty ? _reports.first['id'] as int? : null;
        final nextReport = _reports.firstWhere(
          (item) => item['id'] == _activeReportId,
          orElse: () => <String, dynamic>{},
        );
        if (nextReport.isNotEmpty) {
          _applyReportData(nextReport, _taskTypeId);
        } else {
          _reportSections = [];
          _reportAnswers = {};
          _reportPhotos = [];
          _reportStatus = 'rascunho';
        }
        _reportMessage = 'Relatório local removido.';
        _offlineSyncPending = true;
        _loadingFromOfflineDraft = true;
      });
      _reportDraftDirty = true;
      await _persistOfflineDraft(pendingSync: true);
      return;
    }

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
    try {
      await _api.delete('/reports/$_activeReportId');
      await _loadReports(_taskTypeId);
      await _loadBudgets(_reports);
      _markReportDraftSynced();
      await _reconcileOfflineDraftAfterSync();
    } catch (error) {
      _showMessage(error.toString());
    }
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
    _markReportDraftDirty();
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
    _markReportDraftDirty();
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
    _markTaskDraftDirty();
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
    _markTaskDraftDirty();
  }

  Widget _buildDetailsTab() {
    return TaskDetailsTab(
      titleController: _title,
      descriptionController: _description,
      startDateController: _startDate,
      dueDateController: _dueDate,
      status: _status,
      priority: _priority,
      clientId: _clientId,
      userId: _userId,
      taskTypeId: _taskTypeId,
      clients: _clients,
      users: _users,
      types: _types,
      error: _error,
      onStatusChanged: (value) {
        setState(() => _status = value);
        _markTaskDraftDirty();
      },
      onPriorityChanged: (value) {
        setState(() => _priority = value);
        _markTaskDraftDirty();
      },
      onClientChanged: (value) async {
        setState(() {
          _clientId = value;
          _reportEquipmentId = null;
        });
        _markTaskDraftDirty();
        await _loadClientEquipments();
        if (_taskId != null) {
          await _loadReports(_taskTypeId);
          await _loadBudgets(_reports);
        }
      },
      onUserChanged: (value) {
        setState(() => _userId = value);
        _markTaskDraftDirty();
      },
      onTaskTypeChanged: (value) {
        setState(() => _taskTypeId = value);
        _markTaskDraftDirty();
      },
      onPickStartDate: () => _pickDate(_startDate),
      onPickDueDate: () => _pickDate(_dueDate),
      onSave: _saveTask,
    );
  }

  bool _isConnectionError(Object error) {
    return error is AppException && error.category == 'connection_error';
  }

  void _runWithoutDraftTracking(VoidCallback action) {
    _trackingPaused = true;
    try {
      action();
    } finally {
      _trackingPaused = false;
    }
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

    return TaskReportTab(
      taskId: _taskId,
      selectedTemplateExists: _selectedTemplate != null,
      reportOptions: reportOptions,
      activeReportId: _activeReportId,
      onActiveReportChanged: _handleActiveReportChange,
      reportStatus: _reportStatus,
      onReportStatusChanged: (value) {
        setState(() => _reportStatus = value);
        _markReportDirty();
      },
      equipmentField: _buildEquipmentField(),
      reportPhotos: _reportPhotos,
      onAddPhotos: _addPhotos,
      onRemovePhoto: _removePhoto,
      reportSections: _reportSections,
      buildReportFields: _buildReportFields,
      reportMessage: _reportMessage,
      onCreateReport: _createReport,
      onDeleteReport: _deleteReport,
      onSaveReport: _saveReport,
      onSendReportEmail: _sendReportEmail,
      onSharePublicLink: _shareTaskPublicLink,
      onOpenPublicPage: _openTaskPublicPage,
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
              _markReportDraftDirty();
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
              _markReportDraftDirty();
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
              _markReportDraftDirty();
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
            _markReportDraftDirty();
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
              _markReportDraftDirty();
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
            _markReportDraftDirty();
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

    return TaskBudgetsTab(
      taskId: _taskId,
      clientId: _clientId,
      generalReportId: generalReport['id'] as int?,
      products: _products,
      budgets: _budgets,
      onBudgetSaved: () => _loadBudgets(_reports),
      onEditBudget: _editBudget,
      onDeleteBudget: _deleteBudget,
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

    return TaskSignaturesTab(
      taskId: _taskId,
      signatureMode: _signatureMode,
      signatureScope: _signatureScope,
      signatureClient: _signatureClient,
      signatureTech: _signatureTech,
      signaturePages: _signaturePages,
      signaturePageItems:
          signaturePageItems.map((item) => item.map((key, value) => MapEntry(key, value.toString()))).toList(),
      onSignatureModeChanged: (value) {
        setState(() => _signatureMode = value);
        _markTaskDraftDirty();
      },
      onSignatureScopeChanged: (value) {
        setState(() => _signatureScope = value);
        _markTaskDraftDirty();
      },
      onSignatureClientChanged: (value) {
        setState(() => _signatureClient = value);
        _markTaskDraftDirty();
      },
      onSignatureTechChanged: (value) {
        setState(() => _signatureTech = value);
        _markTaskDraftDirty();
      },
      onUpdateSignaturePage: _updateSignaturePage,
      onSave: _saveTask,
    );
  }

  bool get _shouldShowOfflineBanner {
    return _offlineSyncPending ||
        _loadingFromOfflineDraft ||
        _taskDraftDirty ||
        _reportDraftDirty;
  }

  Future<void> _discardOfflineDraft() async {
    await _clearOfflineDraft();
    _taskDraftDirty = false;
    _reportDraftDirty = false;
    if (_taskId != null) {
      await _loadAll();
    } else {
      _runWithoutDraftTracking(() {
        _title.clear();
        _description.clear();
        _startDate.clear();
        _dueDate.clear();
        _clientId = null;
        _userId = null;
        _taskTypeId = null;
        _status = 'aberta';
        _priority = 'media';
        _reports = [];
        _budgets = [];
        _activeReportId = null;
        _reportSections = [];
        _reportAnswers = {};
        _reportPhotos = [];
        _reportStatus = 'rascunho';
        _signatureMode = 'none';
        _signatureScope = 'last_page';
        _signatureClient = '';
        _signatureTech = '';
        _signaturePages = {};
      });
      if (mounted) {
        setState(() {});
      }
    }
    if (!mounted) return;
    _showMessage('O rascunho local foi removido deste aparelho.');
  }

  Future<void> _syncOfflineDraft() async {
    if (_syncingOfflineDraft) return;

    setState(() => _syncingOfflineDraft = true);
    _offlineDraftTimer?.cancel();
    _syncActiveReportIntoCollection();

    try {
      final syncedTaskId = await _pushTaskToServer();
      if (syncedTaskId != null) {
        for (var index = 0; index < _reports.length; index += 1) {
          final report = Map<String, dynamic>.from(_reports[index]);
          final reportId = report['id'] as int?;
          final payload =
              _buildReportPayloadFromReport(report, taskIdOverride: syncedTaskId);

          if ((reportId ?? 0) < 0) {
            final created =
                await _api.post('/reports', payload) as Map<String, dynamic>;
            final createdId = created['id'] as int?;
            if (createdId != null) {
              _reports[index] = {
                ...report,
                'id': createdId,
                'task_id': syncedTaskId,
              };
              if (_activeReportId == reportId) {
                _activeReportId = createdId;
              }
            }
            continue;
          }

          if (reportId != null) {
            await _api.put('/reports/$reportId', payload);
          }
        }
      }

      _markTaskDraftSynced();
      _markReportDraftSynced();
      await _clearOfflineDraft();
      await _loadAll();
      _showMessage('Rascunho local sincronizado com sucesso.');
    } catch (error) {
      await _persistOfflineDraft(pendingSync: true);
      if (!mounted) return;
      setState(() {
        _offlineSyncPending = true;
        _loadingFromOfflineDraft = true;
      });
      _showMessage(
        _isConnectionError(error)
            ? 'Ainda não foi possível sincronizar. O rascunho continua salvo localmente.'
            : error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _syncingOfflineDraft = false);
      }
    }
  }

  Widget _buildOfflineBanner(BuildContext context) {
    final theme = Theme.of(context);
    final waitingConnection = _loadingFromOfflineDraft || _offlineSyncPending;
    final headline = waitingConnection
        ? 'Modo offline ativo'
        : 'Rascunho local disponível';
    final description = waitingConnection
        ? 'As alterações desta tarefa estão salvas neste aparelho e serão sincronizadas quando houver conexão.'
        : 'Existe um rascunho local desta tarefa salvo neste aparelho.';

    return Card(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.65),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  waitingConnection ? Icons.cloud_off_outlined : Icons.save_outlined,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    headline,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _syncingOfflineDraft ? null : _syncOfflineDraft,
                  icon: Icon(_syncingOfflineDraft ? Icons.sync : Icons.cloud_upload_outlined),
                  label: Text(_syncingOfflineDraft ? 'Sincronizando...' : 'Sincronizar agora'),
                ),
                TextButton.icon(
                  onPressed: _syncingOfflineDraft ? null : _discardOfflineDraft,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Descartar rascunho'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'em_andamento':
        return 'Em andamento';
      case 'concluida':
        return 'Concluída';
      default:
        return 'Aberta';
    }
  }

  String _priorityLabel(String value) {
    switch (value) {
      case 'alta':
        return 'Alta';
      case 'baixa':
        return 'Baixa';
      default:
        return 'Média';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(title: 'Tarefa', body: LoadingView());
    }
    if (_error != null) {
      return AppScaffold(title: 'Tarefa', body: Center(child: Text(_error!)));
    }

    final clientName = _clients
        .firstWhere(
          (item) => item['id'] == _clientId,
          orElse: () => <String, dynamic>{},
        )['name']
        ?.toString() ??
        'Sem cliente';
    final taskTypeName = _types
        .firstWhere(
          (item) => item['id'] == _taskTypeId,
          orElse: () => <String, dynamic>{},
        )['name']
        ?.toString();
    final heroTitle = _title.text.trim().isEmpty
        ? (_taskId == null ? 'Nova tarefa' : 'Detalhe da tarefa')
        : _title.text.trim();

    return AppScaffold(
      title: _taskId == null ? 'Nova tarefa' : 'Tarefa #$_taskId',
      subtitle: clientName,
      showLogo: false,
      body: Column(
        children: [
          AppHeroBanner(
            title: heroTitle,
            subtitle: [
              clientName,
              if (taskTypeName != null && taskTypeName.isNotEmpty) taskTypeName,
            ].join(' • '),
            trailing: const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0x1FFFFFFF),
              child: BrandLogo(height: 28),
            ),
            metrics: [
              AppHeroMetric(label: 'Status', value: _statusLabel(_status)),
              AppHeroMetric(label: 'Prioridade', value: _priorityLabel(_priority)),
              AppHeroMetric(label: 'Relatórios', value: '${_reports.length}'),
            ],
          ),
          const SizedBox(height: 16),
          AppSurface(
            child: Row(
              children: [
                Expanded(
                  child: _SummaryInfo(
                    title: 'Cliente e local',
                    value: clientName,
                    caption: _description.text.trim().isEmpty
                        ? 'Sem observação inicial registrada.'
                        : _description.text.trim(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryInfo(
                    title: 'Próxima ação',
                    value: _reports.isEmpty ? 'Criar relatório' : 'Atualizar execução',
                    caption:
                        '${_budgets.length} orçamento(s) • ${_equipments.length} equipamento(s)',
                  ),
                ),
              ],
            ),
          ),
          if (_shouldShowOfflineBanner) ...[
            const SizedBox(height: 12),
            _buildOfflineBanner(context),
          ],
          const SizedBox(height: 16),
          AppSurface(
            padding: const EdgeInsets.all(6),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Detalhes'),
                Tab(text: 'Relatório'),
                Tab(text: 'Orçamentos'),
                Tab(text: 'Assinaturas'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
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
        ],
      ),
    );
  }
}

class _SummaryInfo extends StatelessWidget {
  const _SummaryInfo({
    required this.title,
    required this.value,
    required this.caption,
  });

  final String title;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(caption, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

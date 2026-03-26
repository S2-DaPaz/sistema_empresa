/// Tela de detalhe / criação de tarefa — orquestrador de estado.
///
/// Concentra toda a lógica de negócio (CRUD de tarefa, relatórios,
/// orçamentos, fotos, assinaturas, autosave e links públicos).
/// A interface de cada aba foi extraída para widgets dedicados:
///   - [TaskDetailDetailsTab]    → aba "Detalhes"
///   - [TaskDetailReportTab]     → aba "Relatório"
///   - [TaskDetailBudgetsTab]    → aba "Orçamentos"
///   - [TaskDetailSignaturesTab] → aba "Assinaturas"
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/errors/app_exception.dart';
import '../features/tasks/data/task_detail_repository.dart';
import '../features/tasks/presentation/task_detail/report_autosave_scheduler.dart';
import '../features/tasks/presentation/task_detail/task_photo_processor.dart';
import '../services/auth_service.dart';
import '../services/permissions.dart';
import '../theme/app_tokens.dart';
import '../utils/contact_utils.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/budget_form.dart';
import '../widgets/email_recipient_dialog.dart';
import '../widgets/loading_view.dart';
import 'task_detail_budgets_tab.dart';
import 'task_detail_details_tab.dart';
import 'task_detail_report_tab.dart';
import 'task_detail_signatures_tab.dart';

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
  final TaskDetailRepository _repository = TaskDetailRepository();
  final ReportAutosaveScheduler _reportAutosaveScheduler =
      ReportAutosaveScheduler();
  final ImagePicker _picker = ImagePicker();
  final TaskPhotoProcessor _photoProcessor = const TaskPhotoProcessor(
    maxDimension: _maxPhotoDimension,
    jpegQuality: _photoJpegQuality,
  );
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
    _reportAutosaveScheduler.dispose();
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
      final bootstrap = await _repository.loadBootstrap(
        taskId: _taskId,
        includeUsers: AuthService.instance.hasPermission(Permissions.viewUsers),
      );

      _clients = bootstrap.clients;
      _users = bootstrap.users;
      _types = bootstrap.types;
      _templates = bootstrap.templates;
      _products = bootstrap.products;

      if (_taskId != null && bootstrap.task != null) {
        final task = bootstrap.task!;
        _title.text = task['title']?.toString() ?? '';
        _description.text = task['description']?.toString() ?? '';
        _clientId = task['client_id'] as int?;
        _userId = task['user_id'] as int?;
        _taskTypeId = task['task_type_id'] as int?;
        _status = task['status']?.toString() ?? 'aberta';
        _priority = task['priority']?.toString() ?? 'media';
        _startDate.text = formatarEntradaData(task['start_date']?.toString());
        _dueDate.text = formatarEntradaData(task['due_date']?.toString());
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
      final data = await _repository.loadClientEquipments(_clientId!);
      _setStateIfMounted(() {
        _equipments = data;
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
    final nextReports = await _repository.loadReports(_taskId!);
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
    final byTask = await _repository.loadBudgetsByTask(_taskId!);
    final reportIds =
        reportList.map((report) => report['id']).whereType<int>().toList();
    final byReports = await Future.wait(
      reportIds.map((id) => _repository.loadBudgetsByReport(id)),
    );

    final merged = <int, Map<String, dynamic>>{};
    for (final item in byTask) {
      if (item['id'] != null) {
        merged[item['id'] as int] = item;
      }
    }
    for (final list in byReports) {
      for (final item in list) {
        if (item['id'] != null) {
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
        initialBudget = await _repository.loadBudgetDetail(budget['id'] as int);
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
      await _repository.deleteBudget(id);
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
    _reportAutosaveScheduler.cancel();
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
      'start_date': converterDataBrParaIso(_startDate.text),
      'due_date': converterDataBrParaIso(_dueDate.text),
      'signature_mode': _signatureMode,
      'signature_scope': _signatureScope,
      'signature_client': _signatureClient.isEmpty ? null : _signatureClient,
      'signature_tech': _signatureTech.isEmpty ? null : _signatureTech,
      'signature_pages': _signaturePages,
    };

    final isEditing = _taskId != null;

    try {
      if (_taskId == null) {
        final saved = await _repository.createTask(payload);
        if (!mounted) return;
        setState(() {
          _taskId = saved['id'] as int?;
        });
        _openReportTab();
      } else {
        await _repository.updateTask(_taskId!, payload);
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
        normalized[fieldId] = converterDataBrParaIso(raw.toString());
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
      await _repository.updateReport(_activeReportId!, payload);
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
    if (_activeReportId == null) return;
    _reportAutosaveSeq = _reportAutosaveScheduler.schedule(
      delay: delay,
      onFire: _runReportAutosave,
    );
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
    _reportAutosaveScheduler.cancel();
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
      await _repository.updateReportEquipment(_activeReportId!, equipmentId);
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
      final created = await _repository.createReport(payload);
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
    await _repository.deleteReport(_activeReportId!);
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
    final newPhotos = await _photoProcessor.buildDrafts(files);
    if (!mounted) return;
    setState(
      () => _reportPhotos = [
        ..._reportPhotos,
        ...newPhotos.map((photo) => photo.toMap()),
      ],
    );
    _markReportDirty();
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
    final url = await _repository.createTaskPublicLink(_taskId!);
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
    if (_activeReport == null || _taskId == null) return;
    final client = _clients.firstWhere(
      (item) => item['id'] == _clientId,
      orElse: () => <String, dynamic>{},
    );
    final email = await showEmailRecipientDialog(
      context,
      title: 'Enviar relatório por e-mail',
      message:
          'Confirme o e-mail do destinatário para enviar um link seguro do relatório.',
      confirmLabel: 'Enviar relatório',
      initialEmail: extrairEmail(client['contact']?.toString()),
    );
    if (email == null || email.isEmpty) return;
    try {
      final message = await _repository.sendReportEmailLink(
        taskId: _taskId!,
        email: email,
        reportId: _activeReportId,
      );
      if (mounted) {
        _showMessage(message);
      }
    } catch (error) {
      _showMessage(error.toString());
    }
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
    controller.text = formatarDataDeDate(selected);
    setState(() {});
  }

  Future<void> _launchContact(String scheme, String value) async {
    if (value.isEmpty) return;
    await launchUrl(
      Uri.parse(scheme + value),
      mode: LaunchMode.externalApplication,
    );
  }

  void _onReportAnswerChanged(String fieldId, dynamic value) {
    setState(() => _reportAnswers[fieldId] = value);
    _markReportDirty();
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
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppGradients.darkScaffold
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF6FAFD), Color(0xFFEAF2F8)],
                ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            TaskDetailDetailsTab(
              taskId: _taskId,
              status: _status,
              priority: _priority,
              clientId: _clientId,
              userId: _userId,
              taskTypeId: _taskTypeId,
              titleController: _title,
              descriptionController: _description,
              startDateController: _startDate,
              dueDateController: _dueDate,
              error: _error,
              clients: _clients,
              users: _users,
              types: _types,
              reports: _reports,
              budgets: _budgets,
              signatureMode: _signatureMode,
              signatureClient: _signatureClient,
              signatureTech: _signatureTech,
              signaturePages: _signaturePages,
              onStatusChanged: (v) =>
                  setState(() => _status = v ?? 'aberta'),
              onPriorityChanged: (v) =>
                  setState(() => _priority = v ?? 'media'),
              onClientChanged: (v) async {
                setState(() {
                  _clientId = v;
                  _reportEquipmentId = null;
                });
                await _loadClientEquipments();
                if (_taskId != null) {
                  await _loadReports(_taskTypeId);
                  await _loadBudgets(_reports);
                }
              },
              onUserChanged: (v) => setState(() => _userId = v),
              onTaskTypeChanged: (v) =>
                  setState(() => _taskTypeId = v),
              onPickStartDate: () => _pickDate(_startDate),
              onPickDueDate: () => _pickDate(_dueDate),
              onSaveTask: _saveTask,
              onStartWork: _taskId != null && _status != 'em_andamento'
                  ? () {
                      setState(() => _status = 'em_andamento');
                      _saveTask();
                    }
                  : null,
              onLaunchContact: _launchContact,
            ),
            TaskDetailReportTab(
              taskId: _taskId,
              clientId: _clientId,
              activeReportId: _activeReportId,
              reports: _reports,
              reportSections: _reportSections,
              reportAnswers: _reportAnswers,
              reportPhotos: _reportPhotos,
              reportStatus: _reportStatus,
              reportMessage: _reportMessage,
              reportEquipmentId: _reportEquipmentId,
              equipments: _equipments,
              equipmentsLoading: _equipmentsLoading,
              equipmentsError: _equipmentsError,
              selectedTemplate: _selectedTemplate,
              onActiveReportChanged: _handleActiveReportChange,
              onReportStatusChanged: (v) {
                setState(() => _reportStatus = v ?? 'rascunho');
                _markReportDirty();
              },
              onReportAnswerChanged: _onReportAnswerChanged,
              onEquipmentChanged: _updateReportEquipment,
              onAddPhotos: _addPhotos,
              onRemovePhoto: _removePhoto,
              onCreateReport: _createReport,
              onDeleteReport: _deleteReport,
              onSaveReport: _saveReport,
              onSendEmail: _sendReportEmail,
              onShareLink: _shareTaskPublicLink,
              onOpenPdf: _openTaskPublicPage,
              onRetryEquipments: _loadClientEquipments,
            ),
            TaskDetailBudgetsTab(
              taskId: _taskId,
              clientId: _clientId,
              reports: _reports,
              budgets: _budgets,
              products: _products,
              onBudgetsSaved: () => _loadBudgets(_reports),
              onEditBudget: _editBudget,
              onDeleteBudget: _deleteBudget,
            ),
            TaskDetailSignaturesTab(
              taskId: _taskId,
              signatureMode: _signatureMode,
              signatureScope: _signatureScope,
              signatureClient: _signatureClient,
              signatureTech: _signatureTech,
              signaturePages: _signaturePages,
              reports: _reports,
              budgets: _budgets,
              onSignatureModeChanged: (v) =>
                  setState(() => _signatureMode = v ?? 'none'),
              onSignatureScopeChanged: (v) =>
                  setState(() => _signatureScope = v ?? 'last_page'),
              onSignatureClientChanged: (v) =>
                  setState(() => _signatureClient = v),
              onSignatureTechChanged: (v) =>
                  setState(() => _signatureTech = v),
              onSignaturePageChanged: _updateSignaturePage,
              onSave: _saveTask,
            ),
          ],
        ),
      ),
    );
  }
}

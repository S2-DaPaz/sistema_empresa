class TaskOfflineDraft {
  TaskOfflineDraft({
    required this.draftId,
    required this.updatedAt,
    required this.pendingSync,
    required this.lookups,
    required this.task,
    required this.reports,
    required this.budgets,
    this.taskId,
    this.activeReportId,
    this.reportEquipmentId,
  });

  final String draftId;
  final int? taskId;
  final int? activeReportId;
  final int? reportEquipmentId;
  final String updatedAt;
  final bool pendingSync;
  final Map<String, dynamic> lookups;
  final Map<String, dynamic> task;
  final List<Map<String, dynamic>> reports;
  final List<Map<String, dynamic>> budgets;

  factory TaskOfflineDraft.fromJson(Map<String, dynamic> json) {
    return TaskOfflineDraft(
      draftId: json['draftId']?.toString() ?? '',
      taskId: _toNullableInt(json['taskId']),
      activeReportId: _toNullableInt(json['activeReportId']),
      reportEquipmentId: _toNullableInt(json['reportEquipmentId']),
      updatedAt: json['updatedAt']?.toString() ?? '',
      pendingSync: json['pendingSync'] == true,
      lookups: _toMap(json['lookups']),
      task: _toMap(json['task']),
      reports: _toListOfMaps(json['reports']),
      budgets: _toListOfMaps(json['budgets']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'draftId': draftId,
      'taskId': taskId,
      'activeReportId': activeReportId,
      'reportEquipmentId': reportEquipmentId,
      'updatedAt': updatedAt,
      'pendingSync': pendingSync,
      'lookups': lookups,
      'task': task,
      'reports': reports,
      'budgets': budgets,
    };
  }

  static Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _toListOfMaps(dynamic value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static int? _toNullableInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }
}

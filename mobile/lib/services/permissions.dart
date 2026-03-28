import '../core/auth/auth_service.dart';
import '../core/contracts/generated/permissions.g.dart';

enum AppModule {
  dashboard,
  tasks,
  clients,
  budgets,
  products,
  taskTypes,
  templates,
  equipments,
  users,
  errorLogs,
  eventLogs,
}

class Permissions {
  static const String viewDashboard = AppPermissions.viewDashboard;
  static const String viewClients = AppPermissions.viewClients;
  static const String manageClients = AppPermissions.manageClients;
  static const String viewTasks = AppPermissions.viewTasks;
  static const String manageTasks = AppPermissions.manageTasks;
  static const String viewTemplates = AppPermissions.viewTemplates;
  static const String manageTemplates = AppPermissions.manageTemplates;
  static const String viewBudgets = AppPermissions.viewBudgets;
  static const String manageBudgets = AppPermissions.manageBudgets;
  static const String viewUsers = AppPermissions.viewUsers;
  static const String manageUsers = AppPermissions.manageUsers;
  static const String viewProducts = AppPermissions.viewProducts;
  static const String manageProducts = AppPermissions.manageProducts;
  static const String viewTaskTypes = AppPermissions.viewTaskTypes;
  static const String manageTaskTypes = AppPermissions.manageTaskTypes;

  static bool canAccessModule(AppModule module) {
    if (AuthService.instance.isVisitor) {
      return switch (module) {
        AppModule.dashboard ||
        AppModule.tasks ||
        AppModule.clients ||
        AppModule.budgets ||
        AppModule.products ||
        AppModule.taskTypes ||
        AppModule.templates ||
        AppModule.equipments => true,
        AppModule.users || AppModule.errorLogs || AppModule.eventLogs => false,
      };
    }

    return switch (module) {
      AppModule.dashboard => _has(viewDashboard),
      AppModule.tasks => _has(viewTasks),
      AppModule.clients => _has(viewClients),
      AppModule.budgets => _has(viewBudgets),
      AppModule.products => _has(viewProducts),
      AppModule.taskTypes => _has(viewTaskTypes),
      AppModule.templates => _has(viewTemplates),
      // Compatibilidade legada: equipamentos ainda compartilha a mesma
      // superfície operacional de tarefas e não possui permissão própria.
      AppModule.equipments => _has(viewTasks),
      AppModule.users => _has(viewUsers),
      AppModule.errorLogs || AppModule.eventLogs => AuthService.instance.isAdmin,
    };
  }

  static bool canViewModuleData(AppModule module) {
    if (AuthService.instance.isVisitor) {
      return false;
    }

    return switch (module) {
      AppModule.dashboard => _has(viewDashboard),
      AppModule.tasks => _has(viewTasks),
      AppModule.clients => _has(viewClients),
      AppModule.budgets => _has(viewBudgets),
      AppModule.products => _has(viewProducts),
      AppModule.taskTypes => _has(viewTaskTypes),
      AppModule.templates => _has(viewTemplates),
      AppModule.equipments => _has(viewTasks),
      AppModule.users => _has(viewUsers),
      AppModule.errorLogs || AppModule.eventLogs => AuthService.instance.isAdmin,
    };
  }

  static bool canManageModule(AppModule module) {
    if (AuthService.instance.isVisitor) {
      return false;
    }

    return switch (module) {
      AppModule.dashboard => false,
      AppModule.tasks => _has(manageTasks),
      AppModule.clients => _has(manageClients),
      AppModule.budgets => _has(manageBudgets),
      AppModule.products => _has(manageProducts),
      AppModule.taskTypes => _has(manageTaskTypes),
      AppModule.templates => _has(manageTemplates),
      AppModule.equipments => _has(manageTasks),
      AppModule.users => _has(manageUsers),
      AppModule.errorLogs || AppModule.eventLogs => AuthService.instance.isAdmin,
    };
  }

  static bool canViewEndpointData(String endpoint) {
    final module = _moduleForEndpoint(endpoint);
    if (module == null) {
      return !AuthService.instance.isVisitor;
    }
    return canViewModuleData(module);
  }

  static bool canManageEndpoint(String endpoint) {
    final module = _moduleForEndpoint(endpoint);
    if (module == null) {
      return !AuthService.instance.isVisitor;
    }
    return canManageModule(module);
  }

  static bool _has(String permission) {
    return AuthService.instance.hasPermission(permission);
  }

  static AppModule? _moduleForEndpoint(String endpoint) {
    final normalized = endpoint.split('?').first;
    return switch (normalized) {
      '/clients' => AppModule.clients,
      '/tasks' => AppModule.tasks,
      '/budgets' => AppModule.budgets,
      '/products' => AppModule.products,
      '/task-types' => AppModule.taskTypes,
      '/report-templates' => AppModule.templates,
      '/equipments' => AppModule.equipments,
      '/users' => AppModule.users,
      _ => null,
    };
  }
}

import 'generated/permissions.g.dart';

class PermissionCatalog {
  static const List<String> all = [
    AppPermissions.viewDashboard,
    AppPermissions.viewClients,
    AppPermissions.manageClients,
    AppPermissions.viewTasks,
    AppPermissions.manageTasks,
    AppPermissions.viewTemplates,
    AppPermissions.manageTemplates,
    AppPermissions.viewBudgets,
    AppPermissions.manageBudgets,
    AppPermissions.viewUsers,
    AppPermissions.manageUsers,
    AppPermissions.viewProducts,
    AppPermissions.manageProducts,
    AppPermissions.viewTaskTypes,
    AppPermissions.manageTaskTypes,
  ];

  static const Map<String, List<String>> roleDefaults = kRoleDefaults;
  static const List<String> reservedRoleKeys = kReservedRoleKeys;
}

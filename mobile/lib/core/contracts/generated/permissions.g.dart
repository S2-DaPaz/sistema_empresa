// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: packages/contracts/permissions.json

class AppPermissions {
  static const String viewDashboard = 'view_dashboard';
  static const String viewClients = 'view_clients';
  static const String manageClients = 'manage_clients';
  static const String viewTasks = 'view_tasks';
  static const String manageTasks = 'manage_tasks';
  static const String viewTemplates = 'view_templates';
  static const String manageTemplates = 'manage_templates';
  static const String viewBudgets = 'view_budgets';
  static const String manageBudgets = 'manage_budgets';
  static const String viewUsers = 'view_users';
  static const String manageUsers = 'manage_users';
  static const String viewProducts = 'view_products';
  static const String manageProducts = 'manage_products';
  static const String viewTaskTypes = 'view_task_types';
  static const String manageTaskTypes = 'manage_task_types';
}

const Map<String, List<String>> kRoleDefaults = {
  'administracao': [
    'view_dashboard',
    'view_clients',
    'manage_clients',
    'view_tasks',
    'manage_tasks',
    'view_templates',
    'manage_templates',
    'view_budgets',
    'manage_budgets',
    'view_users',
    'manage_users',
    'view_products',
    'manage_products',
    'view_task_types',
    'manage_task_types'
  ],
  'gestor': [
    'view_dashboard',
    'view_clients',
    'manage_clients',
    'view_tasks',
    'manage_tasks',
    'view_templates',
    'manage_templates',
    'view_budgets',
    'manage_budgets',
    'view_products',
    'manage_products',
    'view_task_types',
    'manage_task_types'
  ],
  'tecnico': [
    'view_dashboard',
    'view_clients',
    'view_tasks',
    'manage_tasks',
    'view_budgets',
    'view_products'
  ],
  'visitante': [
    'view_dashboard',
    'view_clients',
    'view_tasks',
    'view_templates',
    'view_budgets',
    'view_products',
    'view_task_types'
  ],
};

const List<String> kReservedRoleKeys = [
  'administracao',
  'gestor',
  'tecnico',
  'visitante'
];

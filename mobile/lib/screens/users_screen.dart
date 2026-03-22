import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/permissions.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_ui.dart';
import '../widgets/error_view.dart';
import '../widgets/form_fields.dart';
import '../widgets/loading_view.dart';

class PermissionOption {
  const PermissionOption(this.id, this.label);

  final String id;
  final String label;
}

class _RoleOption {
  const _RoleOption(this.key, this.name);

  final String key;
  final String name;
}

const List<_RoleOption> _fallbackRoles = [
  _RoleOption('administracao', 'Administração'),
  _RoleOption('gestor', 'Gestor'),
  _RoleOption('tecnico', 'Técnico'),
  _RoleOption('visitante', 'Visitante'),
];

const List<PermissionOption> _permissionOptions = [
  PermissionOption(Permissions.viewDashboard, 'Visualizar painel'),
  PermissionOption(Permissions.viewClients, 'Visualizar clientes'),
  PermissionOption(Permissions.manageClients, 'Gerenciar clientes'),
  PermissionOption(Permissions.viewTasks, 'Visualizar tarefas'),
  PermissionOption(Permissions.manageTasks, 'Gerenciar tarefas'),
  PermissionOption(Permissions.viewTemplates, 'Visualizar modelos'),
  PermissionOption(Permissions.manageTemplates, 'Gerenciar modelos'),
  PermissionOption(Permissions.viewBudgets, 'Visualizar orçamentos'),
  PermissionOption(Permissions.manageBudgets, 'Gerenciar orçamentos'),
  PermissionOption(Permissions.viewUsers, 'Visualizar usuários'),
  PermissionOption(Permissions.manageUsers, 'Gerenciar usuários'),
  PermissionOption(Permissions.viewProducts, 'Visualizar produtos'),
  PermissionOption(Permissions.manageProducts, 'Gerenciar produtos'),
  PermissionOption(Permissions.viewTaskTypes, 'Visualizar tipos de tarefa'),
  PermissionOption(Permissions.manageTaskTypes, 'Gerenciar tipos de tarefa'),
];

const Set<String> _reservedRoles = {
  'administracao',
  'gestor',
  'tecnico',
  'visitante',
};

List<String> _parsePermissions(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  if (value is String && value.isNotEmpty) {
    try {
      final parsed = jsonDecode(value);
      if (parsed is List) {
        return parsed.map((item) => item.toString()).toList();
      }
    } catch (_) {}
  }
  return [];
}

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _roles = [];

  bool get _canManage =>
      AuthService.instance.hasPermission(Permissions.manageUsers);
  bool get _canView =>
      AuthService.instance.hasPermission(Permissions.viewUsers);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_canView) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.get('/users'),
        _api.get('/roles'),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _users = ((results[0] as List?) ?? []).cast<Map<String, dynamic>>();
        _roles = ((results[1] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Não foi possível carregar usuários e perfis.';
        _loading = false;
      });
    }
  }

  String _roleName(String? key) {
    if (key == null) return 'Visitante';
    final match = _roles.where((role) => role['key']?.toString() == key).toList();
    if (match.isNotEmpty) {
      return match.first['name']?.toString() ?? key;
    }
    final fallback = _fallbackRoles.firstWhere(
      (role) => role.key == key,
      orElse: () => _fallbackRoles.last,
    );
    return fallback.name;
  }

  Future<void> _openUserForm({Map<String, dynamic>? item}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UserFormScreen(user: item, roles: _roles),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _openRoleForm({Map<String, dynamic>? item}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoleFormScreen(role: item),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover usuário'),
        content: const Text('Deseja remover este usuário?'),
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
    if (confirmed != true) return;

    try {
      await _api.delete('/users/$id');
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível remover o usuário agora.'),
        ),
      );
    }
  }

  Future<void> _deleteRole(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) return;
    if (_reservedRoles.contains(item['key']?.toString())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este perfil é protegido e não pode ser removido.'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover perfil'),
        content: Text('Deseja remover o perfil "${item['name']}"?'),
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
    if (confirmed != true) return;

    try {
      await _api.delete('/roles/$id');
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível remover o perfil agora.'),
        ),
      );
    }
  }

  Widget _buildUsersTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          if (_canManage)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _openUserForm(),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Novo usuário'),
              ),
            ),
          const SizedBox(height: AppTokens.space4),
          if (_users.isEmpty)
            const EmptyStateCard(
              title: 'Nenhum usuário cadastrado',
              subtitle: 'Convide pessoas e distribua papéis de acesso por perfil.',
            ),
          ..._users.map((item) {
            final roleKey = item['role']?.toString();
            final roleName = item['role_name']?.toString() ?? _roleName(roleKey);
            final isMe = item['id'] == AuthService.instance.user?['id'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppSurface(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          AppTokens.accentBlue.withValues(alpha: 0.12),
                      child: Text(
                        (item['name']?.toString().isNotEmpty ?? false)
                            ? item['name'].toString().trim().substring(0, 1).toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: AppTokens.accentBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                item['name']?.toString() ?? 'Sem nome',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              if (isMe) const AppStatusPill(label: 'Você'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['email']?.toString() ?? 'Sem e-mail',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          AppStatusPill(label: roleName),
                        ],
                      ),
                    ),
                    if (_canManage)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _openUserForm(item: item);
                          if (value == 'delete') _deleteUser(item);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Editar'),
                          ),
                          if (!isMe)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Remover'),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRolesTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          if (_canManage)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _openRoleForm(),
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Novo perfil'),
              ),
            ),
          const SizedBox(height: AppTokens.space4),
          if (_roles.isEmpty)
            const EmptyStateCard(
              title: 'Nenhum perfil cadastrado',
              subtitle: 'Crie perfis para centralizar permissões por tipo de usuário.',
            ),
          ..._roles.map((item) {
            final isAdmin = item['is_admin'] == true;
            final key = item['key']?.toString() ?? '';
            final permissions = (item['permissions'] as List?)?.length ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppSurface(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppTokens.supportTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: AppTokens.supportTeal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Text(
                                item['name']?.toString() ?? 'Perfil',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              if (isAdmin)
                                const AppStatusPill(
                                  label: 'ADM',
                                  color: AppTokens.accentBlue,
                                ),
                              if (_reservedRoles.contains(key))
                                const AppStatusPill(label: 'Padrão'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Código: $key',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isAdmin
                                ? 'Permissões: acesso total'
                                : 'Permissões: $permissions item(ns)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (_canManage)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _openRoleForm(item: item);
                          if (value == 'delete') _deleteRole(item);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Editar'),
                          ),
                          if (!_reservedRoles.contains(key))
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Remover'),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(title: 'Usuários', body: LoadingView());
    }
    if (_error != null) {
      return AppScaffold(
        title: 'Usuários',
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }
    if (!_canView) {
      return const AppScaffold(
        title: 'Usuários',
        body: EmptyStateCard(
          title: 'Acesso restrito',
          subtitle: 'Você não possui permissão para visualizar usuários.',
        ),
      );
    }

    return AppScaffold(
      title: 'Usuários e perfis',
      subtitle: 'Pessoas, papéis e acessos do sistema',
      body: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppHeroBanner(
              title: 'Usuários e papéis',
              subtitle: 'Gestão de pessoas, acessos e perfis da operação.',
              metrics: [
                AppHeroMetric(label: 'Usuários', value: '${_users.length}'),
                AppHeroMetric(label: 'Perfis', value: '${_roles.length}'),
              ],
            ),
            const SizedBox(height: AppTokens.space4),
            const AppSurface(
              padding: EdgeInsets.all(6),
              child: TabBar(
                tabs: [
                  Tab(text: 'Usuários'),
                  Tab(text: 'Perfis'),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space4),
            Expanded(
              child: TabBarView(
                children: [
                  _buildUsersTab(),
                  _buildRolesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key, this.user, required this.roles});

  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> roles;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _role = 'visitante';
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.user?['id'] != null;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    if (user != null) {
      _nameController.text = user['name']?.toString() ?? '';
      _emailController.text = user['email']?.toString() ?? '';
      _role = user['role']?.toString() ?? 'visitante';
    }
    if (widget.roles.isNotEmpty &&
        !widget.roles.any((role) => role['key']?.toString() == _role)) {
      _role = widget.roles.first['key']?.toString() ?? _role;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  List<DropdownMenuItem<String>> _buildRoleItems() {
    final roles = widget.roles.isNotEmpty
        ? widget.roles
            .map(
              (role) => _RoleOption(
                role['key']?.toString() ?? '',
                role['name']?.toString() ?? '',
              ),
            )
            .toList()
        : _fallbackRoles;

    return roles
        .map(
          (role) => DropdownMenuItem<String>(
            value: role.key,
            child: Text(role.name.isEmpty ? role.key : role.name),
          ),
        )
        .toList();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'role': _role,
    };
    if (!_isEdit || _passwordController.text.trim().isNotEmpty) {
      payload['password'] = _passwordController.text.trim();
    }

    try {
      if (_isEdit) {
        await _api.put('/users/${widget.user?['id']}', payload);
      } else {
        await _api.post('/users', payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      setState(() => _error = 'Não foi possível salvar o usuário.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Editar usuário' : 'Novo usuário',
      subtitle: 'Cadastro operacional',
      body: ListView(
        children: [
          AppSurface(
            child: Column(
              children: [
                AppTextField(label: 'Nome', controller: _nameController),
                const SizedBox(height: AppTokens.space4),
                AppTextField(label: 'E-mail', controller: _emailController),
                const SizedBox(height: AppTokens.space4),
                AppDropdownField<String>(
                  label: 'Perfil',
                  value: _role,
                  items: _buildRoleItems(),
                  onChanged: (value) => setState(() => _role = value ?? _role),
                ),
                const SizedBox(height: AppTokens.space4),
                AppTextField(
                  label: _isEdit ? 'Nova senha (opcional)' : 'Senha',
                  controller: _passwordController,
                  obscureText: true,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppTokens.space4),
            AppMessageBanner(
              message: _error!,
              icon: Icons.error_outline_rounded,
              toneColor: Theme.of(context).colorScheme.error,
            ),
          ],
          const SizedBox(height: AppTokens.space5),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}

class RoleFormScreen extends StatefulWidget {
  const RoleFormScreen({super.key, this.role});

  final Map<String, dynamic>? role;

  @override
  State<RoleFormScreen> createState() => _RoleFormScreenState();
}

class _RoleFormScreenState extends State<RoleFormScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _nameController = TextEditingController();
  List<String> _permissions = [];
  bool _isAdmin = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.role?['id'] != null;

  @override
  void initState() {
    super.initState();
    final role = widget.role;
    if (role != null) {
      _nameController.text = role['name']?.toString() ?? '';
      _permissions = _parsePermissions(role['permissions']);
      _isAdmin = role['is_admin'] == true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _togglePermission(String permission) {
    setState(() {
      if (_permissions.contains(permission)) {
        _permissions = _permissions.where((item) => item != permission).toList();
      } else {
        _permissions = [..._permissions, permission];
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = {
      'name': _nameController.text.trim(),
      'permissions': _isAdmin ? [] : _permissions,
      'is_admin': _isAdmin,
    };

    try {
      if (_isEdit) {
        await _api.put('/roles/${widget.role?['id']}', payload);
      } else {
        await _api.post('/roles', payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      setState(() => _error = 'Não foi possível salvar o perfil.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Editar perfil' : 'Novo perfil',
      subtitle: 'Permissões e acesso',
      body: ListView(
        children: [
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: 'Nome do perfil',
                  controller: _nameController,
                ),
                const SizedBox(height: AppTokens.space4),
                AppCheckboxField(
                  label: 'Permissões de administração',
                  value: _isAdmin,
                  onChanged: (value) => setState(() {
                    _isAdmin = value == true;
                    if (_isAdmin) _permissions = [];
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Permissões do perfil',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Ao ativar permissões de administração, o perfil passa a ter acesso total.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppTokens.space4),
                ..._permissionOptions.map(
                  (option) => AppCheckboxField(
                    label: option.label,
                    value: _permissions.contains(option.id),
                    onChanged: _isAdmin ? (_) {} : (_) => _togglePermission(option.id),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppTokens.space4),
            AppMessageBanner(
              message: _error!,
              icon: Icons.error_outline_rounded,
              toneColor: Theme.of(context).colorScheme.error,
            ),
          ],
          const SizedBox(height: AppTokens.space5),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}

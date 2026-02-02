import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/permissions.dart';
import '../widgets/app_scaffold.dart';
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

const Set<String> _reservedRoles = {'administracao', 'gestor', 'tecnico', 'visitante'};

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

  bool get _canManage => AuthService.instance.hasPermission(Permissions.manageUsers);
  bool get _canView => AuthService.instance.hasPermission(Permissions.viewUsers);

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
      final users = (results[0] as List?) ?? [];
      final roles = (results[1] as List?) ?? [];
      setState(() {
        _users = users.cast<Map<String, dynamic>>();
        _roles = roles.cast<Map<String, dynamic>>();
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      setState(() => _loading = false);
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
        builder: (_) => UserFormScreen(
          user: item,
          roles: _roles,
        ),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.delete('/users/$id');
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _deleteRole(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) return;
    if (_reservedRoles.contains(item['key']?.toString())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este cargo é protegido e não pode ser removido.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover cargo'),
        content: Text('Deseja remover o cargo "${item['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.delete('/roles/$id');
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
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
              child: ElevatedButton.icon(
                onPressed: () => _openUserForm(),
                icon: const Icon(Icons.person_add),
                label: const Text('Novo usuário'),
              ),
            ),
          const SizedBox(height: 12),
          if (_users.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhum usuário cadastrado.'),
              ),
            ),
          ..._users.map((item) {
            final roleKey = item['role']?.toString();
            final roleName = item['role_name']?.toString() ?? _roleName(roleKey);
            final isMe = item['id'] == AuthService.instance.user?['id'];
            return Card(
              child: ListTile(
                title: Row(
                  children: [
                    Expanded(child: Text(item['name']?.toString() ?? 'Sem nome')),
                    if (isMe)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Chip(label: Text('Você')),
                      ),
                  ],
                ),
                subtitle: Text(
                  '${item['email']?.toString() ?? 'Sem e-mail'}\nCargo: $roleName',
                ),
                isThreeLine: true,
                trailing: _canManage
                    ? PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _openUserForm(item: item);
                          if (value == 'delete') _deleteUser(item);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Editar')),
                          if (!isMe)
                            const PopupMenuItem(value: 'delete', child: Text('Remover')),
                        ],
                      )
                    : null,
              ),
            );
          }),
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
              child: ElevatedButton.icon(
                onPressed: () => _openRoleForm(),
                icon: const Icon(Icons.add_moderator_outlined),
                label: const Text('Novo cargo'),
              ),
            ),
          const SizedBox(height: 12),
          if (_roles.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhum cargo cadastrado.'),
              ),
            ),
          ..._roles.map((item) {
            final isAdmin = item['is_admin'] == true;
            final key = item['key']?.toString() ?? '';
            final permissions = (item['permissions'] as List?)?.length ?? 0;
            return Card(
              child: ListTile(
                title: Row(
                  children: [
                    Expanded(child: Text(item['name']?.toString() ?? 'Cargo')),
                    if (isAdmin)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Chip(label: Text('ADM')),
                      ),
                    if (_reservedRoles.contains(key))
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Chip(label: Text('Padrão')),
                      ),
                  ],
                ),
                subtitle: Text(
                  'Código: $key\nPermissões: ${isAdmin ? 'Todas (ADM)' : permissions}',
                ),
                isThreeLine: true,
                trailing: _canManage
                    ? PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _openRoleForm(item: item);
                          if (value == 'delete') _deleteRole(item);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Editar')),
                          if (!_reservedRoles.contains(key))
                            const PopupMenuItem(value: 'delete', child: Text('Remover')),
                        ],
                      )
                    : null,
              ),
            );
          }),
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
        body: Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Você não possui permissão para visualizar usuários.'),
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'Usuários',
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: 'Usuários'),
                Tab(text: 'Cargos'),
              ],
            ),
            const SizedBox(height: 12),
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
            .map((role) => _RoleOption(
                  role['key']?.toString() ?? '',
                  role['name']?.toString() ?? '',
                ))
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
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Editar usuário' : 'Novo usuário',
      body: ListView(
        children: [
          AppTextField(label: 'Nome', controller: _nameController),
          AppTextField(label: 'E-mail', controller: _emailController),
          AppDropdownField<String>(
            label: 'Cargo',
            value: _role,
            items: _buildRoleItems(),
            onChanged: (value) => setState(() => _role = value ?? _role),
          ),
          AppTextField(
            label: _isEdit ? 'Nova senha (opcional)' : 'Senha',
            controller: _passwordController,
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ),
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
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Editar cargo' : 'Novo cargo',
      body: ListView(
        children: [
          AppTextField(label: 'Nome do cargo', controller: _nameController),
          CheckboxListTile(
            value: _isAdmin,
            onChanged: (value) => setState(() {
              _isAdmin = value == true;
              if (_isAdmin) _permissions = [];
            }),
            title: const Text('Permissões de ADM'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          Text(
            'Permissões do cargo',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ..._permissionOptions.map(
            (option) => CheckboxListTile(
              value: _permissions.contains(option.id),
              onChanged: _isAdmin ? null : (_) => _togglePermission(option.id),
              title: Text(option.label),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ao ativar "Permissões de ADM", o cargo passa a ter acesso total.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}

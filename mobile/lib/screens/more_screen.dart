import 'package:flutter/material.dart';

import 'products_screen.dart';
import 'task_types_screen.dart';
import 'templates_screen.dart';
import 'users_screen.dart';
import 'equipments_screen.dart';
import '../services/auth_service.dart';
import '../services/permissions.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/brand_logo.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Mais',
      body: ValueListenableBuilder<AuthSession?>(
        valueListenable: AuthService.instance.session,
        builder: (context, session, _) {
          final name = session?.user['name']?.toString() ?? 'Visitante';
          final role = session?.user['role_name']?.toString() ??
              session?.user['role']?.toString() ??
              'visitante';
          final canViewUsers = AuthService.instance.hasPermission(Permissions.viewUsers);
          final canViewEquipments = AuthService.instance.hasPermission(Permissions.viewTasks);
          return ListView(
            children: [
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const BrandLogo(height: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RV TecnoCare',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Atalhos e configurações do sistema',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Text('$name • $role'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (canViewUsers)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Usuários'),
                  subtitle: const Text('Gestão de usuários do sistema'),
                    onTap: () => _open(context, UsersScreen()),
                  ),
                ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Produtos'),
                  subtitle: const Text('Cadastro de itens de orçamento'),
                  onTap: () => _open(context, ProductsScreen()),
                ),
              ),
              if (canViewEquipments)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.devices_other_outlined),
                    title: const Text('Equipamentos'),
                    subtitle: const Text('Cadastro e vínculo com clientes'),
                    onTap: () => _open(context, const EquipmentsScreen()),
                  ),
                ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Tipos de tarefa'),
                  subtitle: const Text('Modelo de relatório por tipo'),
                  onTap: () => _open(context, const TaskTypesScreen()),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Modelos de relatório'),
                  subtitle: const Text('Campos dinâmicos para relatórios'),
                  onTap: () => _open(context, const TemplatesScreen()),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sair'),
                  onTap: () => AuthService.instance.logout(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

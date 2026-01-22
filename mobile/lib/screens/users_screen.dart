import '../utils/entity_config.dart';
import '../utils/field_config.dart';
import 'entity_list_screen.dart';

class UsersScreen extends EntityListScreen {
  UsersScreen({super.key})
      : super(
          config: EntityConfig(
            title: 'Usuários',
            endpoint: '/users',
            primaryField: 'name',
            hint: 'Controle de usuários do sistema.',
            fields: [
              FieldConfig(name: 'name', label: 'Nome', type: FieldType.text),
              FieldConfig(name: 'email', label: 'E-mail', type: FieldType.text),
              FieldConfig(name: 'role', label: 'Função', type: FieldType.text),
            ],
          ),
        );
}

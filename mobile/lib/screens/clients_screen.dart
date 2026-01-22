import '../utils/entity_config.dart';
import '../utils/field_config.dart';
import 'entity_list_screen.dart';

class ClientsScreen extends EntityListScreen {
  ClientsScreen({super.key})
      : super(
          config: EntityConfig(
            title: 'Clientes',
            endpoint: '/clients',
            primaryField: 'name',
            hint: 'Cadastre empresas e contatos principais.',
            fields: [
              FieldConfig(name: 'name', label: 'Nome', type: FieldType.text),
              FieldConfig(name: 'cnpj', label: 'CPF/CNPJ', type: FieldType.text),
              FieldConfig(name: 'address', label: 'Endereço', type: FieldType.textarea),
              FieldConfig(name: 'contact', label: 'Contato', type: FieldType.text),
            ],
          ),
        );
}

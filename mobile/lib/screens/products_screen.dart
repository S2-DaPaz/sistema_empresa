import '../utils/entity_config.dart';
import '../utils/field_config.dart';
import '../utils/formatters.dart';
import 'entity_list_screen.dart';

class ProductsScreen extends EntityListScreen {
  ProductsScreen({super.key})
      : super(
          config: EntityConfig(
            title: 'Produtos',
            endpoint: '/products',
            primaryField: 'name',
            hint: 'Produtos usados nos orçamentos.',
            fields: [
              FieldConfig(name: 'name', label: 'Nome', type: FieldType.text),
              FieldConfig(name: 'sku', label: 'SKU', type: FieldType.text),
              FieldConfig(name: 'unit', label: 'Unidade', type: FieldType.text),
              FieldConfig(
                name: 'price',
                label: 'Preço',
                type: FieldType.number,
                formatter: (value) => formatCurrency(num.tryParse(value.toString()) ?? 0),
              ),
            ],
          ),
        );
}

import '../utils/entity_config.dart';
import '../utils/field_config.dart';
import '../utils/formatters.dart';
import 'entity_list_screen.dart';

class ProductsScreen extends EntityListScreen {
  ProductsScreen({super.key})
      : super(
          config: ConfiguracaoEntidade(
            title: 'Produtos',
            endpoint: '/products',
            primaryField: 'name',
            hint: 'Produtos usados nos orçamentos.',
            fields: [
              ConfiguracaoCampo(name: 'name', label: 'Nome', type: TipoCampo.text),
              ConfiguracaoCampo(name: 'sku', label: 'SKU', type: TipoCampo.text),
              ConfiguracaoCampo(name: 'unit', label: 'Unidade', type: TipoCampo.text),
              ConfiguracaoCampo(
                name: 'price',
                label: 'Preço',
                type: TipoCampo.number,
                formatter: (value) =>
                    formatarMoeda(num.tryParse(value.toString()) ?? 0),
              ),
            ],
          ),
        );
}

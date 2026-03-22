import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/budget_item.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_ui.dart';
import '../widgets/form_fields.dart';

class BudgetItemFormPage extends StatefulWidget {
  const BudgetItemFormPage({
    super.key,
    required this.products,
    this.initialItem,
  });

  final List<Map<String, dynamic>> products;
  final BudgetItemData? initialItem;

  @override
  State<BudgetItemFormPage> createState() => _BudgetItemFormPageState();
}

class _BudgetItemFormPageState extends State<BudgetItemFormPage> {
  final TextEditingController _description = TextEditingController();
  final TextEditingController _qty = TextEditingController(text: '1');
  final TextEditingController _unitPrice = TextEditingController(text: '');

  int? _productId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    if (item != null) {
      _description.text = item.description;
      _qty.text = item.qty.toString();
      _unitPrice.text = formatCurrency(item.unitPrice);
      _productId = item.productId;
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _qty.dispose();
    _unitPrice.dispose();
    super.dispose();
  }

  double _toDouble(String value) {
    if (value.contains('R\$')) {
      return parseCurrency(value);
    }
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }

  void _handleProductChange(int? productId) {
    _productId = productId;
    final product = widget.products.firstWhere(
      (item) => item['id'] == productId,
      orElse: () => {},
    );
    if (product.isNotEmpty) {
      if (_description.text.trim().isEmpty) {
        _description.text = product['name']?.toString() ?? '';
      }
      if (_unitPrice.text.trim().isEmpty || _toDouble(_unitPrice.text) == 0) {
        _unitPrice.text = formatCurrency(product['price'] ?? 0);
      }
    }
    setState(() {});
  }

  void _save() {
    setState(() => _error = null);

    final description = _description.text.trim();
    final qty = _toDouble(_qty.text);
    final unitPrice = _toDouble(_unitPrice.text);

    if (description.isEmpty) {
      setState(() => _error = 'Informe a descrição do item.');
      return;
    }
    if (qty <= 0) {
      setState(() => _error = 'A quantidade deve ser maior que zero.');
      return;
    }
    if (unitPrice < 0) {
      setState(() => _error = 'O valor unitário não pode ser negativo.');
      return;
    }

    final item = BudgetItemData(
      id: widget.initialItem?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      description: description,
      qty: qty,
      unitPrice: unitPrice,
      productId: _productId,
    );
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final productOptions = widget.products
        .map(
          (product) => DropdownMenuItem<int>(
            value: product['id'] as int?,
            child: Text(
              product['name']?.toString() ?? 'Produto',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();

    final total = _toDouble(_qty.text) * _toDouble(_unitPrice.text);

    return AppScaffold(
      title: widget.initialItem == null ? 'Adicionar item' : 'Editar item',
      subtitle: 'Composição flexível do orçamento',
      showLogo: false,
      body: ListView(
        children: [
          AppSurface(
            backgroundColor: AppTokens.bgSoft,
            shadow: const [],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contexto',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppTokens.space3),
                Text(
                  widget.initialItem == null
                      ? 'Inclua um novo item na proposta atual.'
                      : 'Revise quantidade, descrição e valor antes de salvar.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space5),
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionBlock(
                  title: 'Dados do item',
                  subtitle: 'Produto, quantidade, valor unitário e descrição.',
                ),
                const SizedBox(height: AppTokens.space4),
                if (productOptions.isNotEmpty) ...[
                  AppDropdownField<int>(
                    label: 'Produto',
                    value: _productId,
                    items: productOptions,
                    onChanged: _handleProductChange,
                  ),
                  const SizedBox(height: AppTokens.space4),
                ],
                AppTextField(
                  label: 'Descrição',
                  controller: _description,
                ),
                const SizedBox(height: AppTokens.space4),
                AppTextField(
                  label: 'Quantidade',
                  controller: _qty,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                ),
                const SizedBox(height: AppTokens.space4),
                AppTextField(
                  label: 'Valor unitário',
                  controller: _unitPrice,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  inputFormatters: [CurrencyInputFormatter()],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space5),
          AppMetricTile(
            title: 'Resumo do item',
            value: formatCurrency(total),
            subtitle: 'Subtotal calculado com quantidade e valor unitário.',
            emphasis: true,
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Salvar item'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

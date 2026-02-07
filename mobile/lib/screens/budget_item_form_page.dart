import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/budget_item.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
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
  final _formKey = GlobalKey<FormState>();
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
      setState(() => _error = 'A descrição é obrigatória.');
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
      id: widget.initialItem?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
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
        .map((product) => DropdownMenuItem<int>(
              value: product['id'] as int?,
              child: Text(
                product['name']?.toString() ?? 'Produto',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ))
        .toList();

    return AppScaffold(
      title: widget.initialItem == null ? 'Adicionar item' : 'Editar item',
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            if (productOptions.isNotEmpty) ...[
              AppDropdownField<int>(
                label: 'Produto',
                value: _productId,
                items: productOptions,
                onChanged: _handleProductChange,
              ),
              const SizedBox(height: 12),
            ],
            AppTextField(
              label: 'Descrição',
              controller: _description,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Quantidade',
              controller: _qty,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Valor unitário',
              controller: _unitPrice,
              keyboardType: TextInputType.number,
              inputFormatters: [
                CurrencyInputFormatter(),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _save,
                  child: const Text('Salvar'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Cancelar'),
                ),
                if (_unitPrice.text.trim().isNotEmpty)
                  Chip(
                    label: Text(
                      'Total: ${formatCurrency(_toDouble(_qty.text) * _toDouble(_unitPrice.text))}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

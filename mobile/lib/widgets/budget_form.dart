import 'package:flutter/material.dart';

import '../models/budget_item.dart';
import '../screens/budget_item_form_page.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import 'form_fields.dart';
import 'signature_pad.dart';

class BudgetForm extends StatefulWidget {
  const BudgetForm({
    super.key,
    required this.products,
    this.clients = const [],
    this.clientId,
    this.taskId,
    this.reportId,
    this.initialBudget,
    this.onSaved,
  });

  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> clients;
  final int? clientId;
  final int? taskId;
  final int? reportId;
  final Map<String, dynamic>? initialBudget;
  final VoidCallback? onSaved;

  @override
  State<BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<BudgetForm> {
  final ApiService _api = ApiService();
  final List<BudgetItemData> _items = [];

  int? _localClientId;
  String _status = 'em_andamento';
  String? _createdAt;
  int? _selectedItemIndex;
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _internalNote = TextEditingController();
  final TextEditingController _proposalValidity = TextEditingController(text: '30 dias');
  final TextEditingController _paymentTerms = TextEditingController(text: 'A vista');
  final TextEditingController _serviceDeadline = TextEditingController(text: '03 a 04 horas');
  final TextEditingController _productValidity = TextEditingController(text: '03 meses');
  final TextEditingController _discount = TextEditingController(text: '0');
  final TextEditingController _tax = TextEditingController(text: '0');
  String _signatureMode = 'none';
  String _signatureScope = 'last_page';
  String _signatureClient = '';
  String _signatureTech = '';
  Map<String, dynamic> _signaturePages = {};

  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _localClientId = widget.clientId;
    _applyBudget(widget.initialBudget);
  }

  @override
  void didUpdateWidget(covariant BudgetForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientId != widget.clientId) {
      setState(() => _localClientId = widget.clientId);
    }
    if (oldWidget.initialBudget?['id'] != widget.initialBudget?['id']) {
      setState(() => _applyBudget(widget.initialBudget));
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    _internalNote.dispose();
    _proposalValidity.dispose();
    _paymentTerms.dispose();
    _serviceDeadline.dispose();
    _productValidity.dispose();
    _discount.dispose();
    _tax.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final result = await Navigator.of(context).push<BudgetItemData>(
      MaterialPageRoute(
        builder: (context) => BudgetItemFormPage(products: widget.products),
      ),
    );
    if (result == null) return;
    setState(() {
      _items.add(result);
      _selectedItemIndex = _items.length - 1;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item adicionado')),
    );
  }

  void _applyBudget(Map<String, dynamic>? budget) {
    _items.clear();

    if (budget == null) {
      _selectedItemIndex = null;
      return;
    }

    if (widget.clientId == null) {
      _localClientId = budget['client_id'] as int?;
    }
    _status = budget['status']?.toString() ?? 'em_andamento';
    _notes.text = budget['notes']?.toString() ?? '';
    _internalNote.text = budget['internal_note']?.toString() ?? '';
    _proposalValidity.text = budget['proposal_validity']?.toString() ?? '30 dias';
    _paymentTerms.text = budget['payment_terms']?.toString() ?? 'A vista';
    _serviceDeadline.text = budget['service_deadline']?.toString() ?? '03 a 04 horas';
    _productValidity.text = budget['product_validity']?.toString() ?? '03 meses';
    _discount.text = (budget['discount'] ?? 0).toString();
    _tax.text = (budget['tax'] ?? 0).toString();
    _signatureMode = budget['signature_mode']?.toString() ?? 'none';
    _signatureScope = budget['signature_scope']?.toString() ?? 'last_page';
    _signatureClient = budget['signature_client']?.toString() ?? '';
    _signatureTech = budget['signature_tech']?.toString() ?? '';
    final pages = budget['signature_pages'];
    if (pages is Map) {
      _signaturePages = Map<String, dynamic>.from(pages);
    } else {
      _signaturePages = {};
    }
    _createdAt = budget['created_at']?.toString();

    final items = (budget['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    for (final item in items) {
      _items.add(BudgetItemData.fromMap(item));
    }
    _selectedItemIndex = _items.isEmpty ? null : 0;
  }

  Future<void> _editSelectedItem() async {
    final index = _selectedItemIndex;
    if (index == null || index < 0 || index >= _items.length) return;
    final current = _items[index];
    final result = await Navigator.of(context).push<BudgetItemData>(
      MaterialPageRoute(
        builder: (context) => BudgetItemFormPage(
          products: widget.products,
          initialItem: current,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _items[index] = result;
      _selectedItemIndex = index;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item atualizado')),
    );
  }

  Future<void> _removeSelectedItem() async {
    final index = _selectedItemIndex;
    if (index == null || index < 0 || index >= _items.length) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir item'),
        content: const Text('Deseja excluir este item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _items.removeAt(index);
      if (_items.isEmpty) {
        _selectedItemIndex = null;
      } else if (index == 0) {
        _selectedItemIndex = 0;
      } else {
        _selectedItemIndex = index - 1;
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item removido')),
    );
  }

  double _toDouble(String value) {
    if (value.contains('R\$')) {
      return parseCurrency(value);
    }
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }

  double get _subtotal {
    double sum = 0;
    for (final item in _items) {
      final qty = item.qty;
      final price = item.unitPrice;
      sum += qty * price;
    }
    return sum;
  }

  double get _total {
    final discount = _toDouble(_discount.text);
    final tax = _toDouble(_tax.text);
    return _subtotal - discount + tax;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final clientId = widget.clientId ?? _localClientId;
    if (clientId == null) {
      setState(() {
        _saving = false;
        _error = 'Selecione um cliente antes de salvar.';
      });
      return;
    }

    final payload = {
      'client_id': clientId,
      'task_id': widget.taskId ?? widget.initialBudget?['task_id'],
      'report_id': widget.reportId ?? widget.initialBudget?['report_id'],
      'status': _status,
      'notes': _notes.text,
      'internal_note': _internalNote.text,
      'proposal_validity': _proposalValidity.text,
      'payment_terms': _paymentTerms.text,
      'service_deadline': _serviceDeadline.text,
      'product_validity': _productValidity.text,
      'signature_mode': _signatureMode,
      'signature_scope': _signatureScope,
      'signature_client': _signatureClient,
      'signature_tech': _signatureTech,
      'signature_pages': _signaturePages,
      'discount': _toDouble(_discount.text),
      'tax': _toDouble(_tax.text),
      'items': _items.map((item) {
        return {
          'product_id': item.productId,
          'description': item.description.isEmpty ? 'Item' : item.description,
          'qty': item.qty,
          'unit_price': item.unitPrice,
        };
      }).toList(),
    };

    if (_createdAt != null) {
      payload['created_at'] = _createdAt;
    }

    final budgetId = widget.initialBudget?['id'] as int?;
    try {
      if (budgetId != null) {
        await _api.put('/budgets/$budgetId', payload);
      } else {
        await _api.post('/budgets', payload);
      }
      if (widget.onSaved != null) widget.onSaved!();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            budgetId != null ? 'Orçamento atualizado com sucesso.' : 'Orçamento salvo com sucesso.',
          ),
        ),
      );
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientOptions = widget.clients
        .map((client) => DropdownMenuItem<int>(
              value: client['id'] as int?,
              child: Text(
                client['name']?.toString() ?? 'Cliente',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ))
        .toList();

    final isEditing = widget.initialBudget != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? 'Editar orçamento' : 'Novo orçamento',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (widget.clientId == null)
              AppDropdownField<int>(
                label: 'Cliente',
                value: _localClientId,
                items: clientOptions,
                onChanged: (value) => setState(() => _localClientId = value),
              ),
            const SizedBox(height: 8),
            AppDropdownField<String>(
              label: 'Status',
              value: _status,
              items: const [
                DropdownMenuItem(value: 'aprovado', child: Text('Aprovado')),
                DropdownMenuItem(value: 'em_andamento', child: Text('Em andamento')),
                DropdownMenuItem(value: 'recusado', child: Text('Recusado')),
              ],
              onChanged: (value) => setState(() => _status = value ?? 'em_andamento'),
            ),
            const SizedBox(height: 8),
            AppTextField(
              label: 'Desconto',
              controller: _discount,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              inputFormatters: [
                CurrencyInputFormatter(),
              ],
            ),
            const SizedBox(height: 8),
            AppTextField(label: 'Validade da proposta', controller: _proposalValidity),
            const SizedBox(height: 8),
            AppDropdownField<String>(
              label: 'Condição de pagamento',
              value: _paymentTerms.text,
              items: const [
                DropdownMenuItem(value: 'A vista', child: Text('A vista')),
                DropdownMenuItem(value: 'Parcelado', child: Text('Parcelado')),
              ],
              onChanged: (value) => setState(() => _paymentTerms.text = value ?? 'A vista'),
            ),
            const SizedBox(height: 8),
            AppTextField(label: 'Prazo de serviço', controller: _serviceDeadline),
            const SizedBox(height: 8),
            AppTextField(label: 'Validade dos produtos', controller: _productValidity),
            const SizedBox(height: 8),
            AppTextField(label: 'Observações', controller: _notes, maxLines: 3),
            const SizedBox(height: 8),
            AppTextField(label: 'Nota interna', controller: _internalNote, maxLines: 3),
            const SizedBox(height: 16),
            Text('Assinaturas', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            AppDropdownField<String>(
              label: 'Assinatura',
              value: _signatureMode,
              items: const [
                DropdownMenuItem(value: 'none', child: Text('Sem assinatura')),
                DropdownMenuItem(value: 'client', child: Text('Cliente')),
                DropdownMenuItem(value: 'tech', child: Text('Técnico')),
                DropdownMenuItem(value: 'both', child: Text('Cliente e técnico')),
              ],
              onChanged: (value) => setState(() => _signatureMode = value ?? 'none'),
            ),
            const SizedBox(height: 8),
            AppDropdownField<String>(
              label: 'Escopo',
              value: _signatureScope,
              items: const [
                DropdownMenuItem(value: 'last_page', child: Text('Assinar apenas no final')),
                DropdownMenuItem(value: 'all_pages', child: Text('Assinar todas as páginas')),
              ],
              onChanged: (value) {
                if (_signatureMode == 'none') return;
                setState(() => _signatureScope = value ?? 'last_page');
              },
            ),
            if (_signatureMode != 'none') ...[
              const SizedBox(height: 12),
              if (_signatureMode == 'client' || _signatureMode == 'both')
                SignaturePadField(
                  label: 'Assinatura do cliente',
                  value: _signatureClient,
                  onChanged: (value) => setState(() => _signatureClient = value),
                ),
              if (_signatureMode == 'tech' || _signatureMode == 'both') ...[
                const SizedBox(height: 12),
                SignaturePadField(
                  label: 'Assinatura do técnico',
                  value: _signatureTech,
                  onChanged: (value) => setState(() => _signatureTech = value),
                ),
              ],
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Itens', style: Theme.of(context).textTheme.titleSmall),
                OutlinedButton(onPressed: _addItem, child: const Text('Adicionar item')),
              ],
            ),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              const Text('Nenhum item adicionado.')
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppDropdownField<int>(
                    label: 'Item selecionado',
                    value: _selectedItemIndex,
                    items: _items
                        .asMap()
                        .entries
                        .map((entry) {
                          final item = entry.value;
                          final label =
                              '${entry.key + 1} - ${item.description} (Qtd: ${item.qty}, Unit: ${formatCurrency(item.unitPrice)})';
                          return DropdownMenuItem<int>(
                            value: entry.key,
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        })
                        .toList(),
                    onChanged: (value) => setState(() => _selectedItemIndex = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed:
                            _selectedItemIndex == null ? null : _editSelectedItem,
                        child: const Text('Editar'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed:
                            _selectedItemIndex == null ? null : _removeSelectedItem,
                        child: const Text('Excluir'),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(label: Text('Subtotal: ${formatCurrency(_subtotal)}')),
                Chip(label: Text('Total: ${formatCurrency(_total)}')),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving
                    ? 'Salvando...'
                    : (isEditing ? 'Atualizar orçamento' : 'Salvar orçamento'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

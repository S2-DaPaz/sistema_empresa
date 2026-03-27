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

  int? _clienteIdLocal;
  String _status = 'em_andamento';
  String? _createdAt;
  int? _indiceItemSelecionado;
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _notaInterna = TextEditingController();
  final TextEditingController _validadeProposta =
      TextEditingController(text: '30 dias');
  final TextEditingController _condicaoPagamento =
      TextEditingController(text: 'À vista');
  final TextEditingController _prazoServico =
      TextEditingController(text: '03 a 04 horas');
  final TextEditingController _validadeProdutos =
      TextEditingController(text: '03 meses');
  final TextEditingController _discount = TextEditingController(text: '0');
  final TextEditingController _tax = TextEditingController(text: '0');
  String _modoAssinatura = 'none';
  String _escopoAssinatura = 'last_page';
  String _assinaturaCliente = '';
  String _assinaturaTecnico = '';
  Map<String, dynamic> _signaturePages = {};

  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _clienteIdLocal = widget.clientId;
    _applyBudget(widget.initialBudget);
  }

  @override
  void didUpdateWidget(covariant BudgetForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientId != widget.clientId) {
      setState(() => _clienteIdLocal = widget.clientId);
    }
    if (oldWidget.initialBudget?['id'] != widget.initialBudget?['id']) {
      setState(() => _applyBudget(widget.initialBudget));
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    _notaInterna.dispose();
    _validadeProposta.dispose();
    _condicaoPagamento.dispose();
    _prazoServico.dispose();
    _validadeProdutos.dispose();
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
      _indiceItemSelecionado = _items.length - 1;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item adicionado com sucesso.')),
    );
  }

  void _applyBudget(Map<String, dynamic>? budget) {
    _items.clear();

    if (budget == null) {
      _indiceItemSelecionado = null;
      return;
    }

    if (widget.clientId == null) {
      _clienteIdLocal = budget['client_id'] as int?;
    }
    _status = budget['status']?.toString() ?? 'em_andamento';
    _notes.text = budget['notes']?.toString() ?? '';
    _notaInterna.text = budget['internal_note']?.toString() ?? '';
    _validadeProposta.text =
        budget['proposal_validity']?.toString() ?? '30 dias';
    _condicaoPagamento.text = budget['payment_terms']?.toString() ?? 'À vista';
    _prazoServico.text =
        budget['service_deadline']?.toString() ?? '03 a 04 horas';
    _validadeProdutos.text =
        budget['product_validity']?.toString() ?? '03 meses';
    _discount.text = (budget['discount'] ?? 0).toString();
    _tax.text = (budget['tax'] ?? 0).toString();
    _modoAssinatura = budget['signature_mode']?.toString() ?? 'none';
    _escopoAssinatura = budget['signature_scope']?.toString() ?? 'last_page';
    _assinaturaCliente = budget['signature_client']?.toString() ?? '';
    _assinaturaTecnico = budget['signature_tech']?.toString() ?? '';
    final pages = budget['signature_pages'];
    if (pages is Map) {
      _signaturePages = Map<String, dynamic>.from(pages);
    } else {
      _signaturePages = {};
    }
    _createdAt = budget['created_at']?.toString();

    final items =
        (budget['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    for (final item in items) {
      _items.add(BudgetItemData.fromMap(item));
    }
    _indiceItemSelecionado = _items.isEmpty ? null : 0;
  }

  Future<void> _editSelectedItem() async {
    final index = _indiceItemSelecionado;
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
      _indiceItemSelecionado = index;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item atualizado com sucesso.')),
    );
  }

  Future<void> _removeSelectedItem() async {
    final index = _indiceItemSelecionado;
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
        _indiceItemSelecionado = null;
      } else if (index == 0) {
        _indiceItemSelecionado = 0;
      } else {
        _indiceItemSelecionado = index - 1;
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item removido com sucesso.')),
    );
  }

  double _toDouble(String value) {
    if (value.contains('R\$')) {
      return converterMoeda(value);
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

    final clientId = widget.clientId ?? _clienteIdLocal;
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
      'internal_note': _notaInterna.text,
      'proposal_validity': _validadeProposta.text,
      'payment_terms': _condicaoPagamento.text,
      'service_deadline': _prazoServico.text,
      'product_validity': _validadeProdutos.text,
      'signature_mode': _modoAssinatura,
      'signature_scope': _escopoAssinatura,
      'signature_client': _assinaturaCliente,
      'signature_tech': _assinaturaTecnico,
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
            budgetId != null
                ? 'Orçamento atualizado com sucesso.'
                : 'Orçamento salvo com sucesso.',
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
                value: _clienteIdLocal,
                items: clientOptions,
                onChanged: (value) => setState(() => _clienteIdLocal = value),
              ),
            const SizedBox(height: 8),
            AppDropdownField<String>(
              label: 'Status',
              value: _status,
              items: const [
                DropdownMenuItem(value: 'aprovado', child: Text('Aprovado')),
                DropdownMenuItem(
                    value: 'em_andamento', child: Text('Em andamento')),
                DropdownMenuItem(value: 'recusado', child: Text('Recusado')),
              ],
              onChanged: (value) =>
                  setState(() => _status = value ?? 'em_andamento'),
            ),
            const SizedBox(height: 8),
            AppTextField(
              label: 'Desconto',
              controller: _discount,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              inputFormatters: [
                FormatadorEntradaMoeda(),
              ],
            ),
            const SizedBox(height: 8),
            AppTextField(
                label: 'Validade da proposta', controller: _validadeProposta),
            const SizedBox(height: 8),
            AppDropdownField<String>(
              label: 'Condição de pagamento',
              value: _condicaoPagamento.text,
              items: const [
                DropdownMenuItem(value: 'À vista', child: Text('À vista')),
                DropdownMenuItem(value: 'Parcelado', child: Text('Parcelado')),
              ],
              onChanged: (value) =>
                  setState(() => _condicaoPagamento.text = value ?? 'À vista'),
            ),
            const SizedBox(height: 8),
            AppTextField(
                label: 'Prazo de serviço', controller: _prazoServico),
            const SizedBox(height: 8),
            AppTextField(
                label: 'Validade dos produtos', controller: _validadeProdutos),
            const SizedBox(height: 8),
            AppTextField(label: 'Observações', controller: _notes, maxLines: 3),
            const SizedBox(height: 8),
            AppTextField(
                label: 'Nota interna', controller: _notaInterna, maxLines: 3),
            const SizedBox(height: 16),
            Text('Assinaturas', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            AppDropdownField<String>(
              label: 'Assinatura',
              value: _modoAssinatura,
              items: const [
                DropdownMenuItem(value: 'none', child: Text('Sem assinatura')),
                DropdownMenuItem(value: 'client', child: Text('Cliente')),
                DropdownMenuItem(value: 'tech', child: Text('Técnico')),
                DropdownMenuItem(
                    value: 'both', child: Text('Cliente e Técnico')),
              ],
              onChanged: (value) =>
                  setState(() => _modoAssinatura = value ?? 'none'),
            ),
            const SizedBox(height: 8),
            AppDropdownField<String>(
              label: 'Escopo',
              value: _escopoAssinatura,
              items: const [
                DropdownMenuItem(
                    value: 'last_page', child: Text('Assinar apenas no final')),
                DropdownMenuItem(
                    value: 'all_pages',
                    child: Text('Assinar todas as páginas')),
              ],
              onChanged: (value) {
                if (_modoAssinatura == 'none') return;
                setState(() => _escopoAssinatura = value ?? 'last_page');
              },
            ),
            if (_modoAssinatura != 'none') ...[
              const SizedBox(height: 12),
              if (_modoAssinatura == 'client' || _modoAssinatura == 'both')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SignaturePadField(
                      label: 'Assinatura do cliente',
                      value: _assinaturaCliente,
                      onChanged: (value) =>
                          setState(() => _assinaturaCliente = value),
                    ),
                    if (_assinaturaCliente.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () =>
                              setState(() => _assinaturaCliente = ''),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remover assinatura'),
                        ),
                      ),
                  ],
                ),
              if (_modoAssinatura == 'tech' || _modoAssinatura == 'both') ...[
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SignaturePadField(
                      label: 'Assinatura do Técnico',
                      value: _assinaturaTecnico,
                      onChanged: (value) =>
                          setState(() => _assinaturaTecnico = value),
                    ),
                    if (_assinaturaTecnico.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _assinaturaTecnico = ''),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remover assinatura'),
                        ),
                      ),
                  ],
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
                OutlinedButton(
                    onPressed: _addItem, child: const Text('Adicionar item')),
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
                    value: _indiceItemSelecionado,
                    items: _items.asMap().entries.map((entry) {
                      final item = entry.value;
                      final label =
                          '${entry.key + 1} - ${item.description} (Qtd: ${item.qty}, Unit: ${formatarMoeda(item.unitPrice)})';
                      return DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _indiceItemSelecionado = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: _indiceItemSelecionado == null
                            ? null
                            : _editSelectedItem,
                        child: const Text('Editar'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _indiceItemSelecionado == null
                            ? null
                            : _removeSelectedItem,
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
                Chip(label: Text('Subtotal: ${formatarMoeda(_subtotal)}')),
                Chip(label: Text('Total: ${formatarMoeda(_total)}')),
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

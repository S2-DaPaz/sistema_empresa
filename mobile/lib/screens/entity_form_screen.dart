import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/entity_refresh_service.dart';
import '../utils/entity_config.dart';
import '../utils/field_config.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/form_fields.dart';
import 'address_picker_map_screen.dart';

class EntityFormScreen extends StatefulWidget {
  const EntityFormScreen({super.key, required this.config, this.item});

  final ConfiguracaoEntidade config;
  final Map<String, dynamic>? item;

  @override
  State<EntityFormScreen> createState() => _EntityFormScreenState();
}

class _EntityFormScreenState extends State<EntityFormScreen> {
  final ApiService _api = ApiService();
  final Map<String, TextEditingController> _controladores = {};
  final Map<String, dynamic> _valores = {};
  bool _salvando = false;
  String? _erro;

  bool get _ehEdicao => widget.item != null && widget.item?['id'] != null;

  @override
  void initState() {
    super.initState();
    _inicializarCampos();
  }

  void _inicializarCampos() {
    for (final field in widget.config.fields) {
      final rawValue = widget.item?[field.name];
      switch (field.type) {
        case TipoCampo.text:
        case TipoCampo.textarea:
        case TipoCampo.number:
        case TipoCampo.date:
          _controladores[field.name] = TextEditingController(
              text: formatarEntradaData(rawValue?.toString()));
          break;
        case TipoCampo.select:
          _valores[field.name] = rawValue;
          break;
        case TipoCampo.checkbox:
          _valores[field.name] = rawValue == true;
          break;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controladores.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });

    final payload = <String, dynamic>{};
    for (final field in widget.config.fields) {
      switch (field.type) {
        case TipoCampo.text:
        case TipoCampo.textarea:
        case TipoCampo.date:
          payload[field.name] =
              converterDataBrParaIso(_controladores[field.name]?.text.trim());
          break;
        case TipoCampo.number:
          final raw = _controladores[field.name]?.text.trim();
          payload[field.name] =
              raw == null || raw.isEmpty ? 0 : num.tryParse(raw) ?? 0;
          break;
        case TipoCampo.select:
          payload[field.name] = _valores[field.name];
          break;
        case TipoCampo.checkbox:
          payload[field.name] = _valores[field.name] == true;
          break;
      }
    }

    try {
      if (_ehEdicao) {
        await _api.put(
            '${widget.config.endpoint}/${widget.item?['id']}', payload);
      } else {
        await _api.post(widget.config.endpoint, payload);
      }
      EntityRefreshService.instance.notifyChanged(widget.config.endpoint);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      setState(() => _erro = error.toString());
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  Future<void> _selecionarData(ConfiguracaoCampo field) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDate: now,
    );
    if (selected == null) return;
    final formatted = formatarDataDeDate(selected);
    _controladores[field.name]?.text = formatted;
    setState(() {});
  }

  bool _ehCampoEnderecoCliente(ConfiguracaoCampo field) {
    return widget.config.endpoint == '/clients' && field.name == 'address';
  }

  Future<void> _selecionarEnderecoNoMapa(ConfiguracaoCampo field) async {
    final controller = _controladores[field.name];
    if (controller == null) return;

    final selectedAddress = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const AddressPickerMapScreen(),
      ),
    );

    if (!mounted || selectedAddress == null || selectedAddress.trim().isEmpty) {
      return;
    }

    // Nesta primeira fase salvamos apenas o texto do endereco para manter
    // compatibilidade total com o contrato atual do CRUD de clientes.
    controller.text = selectedAddress;
    setState(() {});
  }

  Widget _buildAddressField(ConfiguracaoCampo field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: field.label,
          controller: _controladores[field.name],
          maxLines: field.type == TipoCampo.textarea ? 4 : 1,
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _selecionarEnderecoNoMapa(field),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Selecionar no mapa'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Use o mapa para preencher o endereco e ajuste manualmente se precisar.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _ehEdicao
          ? 'Editar ${widget.config.title}'
          : 'Novo ${widget.config.title}',
      body: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...widget.config.fields.map((field) {
                    Widget fieldWidget;
                    if (_ehCampoEnderecoCliente(field)) {
                      fieldWidget = _buildAddressField(field);
                    } else {
                      switch (field.type) {
                        case TipoCampo.text:
                          fieldWidget = AppTextField(
                            label: field.label,
                            controller: _controladores[field.name],
                          );
                          break;
                        case TipoCampo.textarea:
                          fieldWidget = AppTextField(
                            label: field.label,
                            controller: _controladores[field.name],
                            maxLines: 4,
                          );
                          break;
                        case TipoCampo.number:
                          fieldWidget = AppTextField(
                            label: field.label,
                            controller: _controladores[field.name],
                            keyboardType: TextInputType.number,
                          );
                          break;
                        case TipoCampo.select:
                          fieldWidget = AppDropdownField<dynamic>(
                            label: field.label,
                            value: _valores[field.name],
                            items: field.options
                                .map(
                                  (option) => DropdownMenuItem(
                                    value: option.value,
                                    child: Text(option.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _valores[field.name] = value),
                          );
                          break;
                        case TipoCampo.checkbox:
                          fieldWidget = AppCheckboxField(
                            label: field.label,
                            value: _valores[field.name] == true,
                            onChanged: (value) => setState(
                                () => _valores[field.name] = value ?? false),
                          );
                          break;
                        case TipoCampo.date:
                          fieldWidget = AppDateField(
                            key: ValueKey(_controladores[field.name]?.text ?? ''),
                            label: field.label,
                            value: formatarEntradaData(
                                _controladores[field.name]?.text ?? ''),
                            onTap: () => _selecionarData(field),
                          );
                          break;
                      }
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: fieldWidget,
                    );
                  }),
                  if (_erro != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _erro!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _salvando ? null : _salvar,
                      child: Text(_salvando ? 'Salvando...' : 'Salvar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

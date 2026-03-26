import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.inputFormatters,
    this.readOnly = false,
    this.onTap,
    this.enabled = true,
    this.hintText,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool enabled;
  final String? hintText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(text: label),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          enabled: enabled,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: suffixIcon,
          ),
          onChanged: onChanged,
          inputFormatters: inputFormatters,
        ),
      ],
    );
  }
}

class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final matches = items.where((item) => item.value == value).length;
    final safeValue = matches == 1 ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(text: label),
        DropdownButtonFormField<T>(
          initialValue: safeValue,
          items: items,
          onChanged: enabled ? onChanged : null,
          isExpanded: true,
          decoration: const InputDecoration(),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ],
    );
  }
}

class AppCheckboxField extends StatelessWidget {
  const AppCheckboxField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      initialValue: value,
      readOnly: true,
      onTap: onTap,
      hintText: 'Selecionar',
      suffixIcon: const Icon(Icons.calendar_today_outlined),
    );
  }
}

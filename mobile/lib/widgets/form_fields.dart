import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
    this.hintText,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.onTap,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final String? hintText;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final VoidCallback? onTap;
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
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          enabled: enabled,
          readOnly: readOnly,
          obscureText: obscureText,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: suffixIcon,
          ),
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
    this.hintText,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(text: label),
        DropdownButtonFormField<T>(
          key: ValueKey(value),
          initialValue: value,
          items: items,
          isExpanded: true,
          hint: hintText == null ? null : Text(hintText!),
          onChanged: onChanged,
          selectedItemBuilder: (context) => items.map((item) {
            final child = item.child;
            if (child is Text) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  child.data ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: child.style,
                ),
              );
            }
            return child;
          }).toList(),
          decoration: const InputDecoration(),
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: CheckboxListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        value: value,
        onChanged: onChanged,
        title: Text(label),
        controlAffinity: ListTileControlAffinity.leading,
      ),
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
      hintText: 'Selecione uma data',
      suffixIcon: const Icon(Icons.calendar_today_outlined),
    );
  }
}

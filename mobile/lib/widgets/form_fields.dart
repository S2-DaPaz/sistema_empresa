import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.labelLarge;
    final color = theme.colorScheme.primary.withValues(alpha: 0.9);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        softWrap: true,
        style: baseStyle?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ) ??
            TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
            ),
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
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

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
          decoration: const InputDecoration(),
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
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

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
          onChanged: onChanged,
          isExpanded: true,
          selectedItemBuilder: (context) => items.map((item) {
            final child = item.child;
            if (child is Text) {
              return Text(
                child.data ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: child.style,
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
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(label),
      controlAffinity: ListTileControlAffinity.leading,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(text: label),
        TextFormField(
          readOnly: true,
          decoration: const InputDecoration(),
          initialValue: value,
          onTap: onTap,
        ),
      ],
    );
  }
}

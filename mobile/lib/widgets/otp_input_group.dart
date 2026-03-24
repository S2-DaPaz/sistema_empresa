import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';

class OtpInputGroup extends StatefulWidget {
  const OtpInputGroup({
    super.key,
    required this.length,
    required this.value,
    required this.onChanged,
  });

  final int length;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<OtpInputGroup> createState() => _OtpInputGroupState();
}

class _OtpInputGroupState extends State<OtpInputGroup> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant OtpInputGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final digits = widget.value.padRight(widget.length).split('');
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: _focusNode.requestFocus,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.length, (index) {
              final char = digits[index].trim();
              final hasValue = char.isNotEmpty;
              return Container(
                width: 44,
                height: 56,
                decoration: BoxDecoration(
                  color: hasValue
                      ? theme.colorScheme.primary.withValues(alpha: 0.08)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: hasValue
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  char,
                  style: theme.textTheme.titleLarge,
                ),
              );
            }),
          ),
          Opacity(
            opacity: 0.02,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              onChanged: widget.onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

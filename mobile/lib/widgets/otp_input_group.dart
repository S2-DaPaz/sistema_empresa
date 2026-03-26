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
  late final TextEditingController _controlador;
  late final FocusNode _noFoco;

  @override
  void initState() {
    super.initState();
    _controlador = TextEditingController(text: widget.value);
    _noFoco = FocusNode();
  }

  @override
  void didUpdateWidget(covariant OtpInputGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controlador.text) {
      _controlador.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    _noFoco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final digits = widget.value.padRight(widget.length).split('');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: _noFoco.requestFocus,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.length, (index) {
              final char = digits[index].trim();
              final hasValue = char.isNotEmpty;
              return Container(
                width: 46,
                height: 58,
                decoration: BoxDecoration(
                  color: hasValue
                      ? theme.colorScheme.primary.withValues(
                          alpha: isDark ? 0.16 : 0.08,
                        )
                      : (isDark
                          ? AppDarkColors.surface2.withValues(alpha: 0.9)
                          : theme.colorScheme.surface),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: hasValue
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withValues(
                            alpha: isDark ? 0.82 : 1,
                          ),
                  ),
                  boxShadow: hasValue && isDark ? AppShadows.darkGlow : const [],
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
              controller: _controlador,
              focusNode: _noFoco,
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

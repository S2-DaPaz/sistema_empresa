import 'package:flutter/material.dart';

import 'app_ui.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.color,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AppStatusPill(label: label, color: color);
  }
}

import 'package:flutter/material.dart';

import 'app_ui.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppSectionBlock(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    );
  }
}

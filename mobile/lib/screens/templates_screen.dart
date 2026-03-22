import 'package:flutter/material.dart';

import 'template_management_screen.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TemplateManagementScreen(initialTab: TemplateTab.templates);
  }
}

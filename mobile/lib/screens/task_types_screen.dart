import 'package:flutter/material.dart';

import 'template_management_screen.dart';

class TaskTypesScreen extends StatelessWidget {
  const TaskTypesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TemplateManagementScreen(initialTab: TemplateTab.taskTypes);
  }
}

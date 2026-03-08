import 'package:flutter/material.dart';

import '../core/contracts/domain_options.dart';
import '../core/contracts/generated/domain_options.g.dart';

List<DropdownMenuItem<String>> buildDomainOptionItems(
    List<DomainOption> options) {
  return options
      .map(
        (option) => DropdownMenuItem<String>(
          value: option.value,
          child: Text(option.label),
        ),
      )
      .toList();
}

class TaskDetailOptions {
  static final List<DropdownMenuItem<String>> taskStatusItems =
      buildDomainOptionItems(DomainOptions.taskStatus);

  static final List<DropdownMenuItem<String>> taskPriorityItems =
      buildDomainOptionItems(DomainOptions.taskPriority);

  static final List<DropdownMenuItem<String>> reportStatusItems =
      buildDomainOptionItems(DomainOptions.reportStatus);

  static final List<DropdownMenuItem<String>> signatureModeItems =
      buildDomainOptionItems(DomainOptions.signatureMode);

  static final List<DropdownMenuItem<String>> signatureScopeItems =
      buildDomainOptionItems(DomainOptions.signatureScope);
}

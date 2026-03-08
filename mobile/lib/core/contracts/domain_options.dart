import 'generated/domain_options.g.dart';

class DomainOptions {
  static List<DomainOption> get taskStatus =>
      kDomainOptions['taskStatus'] ?? [];
  static List<DomainOption> get taskPriority =>
      kDomainOptions['taskPriority'] ?? [];
  static List<DomainOption> get reportStatus =>
      kDomainOptions['reportStatus'] ?? [];
  static List<DomainOption> get budgetStatus =>
      kDomainOptions['budgetStatus'] ?? [];
  static List<DomainOption> get signatureMode =>
      kDomainOptions['signatureMode'] ?? [];
  static List<DomainOption> get signatureScope =>
      kDomainOptions['signatureScope'] ?? [];
}

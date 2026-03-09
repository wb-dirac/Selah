import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_installer.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_security_scanner.dart';

void main() {
  group('SkillInstallResult', () {
    test('outcome passed has no criticals or warnings', () {
      final result = SkillInstallResult(
        outcome: ScanOutcome.passed,
        skillName: 'my-skill',
        version: '1.0.0',
        steps: const <InstallStep>[],
        findings: const <ScanFinding>[],
      );
      expect(result.outcome, ScanOutcome.passed);
      expect(result.criticals, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('outcome warning has warning findings but no criticals', () {
      final result = SkillInstallResult(
        outcome: ScanOutcome.warning,
        skillName: 'my-skill',
        version: '1.0.0',
        steps: const <InstallStep>[],
        findings: <ScanFinding>[
          const ScanFinding(
            severity: ScanSeverity.warning,
            category: ScanCategory.fileSystem,
            message: '检测到 open() 调用',
          ),
        ],
      );
      expect(result.outcome, ScanOutcome.warning);
      expect(result.warnings, hasLength(1));
      expect(result.criticals, isEmpty);
    });

    test('outcome rejected has critical findings', () {
      final result = SkillInstallResult(
        outcome: ScanOutcome.rejected,
        skillName: 'evil-skill',
        version: '0.1.0',
        steps: const <InstallStep>[],
        findings: <ScanFinding>[
          const ScanFinding(
            severity: ScanSeverity.critical,
            category: ScanCategory.networkAccess,
            message: '检测到 import socket',
          ),
        ],
      );
      expect(result.outcome, ScanOutcome.rejected);
      expect(result.criticals, hasLength(1));
    });
  });

  group('InstallStep', () {
    test('copyWith changes status', () {
      const step = InstallStep(
        label: '下载 Skill 包',
        status: InstallStepStatus.pending,
      );
      final updated = step.copyWith(status: InstallStepStatus.passed);
      expect(updated.label, step.label);
      expect(updated.status, InstallStepStatus.passed);
    });

    test('copyWith without args preserves status', () {
      const step = InstallStep(
        label: '解压校验',
        status: InstallStepStatus.running,
      );
      final same = step.copyWith();
      expect(same.status, InstallStepStatus.running);
    });
  });

  group('ScanOutcome', () {
    test('passed is distinct from warning and rejected', () {
      expect(ScanOutcome.passed, isNot(ScanOutcome.warning));
      expect(ScanOutcome.passed, isNot(ScanOutcome.rejected));
      expect(ScanOutcome.warning, isNot(ScanOutcome.rejected));
    });
  });
}

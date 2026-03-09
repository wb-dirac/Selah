import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_manifest_parser.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_security_scanner.dart';

enum InstallStepStatus { pending, running, passed, failed }

class InstallStep {
  const InstallStep({required this.label, required this.status});

  final String label;
  final InstallStepStatus status;

  InstallStep copyWith({InstallStepStatus? status}) =>
      InstallStep(label: label, status: status ?? this.status);
}

enum ScanOutcome { passed, warning, rejected }

class SkillInstallResult {
  const SkillInstallResult({
    required this.outcome,
    required this.skillName,
    required this.version,
    required this.steps,
    this.findings = const <ScanFinding>[],
    this.installedPath,
  });

  final ScanOutcome outcome;
  final String skillName;
  final String version;
  final List<InstallStep> steps;
  final List<ScanFinding> findings;
  final String? installedPath;

  List<ScanFinding> get warnings =>
      findings.where((f) => f.severity == ScanSeverity.warning).toList();
  List<ScanFinding> get criticals =>
      findings.where((f) => f.severity == ScanSeverity.critical).toList();
}

typedef InstallProgressCallback = void Function(List<InstallStep> steps);

class SkillInstaller {
  const SkillInstaller();

  static const _scanner = SkillSecurityScanner();
  static const _parser = SkillManifestParser();

  Future<SkillInstallResult> installFromUrl(
    String packageUrl, {
    InstallProgressCallback? onProgress,
  }) async {
    final steps = <InstallStep>[
      const InstallStep(label: '下载 Skill 包', status: InstallStepStatus.pending),
      const InstallStep(label: '解压校验结构', status: InstallStepStatus.pending),
      const InstallStep(label: 'SKILL.md 格式校验', status: InstallStepStatus.pending),
      const InstallStep(label: '脚本静态扫描', status: InstallStepStatus.pending),
      const InstallStep(label: 'Prompt 注入检测', status: InstallStepStatus.pending),
    ];

    void report(int idx, InstallStepStatus status) {
      steps[idx] = steps[idx].copyWith(status: status);
      onProgress?.call(List.unmodifiable(steps));
    }

    final tempDir = await getTemporaryDirectory();
    final workDir = Directory(
      p.join(tempDir.path, 'skill_install_${DateTime.now().millisecondsSinceEpoch}'),
    )..createSync(recursive: true);

    try {
      report(0, InstallStepStatus.running);
      final zipBytes = await _downloadBytes(packageUrl);
      if (zipBytes == null) {
        report(0, InstallStepStatus.failed);
        return _rejected('未知', '', steps, const <ScanFinding>[]);
      }
      report(0, InstallStepStatus.passed);

      report(1, InstallStepStatus.running);
      final extractDir = await _extractZip(zipBytes, workDir);
      if (extractDir == null) {
        report(1, InstallStepStatus.failed);
        return _rejected('未知', '', steps, const <ScanFinding>[]);
      }
      final skillMdFile = File(p.join(extractDir.path, 'SKILL.md'));
      if (!skillMdFile.existsSync()) {
        report(1, InstallStepStatus.failed);
        return _rejected('未知', '', steps, const <ScanFinding>[]);
      }
      report(1, InstallStepStatus.passed);

      report(2, InstallStepStatus.running);
      final skillMdContent = await skillMdFile.readAsString();
      final manifestResult = _parser.parse(skillMdContent);
      if (!manifestResult.isSuccess) {
        report(2, InstallStepStatus.failed);
        return _rejected('未知', '', steps, const <ScanFinding>[]);
      }
      final manifest = manifestResult.manifest!;
      report(2, InstallStepStatus.passed);

      report(3, InstallStepStatus.running);
      final pythonFiles = await _collectFiles(extractDir, ['.py']);
      final shellFiles = await _collectFiles(extractDir, ['.sh']);
      final pyResult = _scanner.scanSkillDirectory(
        pythonFiles: pythonFiles,
        promptFiles: const <String, String>{},
        shellFiles: shellFiles,
      );
      if (pyResult.criticalFindings.isNotEmpty) {
        report(3, InstallStepStatus.failed);
        return _rejected(
          manifest.name,
          manifest.version ?? '',
          steps,
          pyResult.findings,
        );
      }
      report(3, pyResult.warnings.isNotEmpty
          ? InstallStepStatus.failed
          : InstallStepStatus.passed);

      report(4, InstallStepStatus.running);
      final promptFiles = await _collectFiles(extractDir, ['.md', '.txt']);
      final promptResult = _scanner.scanSkillDirectory(
        pythonFiles: const <String, String>{},
        promptFiles: promptFiles,
      );
      final allFindings = <ScanFinding>[
        ...pyResult.findings,
        ...promptResult.findings,
      ];

      if (promptResult.criticalFindings.isNotEmpty) {
        report(4, InstallStepStatus.failed);
        return _rejected(manifest.name, manifest.version ?? '', steps, allFindings);
      }
      report(4, InstallStepStatus.passed);

      final destDir = await _installToSkillsDir(extractDir, manifest.name);

      final outcome = allFindings.any((f) => f.severity == ScanSeverity.warning)
          ? ScanOutcome.warning
          : ScanOutcome.passed;

      return SkillInstallResult(
        outcome: outcome,
        skillName: manifest.name,
        version: manifest.version ?? '',
        steps: List.unmodifiable(steps),
        findings: allFindings,
        installedPath: destDir,
      );
    } finally {
      workDir.deleteSync(recursive: true);
    }
  }

  Future<List<int>?> _downloadBytes(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return response.bodyBytes;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Directory?> _extractZip(List<int> bytes, Directory workDir) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final extractDir = Directory(p.join(workDir.path, 'extracted'))
        ..createSync();
      await extractArchiveToDiskAsync(archive, extractDir.path);
      final topLevel = extractDir
          .listSync()
          .whereType<Directory>()
          .toList();
      if (topLevel.length == 1) return topLevel.first;
      return extractDir;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _collectFiles(
    Directory dir,
    List<String> extensions,
  ) async {
    final result = <String, String>{};
    if (!dir.existsSync()) return result;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (extensions.contains(ext)) {
          final content = await entity.readAsString();
          final rel = p.relative(entity.path, from: dir.path);
          result[rel] = content;
        }
      }
    }
    return result;
  }

  Future<String> _installToSkillsDir(Directory src, String skillName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dest = Directory(p.join(appDir.path, 'skills', skillName));
    if (dest.existsSync()) dest.deleteSync(recursive: true);
    await _copyDir(src, dest);
    return dest.path;
  }

  Future<void> _copyDir(Directory src, Directory dest) async {
    dest.createSync(recursive: true);
    await for (final entity in src.list()) {
      final target = p.join(dest.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(target);
      } else if (entity is Directory) {
        await _copyDir(entity, Directory(target));
      }
    }
  }

  SkillInstallResult _rejected(
    String name,
    String version,
    List<InstallStep> steps,
    List<ScanFinding> findings,
  ) {
    return SkillInstallResult(
      outcome: ScanOutcome.rejected,
      skillName: name,
      version: version,
      steps: List.unmodifiable(steps),
      findings: findings,
    );
  }
}

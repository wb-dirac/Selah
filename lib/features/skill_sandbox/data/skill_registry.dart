import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/data/skill_sandbox_factory.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_loader.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_record.dart';

class SkillRegistryState {
  const SkillRegistryState({
    this.skills = const <SkillRecord>[],
    this.isLoading = false,
  });

  final List<SkillRecord> skills;
  final bool isLoading;

  SkillRecord? findById(String id) {
    try {
      return skills.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  SkillRegistryState copyWith({
    List<SkillRecord>? skills,
    bool? isLoading,
  }) {
    return SkillRegistryState(
      skills: skills ?? this.skills,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SkillRegistryNotifier extends Notifier<SkillRegistryState> {
  static const _loader = SkillLoader();

  @override
  SkillRegistryState build() => const SkillRegistryState();

  Future<void> scanAll() async {
    state = state.copyWith(isLoading: true);
    try {
      final root = await _skillsRoot();
      final records = await _loader.scanDirectory(root);
      state = SkillRegistryState(skills: records);
    } catch (_) {
      state = const SkillRegistryState();
    }
  }

  Future<void> upgradeToLevel2(String skillId) async {
    final current = state.findById(skillId);
    if (current == null) return;
    if (current.loadedLevel.index >= SkillLoadLevel.level2.index) return;

    final upgraded = await _loader.loadLevel2(current);
    if (upgraded == null) return;
    _replace(upgraded);
  }

  Future<void> upgradeToLevel3(String skillId) async {
    final current = state.findById(skillId);
    if (current == null) return;
    if (current.loadedLevel.index >= SkillLoadLevel.level3.index) return;

    final upgraded = await _loader.loadLevel3(current);
    if (upgraded == null) return;

    final level3 = upgraded.level3;
    if (level3 != null) {
      final hasExecutableScripts = level3.executableAssets.keys.any(
        (filename) => SkillSandboxFactory.canHandle(filename),
      );
      if (hasExecutableScripts && !level3.isRuntimeReady) {
        final updatedLevel3 = SkillLevel3(
          id: level3.id,
          manifest: level3.manifest,
          rootPath: level3.rootPath,
          enabled: level3.enabled,
          toolDefinitions: level3.toolDefinitions,
          systemPromptTemplate: level3.systemPromptTemplate,
          readmeContent: level3.readmeContent,
          executableAssets: level3.executableAssets,
          isRuntimeReady: true,
        );
        final runtimeReadyRecord =
            SkillRecord(level1: updatedLevel3).withLevel3(updatedLevel3);
        _replace(runtimeReadyRecord);
        return;
      }
    }

    _replace(upgraded);
  }

  void setEnabled(String skillId, {required bool enabled}) {
    final current = state.findById(skillId);
    if (current == null) return;
    final updated = SkillRecord(
      level1: SkillLevel1(
        id: current.level1.id,
        manifest: current.level1.manifest,
        rootPath: current.level1.rootPath,
        enabled: enabled,
      ),
    );
    _replace(updated);
  }

  void removeSkill(String skillId) {
    final list = state.skills.where((s) => s.id != skillId).toList();
    state = state.copyWith(skills: list);
  }

  void _replace(SkillRecord updated) {
    final list = List<SkillRecord>.from(state.skills);
    final idx = list.indexWhere((s) => s.id == updated.id);
    if (idx >= 0) {
      list[idx] = updated;
    } else {
      list.add(updated);
    }
    state = state.copyWith(skills: list);
  }

  Future<String> _skillsRoot() async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, 'skills');
  }
}

final skillRegistryProvider =
    NotifierProvider<SkillRegistryNotifier, SkillRegistryState>(() {
  return SkillRegistryNotifier();
});

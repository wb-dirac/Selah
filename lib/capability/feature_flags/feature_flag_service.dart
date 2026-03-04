import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppFeatureModule {
  llmGateway,
  multimodalChat,
  generativeUi,
  toolBridge,
  agentSkill,
  backgroundTasks,
  a2aProtocol,
  privacyStorage,
}

class FeatureFlagService {
  FeatureFlagService([Map<AppFeatureModule, bool>? initialFlags])
      : _flags = initialFlags ??
            {
              AppFeatureModule.llmGateway: true,
              AppFeatureModule.multimodalChat: true,
              AppFeatureModule.generativeUi: true,
              AppFeatureModule.toolBridge: true,
              AppFeatureModule.agentSkill: false,
              AppFeatureModule.backgroundTasks: false,
              AppFeatureModule.a2aProtocol: false,
              AppFeatureModule.privacyStorage: true,
            };

  final Map<AppFeatureModule, bool> _flags;

  bool isEnabled(AppFeatureModule module) => _flags[module] ?? false;

  void setEnabled(AppFeatureModule module, bool enabled) {
    _flags[module] = enabled;
  }

  Map<AppFeatureModule, bool> snapshot() => Map.unmodifiable(_flags);
}

final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  return FeatureFlagService();
});

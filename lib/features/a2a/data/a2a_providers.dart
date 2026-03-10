import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personal_ai_assistant/features/a2a/data/a2a_host_client.dart';
import 'package:personal_ai_assistant/features/a2a/data/a2a_remote_server.dart';
import 'package:personal_ai_assistant/features/a2a/data/a2a_sandbox_processor.dart';
import 'package:personal_ai_assistant/features/a2a/data/agent_auth_service.dart';
import 'package:personal_ai_assistant/features/a2a/data/tls_connection_policy.dart';
import 'package:personal_ai_assistant/features/a2a/domain/agent_card.dart';

final _tlsPolicyProvider = Provider<TlsConnectionPolicy>(
  (_) => const TlsConnectionPolicy(),
);

final _sandboxProvider = Provider<A2ASandboxProcessor>(
  (_) => const A2ASandboxProcessor(),
);

final a2aHostClientProvider = Provider<A2AHostClient>((ref) {
  final tls = ref.watch(_tlsPolicyProvider);
  final sandbox = ref.watch(_sandboxProvider);
  return A2AHostClient(tls, sandbox);
});

// The self-describing AgentCard advertised by this app when acting as a server.
final _localAgentCardProvider = Provider<AgentCard>((_) {
  return const AgentCard(
    name: 'Personal AI Assistant',
    url: 'https://localhost:7890/a2a',
    description: '个人 AI 助理 A2A 端点，对外暴露本地 Agent 技能。',
    version: '1.0.0',
    capabilities: AgentCapabilities(
      streaming: false,
      pushNotifications: false,
      stateTransitionHistory: false,
    ),
    skills: <AgentSkill>[
      AgentSkill(
        id: 'chat',
        name: '对话',
        description: '与本地 AI 助理对话',
      ),
    ],
  );
});

final a2aRemoteServerProvider = Provider<A2ARemoteServer>((ref) {
  final card = ref.watch(_localAgentCardProvider);
  return A2ARemoteServer(
    card,
    (String skillId, Map<String, dynamic> input) async {
      // Default skill handler: echo input back.
      // Replace with real skill dispatch when assistant LLM is wired in.
      final text = input['text'] as String? ?? '';
      return '已收到: $text';
    },
  );
});

final _secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  ),
);

final agentAuthServiceProvider = Provider<AgentAuthService>((ref) {
  final storage = ref.watch(_secureStorageProvider);
  return AgentAuthService(storage);
});

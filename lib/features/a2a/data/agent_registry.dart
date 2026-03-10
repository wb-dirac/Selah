import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/a2a/data/a2a_host_client.dart';
import 'package:personal_ai_assistant/features/a2a/data/a2a_remote_server.dart';
import 'package:personal_ai_assistant/features/a2a/data/agent_auth_service.dart';
import 'package:personal_ai_assistant/features/a2a/data/mdns_discovery_service.dart';
import 'package:personal_ai_assistant/features/a2a/domain/a2a_result.dart';
import 'package:personal_ai_assistant/features/a2a/domain/a2a_task.dart';
import 'package:personal_ai_assistant/features/a2a/domain/agent_card.dart';
import 'package:personal_ai_assistant/features/a2a/domain/discovered_agent.dart';

class AgentRegistryState {
  const AgentRegistryState({
    this.connected = const <ConnectedAgent>[],
    this.discovered = const <DiscoveredAgent>[],
    this.isScanning = false,
    this.isRemoteEnabled = false,
    this.remoteServerPort = 7890,
  });

  final List<ConnectedAgent> connected;
  final List<DiscoveredAgent> discovered;
  final bool isScanning;
  final bool isRemoteEnabled;
  final int remoteServerPort;

  List<DiscoveredAgent> get unconnectedDiscovered {
    final connectedUrls = connected.map((a) => a.card.url).toSet();
    return discovered
        .where((d) => !connectedUrls.contains(d.a2aUrl))
        .toList();
  }

  AgentRegistryState copyWith({
    List<ConnectedAgent>? connected,
    List<DiscoveredAgent>? discovered,
    bool? isScanning,
    bool? isRemoteEnabled,
    int? remoteServerPort,
  }) {
    return AgentRegistryState(
      connected: connected ?? this.connected,
      discovered: discovered ?? this.discovered,
      isScanning: isScanning ?? this.isScanning,
      isRemoteEnabled: isRemoteEnabled ?? this.isRemoteEnabled,
      remoteServerPort: remoteServerPort ?? this.remoteServerPort,
    );
  }
}

class AgentRegistryNotifier extends Notifier<AgentRegistryState> {
  @override
  AgentRegistryState build() => const AgentRegistryState();

  void startDiscovery(MdnsDiscoveryService service) {
    state = state.copyWith(isScanning: true);
    service.discover().listen(
      addDiscoveredAgent,
      onDone: () => state = state.copyWith(isScanning: false),
    );
  }

  void stopDiscovery(MdnsDiscoveryService service) {
    service.stopDiscovery();
    state = state.copyWith(isScanning: false);
  }

  void addDiscoveredAgent(DiscoveredAgent agent) {
    final exists = state.discovered.any((d) => d.id == agent.id);
    if (!exists) {
      state = state.copyWith(
        discovered: [...state.discovered, agent],
      );
    }
  }

  void addAgent(AgentCard card, AgentSource source) {
    final alreadyConnected =
        state.connected.any((a) => a.card.url == card.url);
    if (alreadyConnected) return;

    state = state.copyWith(
      connected: [
        ...state.connected,
        ConnectedAgent(
          card: card,
          source: source,
          status: AgentConnectionStatus.unknown,
        ),
      ],
    );
  }

  void removeAgent(String agentUrl) {
    state = state.copyWith(
      connected:
          state.connected.where((a) => a.card.url != agentUrl).toList(),
    );
  }

  void updateStatus(String agentUrl, AgentConnectionStatus status) {
    final updated = state.connected.map((a) {
      if (a.card.url == agentUrl) return a.copyWith(status: status);
      return a;
    }).toList();
    state = state.copyWith(connected: updated);
  }

  void recordCall(String agentUrl) {
    final updated = state.connected.map((a) {
      if (a.card.url == agentUrl) {
        return a.copyWith(lastCalledAt: DateTime.now());
      }
      return a;
    }).toList();
    state = state.copyWith(connected: updated);
  }

  Future<A2ASandboxOutcome> sendTask(
    A2ATask task,
    A2AHostClient hostClient,
    AgentAuthService authService,
  ) async {
    final bearerToken = await authService.getApiKey(task.agentUrl);
    final outcome = await hostClient.sendTask(task, bearerToken: bearerToken);
    recordCall(task.agentUrl);
    return outcome;
  }

  Future<AgentCardValidationResult> addAgentFromUrl(
    String agentCardUrl,
    A2AHostClient hostClient,
  ) async {
    final result = await hostClient.fetchAgentCard(agentCardUrl);
    if (result is AgentCardValid) {
      addAgent(result.card, AgentSource.manual);
    }
    return result;
  }

  Future<void> setRemoteEnabled(
    bool enabled,
    A2ARemoteServer server,
  ) async {
    if (enabled && !server.isRunning) {
      await server.start(port: state.remoteServerPort);
    } else if (!enabled && server.isRunning) {
      await server.stop();
    }
    state = state.copyWith(isRemoteEnabled: enabled);
  }

  Future<void> setRemotePort(
    int port,
    A2ARemoteServer server,
  ) async {
    state = state.copyWith(remoteServerPort: port);
    if (server.isRunning) {
      await server.stop();
      await server.start(port: port);
    }
  }
}

final agentRegistryProvider =
    NotifierProvider<AgentRegistryNotifier, AgentRegistryState>(
  AgentRegistryNotifier.new,
);

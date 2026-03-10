import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/a2a/data/mdns_discovery_service.dart';
import 'package:personal_ai_assistant/features/a2a/domain/agent_card.dart';
import 'package:personal_ai_assistant/features/a2a/domain/discovered_agent.dart';

class AgentRegistryState {
  const AgentRegistryState({
    this.connected = const <ConnectedAgent>[],
    this.discovered = const <DiscoveredAgent>[],
    this.isScanning = false,
  });

  final List<ConnectedAgent> connected;
  final List<DiscoveredAgent> discovered;
  final bool isScanning;

  List<DiscoveredAgent> get unconnectedDiscovered {
    final connectedUrls =
        connected.map((a) => a.card.url).toSet();
    return discovered
        .where((d) => !connectedUrls.contains(d.a2aUrl))
        .toList();
  }

  AgentRegistryState copyWith({
    List<ConnectedAgent>? connected,
    List<DiscoveredAgent>? discovered,
    bool? isScanning,
  }) {
    return AgentRegistryState(
      connected: connected ?? this.connected,
      discovered: discovered ?? this.discovered,
      isScanning: isScanning ?? this.isScanning,
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
}

final agentRegistryProvider =
    NotifierProvider<AgentRegistryNotifier, AgentRegistryState>(
  AgentRegistryNotifier.new,
);

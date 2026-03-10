import 'package:personal_ai_assistant/features/a2a/domain/agent_card.dart';

enum AgentSource { lan, internet, manual }

enum AgentConnectionStatus { online, offline, unknown }

class DiscoveredAgent {
  const DiscoveredAgent({
    required this.id,
    required this.host,
    required this.port,
    required this.source,
    this.deviceName,
  });

  final String id;
  final String host;
  final int port;
  final AgentSource source;
  final String? deviceName;

  String get a2aUrl => 'https://$host:$port/a2a';
}

class ConnectedAgent {
  const ConnectedAgent({
    required this.card,
    required this.source,
    this.status = AgentConnectionStatus.unknown,
    this.lastCalledAt,
  });

  final AgentCard card;
  final AgentSource source;
  final AgentConnectionStatus status;
  final DateTime? lastCalledAt;

  ConnectedAgent copyWith({
    AgentConnectionStatus? status,
    DateTime? lastCalledAt,
  }) {
    return ConnectedAgent(
      card: card,
      source: source,
      status: status ?? this.status,
      lastCalledAt: lastCalledAt ?? this.lastCalledAt,
    );
  }
}

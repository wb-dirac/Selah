import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/a2a/data/agent_registry.dart';
import 'package:personal_ai_assistant/features/a2a/data/mdns_discovery_service.dart';
import 'package:personal_ai_assistant/features/a2a/domain/agent_card.dart';
import 'package:personal_ai_assistant/features/a2a/domain/discovered_agent.dart';

const _card = AgentCard(
  name: '铁路查询 Agent',
  url: 'https://rail-agent.local:8080/a2a',
  capabilities: AgentCapabilities(streaming: true),
  skills: <AgentSkill>[
    AgentSkill(id: 'schedule', name: '查询班次', description: '查询高铁班次'),
  ],
);

AgentRegistryNotifier _notifier(ProviderContainer c) =>
    c.read(agentRegistryProvider.notifier);

AgentRegistryState _state(ProviderContainer c) =>
    c.read(agentRegistryProvider);

void main() {
  group('AgentRegistry — connected agents', () {
    test('starts empty', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(_state(c).connected, isEmpty);
      expect(_state(c).discovered, isEmpty);
    });

    test('addAgent connects agent', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifier(c).addAgent(_card, AgentSource.lan);
      expect(_state(c).connected, hasLength(1));
      expect(_state(c).connected.first.card.name, '铁路查询 Agent');
    });

    test('addAgent deduplicates by url', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifier(c).addAgent(_card, AgentSource.lan);
      _notifier(c).addAgent(_card, AgentSource.lan);
      expect(_state(c).connected, hasLength(1));
    });

    test('removeAgent disconnects agent', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifier(c).addAgent(_card, AgentSource.lan);
      _notifier(c).removeAgent(_card.url);
      expect(_state(c).connected, isEmpty);
    });

    test('updateStatus changes connection status', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifier(c).addAgent(_card, AgentSource.lan);
      _notifier(c).updateStatus(_card.url, AgentConnectionStatus.online);
      expect(
        _state(c).connected.first.status,
        AgentConnectionStatus.online,
      );
    });

    test('recordCall sets lastCalledAt', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final before = DateTime.now();
      _notifier(c).addAgent(_card, AgentSource.lan);
      _notifier(c).recordCall(_card.url);
      expect(_state(c).connected.first.lastCalledAt, isNotNull);
      expect(
        !_state(c).connected.first.lastCalledAt!.isBefore(before),
        isTrue,
      );
    });
  });

  group('AgentRegistry — mDNS discovery', () {
    test('addDiscoveredAgent adds agent to discovered list', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      const agent = DiscoveredAgent(
        id: 'home-assistant',
        host: '192.168.1.10',
        port: 8080,
        source: AgentSource.lan,
        deviceName: 'MacBook-Pro',
      );

      _notifier(c).addDiscoveredAgent(agent);
      expect(_state(c).discovered, hasLength(1));
      expect(_state(c).discovered.first.deviceName, 'MacBook-Pro');
    });

    test('unconnectedDiscovered excludes already-connected agents', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      const discovered = DiscoveredAgent(
        id: 'rail',
        host: 'rail-agent.local',
        port: 8080,
        source: AgentSource.lan,
      );

      _notifier(c).addDiscoveredAgent(discovered);
      _notifier(c).addAgent(_card, AgentSource.lan);

      expect(_state(c).unconnectedDiscovered, isEmpty);
    });

    test('addDiscoveredAgent deduplicates by id', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      const agent = DiscoveredAgent(
        id: 'dup',
        host: '10.0.0.1',
        port: 9000,
        source: AgentSource.lan,
      );

      _notifier(c).addDiscoveredAgent(agent);
      _notifier(c).addDiscoveredAgent(agent);
      expect(_state(c).discovered, hasLength(1));
    });

    test('StubMdnsDiscoveryService emits no agents', () async {
      final service = StubMdnsDiscoveryService();
      final agents = await service.discover().toList();
      expect(agents, isEmpty);
    });
  });

  group('DiscoveredAgent', () {
    test('a2aUrl builds correct https URL', () {
      const agent = DiscoveredAgent(
        id: 'x',
        host: '192.168.1.5',
        port: 8080,
        source: AgentSource.lan,
      );
      expect(agent.a2aUrl, 'https://192.168.1.5:8080/a2a');
    });
  });
}


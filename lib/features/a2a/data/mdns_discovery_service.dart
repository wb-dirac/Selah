import 'package:personal_ai_assistant/features/a2a/domain/discovered_agent.dart';

abstract class MdnsDiscoveryService {
  Stream<DiscoveredAgent> discover();

  void stopDiscovery();
}

class StubMdnsDiscoveryService implements MdnsDiscoveryService {
  @override
  Stream<DiscoveredAgent> discover() {
    return const Stream<DiscoveredAgent>.empty();
  }

  @override
  void stopDiscovery() {}
}

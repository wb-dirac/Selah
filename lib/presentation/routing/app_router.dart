import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/features/conversation/presentation/screens/conversation_list_screen.dart';
import 'package:personal_ai_assistant/presentation/screens/agent/agent_screen.dart';
import 'package:personal_ai_assistant/presentation/screens/chat/chat_screen.dart';
import 'package:personal_ai_assistant/presentation/screens/settings/provider_management_screen.dart';
import 'package:personal_ai_assistant/presentation/screens/settings/provider_routing_screen.dart';
import 'package:personal_ai_assistant/presentation/screens/settings/proxy_settings_screen.dart';
import 'package:personal_ai_assistant/presentation/screens/settings/settings_screen.dart';
import 'package:personal_ai_assistant/presentation/screens/tasks/tasks_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/chat',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _AppScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                name: 'chat',
                builder: (context, state) => const ChatScreen(),
                routes: [
                  GoRoute(
                    path: 'history',
                    name: 'chat-history',
                    builder: (context, state) => const ConversationListScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tasks',
                name: 'tasks',
                builder: (context, state) => const TasksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/agents',
                name: 'agents',
                builder: (context, state) => const AgentScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'providers',
                    name: 'settings-providers',
                    builder: (context, state) => const ProviderManagementScreen(),
                  ),
                  GoRoute(
                    path: 'routing',
                    name: 'settings-routing',
                    builder: (context, state) => const ProviderRoutingScreen(),
                  ),
                  GoRoute(
                    path: 'proxy',
                    name: 'settings-proxy',
                    builder: (context, state) => const ProxySettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _AppScaffold extends StatelessWidget {
  const _AppScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: '对话'),
    NavigationDestination(icon: Icon(Icons.checklist_outlined), label: '任务'),
    NavigationDestination(icon: Icon(Icons.hub_outlined), label: 'Agent'),
    NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置'),
  ];

  static const _railDestinations = [
    NavigationRailDestination(
      icon: Icon(Icons.chat_bubble_outline),
      label: Text('对话'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.checklist_outlined),
      label: Text('任务'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.hub_outlined),
      label: Text('Agent'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      label: Text('设置'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _onTap,
                  destinations: _railDestinations,
                  labelType: NavigationRailLabelType.all,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }
        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            destinations: _destinations,
            onDestinationSelected: _onTap,
          ),
        );
      },
    );
  }

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

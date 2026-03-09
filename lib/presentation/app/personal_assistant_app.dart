import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/accessibility/data/accessibility_settings_service.dart';

import 'package:personal_ai_assistant/presentation/routing/app_router.dart';
import 'package:personal_ai_assistant/presentation/theme/app_theme.dart';

class PersonalAssistantApp extends ConsumerWidget {
  const PersonalAssistantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(accessibilitySettingsProvider).asData?.value ?? 
        const AccessibilitySettings();
    return MaterialApp.router(
      title: 'Personal AI Assistant',
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
      theme: settings.forceHighContrast
          ? AppTheme.lightHighContrast
          : AppTheme.light,
      darkTheme: settings.forceHighContrast
          ? AppTheme.darkHighContrast
          : AppTheme.dark,
      themeMode: ThemeMode.system,
      themeAnimationDuration:
          settings.reduceMotion ? Duration.zero : kThemeAnimationDuration,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final nextMediaQuery = mediaQuery.copyWith(
          highContrast: mediaQuery.highContrast || settings.forceHighContrast,
          disableAnimations:
              mediaQuery.disableAnimations || settings.reduceMotion,
          accessibleNavigation:
              mediaQuery.accessibleNavigation || settings.reduceMotion,
          textScaler: settings.respectSystemTextScale
              ? mediaQuery.textScaler
              : const TextScaler.linear(1),
        );
        return MediaQuery(
          data: nextMediaQuery,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

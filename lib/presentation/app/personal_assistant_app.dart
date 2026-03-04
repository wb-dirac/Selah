import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/presentation/routing/app_router.dart';
import 'package:personal_ai_assistant/presentation/theme/app_theme.dart';

class PersonalAssistantApp extends StatelessWidget {
  const PersonalAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Personal AI Assistant',
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
    );
  }
}

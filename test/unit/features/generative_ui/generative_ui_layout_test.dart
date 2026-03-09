import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/generative_ui/presentation/generative_ui_layout.dart';

void main() {
  group('UiBreakpointContext', () {
    void setLogicalSize(WidgetTester tester, Size size) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('phone breakpoint below 600px', (tester) async {
      setLogicalSize(tester, const Size(375, 812));

      late UiBreakpoint captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = context.uiBreakpoint;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(captured, UiBreakpoint.phone);
    });

    testWidgets('tablet breakpoint at 768px', (tester) async {
      setLogicalSize(tester, const Size(768, 1024));

      late UiBreakpoint captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = context.uiBreakpoint;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(captured, UiBreakpoint.tablet);
    });

    testWidgets('desktop breakpoint above 1200px', (tester) async {
      setLogicalSize(tester, const Size(1440, 900));

      late UiBreakpoint captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = context.uiBreakpoint;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(captured, UiBreakpoint.desktop);
    });

    testWidgets('phone returns infinite card max width', (tester) async {
      setLogicalSize(tester, const Size(390, 844));

      late double maxWidth;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              maxWidth = context.uiCardMaxWidth;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(maxWidth, double.infinity);
    });

    testWidgets('tablet returns finite card max width', (tester) async {
      setLogicalSize(tester, const Size(800, 1024));

      late double maxWidth;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              maxWidth = context.uiCardMaxWidth;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(maxWidth < double.infinity, isTrue);
      expect(maxWidth, lessThan(800));
    });
  });
}

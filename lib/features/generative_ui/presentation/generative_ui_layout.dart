import 'package:flutter/material.dart';

enum UiBreakpoint { phone, tablet, desktop }

extension UiBreakpointContext on BuildContext {
  UiBreakpoint get uiBreakpoint {
    final width = MediaQuery.sizeOf(this).width;
    if (width < 600) return UiBreakpoint.phone;
    if (width < 1200) return UiBreakpoint.tablet;
    return UiBreakpoint.desktop;
  }

  double get uiCardMaxWidth => switch (uiBreakpoint) {
    UiBreakpoint.phone => double.infinity,
    UiBreakpoint.tablet => 560,
    UiBreakpoint.desktop => 680,
  };

  EdgeInsets get uiCardPadding => switch (uiBreakpoint) {
    UiBreakpoint.phone => const EdgeInsets.all(16),
    UiBreakpoint.tablet => const EdgeInsets.all(20),
    UiBreakpoint.desktop => const EdgeInsets.all(24),
  };

  double get uiMapPreviewHeight => switch (uiBreakpoint) {
    UiBreakpoint.phone => 160,
    UiBreakpoint.tablet => 200,
    UiBreakpoint.desktop => 240,
  };

  double get uiChartHeight => switch (uiBreakpoint) {
    UiBreakpoint.phone => 160,
    UiBreakpoint.tablet => 200,
    UiBreakpoint.desktop => 240,
  };
}

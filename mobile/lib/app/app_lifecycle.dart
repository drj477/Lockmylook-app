import 'package:flutter/widgets.dart';

class AppLifecycle extends WidgetsBindingObserver {
  AppLifecycle();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        break;

      case AppLifecycleState.inactive:
        break;

      case AppLifecycleState.paused:
        break;

      case AppLifecycleState.hidden:
        break;

      case AppLifecycleState.detached:
        break;
    }
  }
}

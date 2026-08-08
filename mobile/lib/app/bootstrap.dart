import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app/app.dart';
import 'package:mobile/app/app_lifecycle.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  WidgetsBinding.instance.addObserver(AppLifecycle());

  runApp(const ProviderScope(child: LockMyLookApp()));
}

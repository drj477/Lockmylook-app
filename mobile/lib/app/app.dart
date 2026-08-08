import 'package:flutter/material.dart';

import 'package:mobile/app/router.dart';
import 'package:mobile/core/theme/app_theme.dart';

class LockMyLookApp extends StatelessWidget {
  const LockMyLookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LockMyLook',

      debugShowCheckedModeBanner: false,

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,

      themeMode: ThemeMode.system,

      routerConfig: AppRouter.router,
    );
  }
}

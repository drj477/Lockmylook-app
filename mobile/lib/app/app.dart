import 'package:flutter/material.dart';

class LockMyLookApp extends StatelessWidget {
  const LockMyLookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LockMyLook',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'LockMyLook',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
/// The root widget: start screen → game.
library;

import 'dart:ffi' show DynamicLibrary;

import 'package:flutter/material.dart';

import 'start_screen/start_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bust A Move',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE53935)),
        useMaterial3: true,
      ),
      home: const StartScreen(),
    );
  }
}

/// TEMPORARY: proves the web build catches what analyze and tests do not.
String debugPlatform() => DynamicLibrary.process().toString();

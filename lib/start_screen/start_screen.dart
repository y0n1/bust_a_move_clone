/// Start screen — entry point for the game.
library;

import 'package:flutter/material.dart';

import '../gameplay/ui/game_screen.dart';
import 'viewmodel/start_screen_viewmodel.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key, this.viewModel});

  final StartViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1E3A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'BUST A MOVE',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFDD835),
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'A Flutter web clone of the classic bubble shooter',
                style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 16),
              ),
              const SizedBox(height: 48),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 20),
                ),
                onPressed: () {
                  final vm = viewModel ?? StartViewModel();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                        builder: (_) => GameScreen(viewModel: vm.createGame())),
                  );
                },
                child: const Text(
                  'PLAY',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Aim with the mouse or finger, tap to fire.\n'
                'Match 3+ of a color to pop. Clear the board!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

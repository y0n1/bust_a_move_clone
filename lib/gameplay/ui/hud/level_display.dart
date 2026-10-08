/// HUD widget — displays lives, level, next-color queue, and restart button.
library;

import 'package:flutter/material.dart';

import '../../game/model.dart';

class LevelDisplay extends StatelessWidget {
  const LevelDisplay({
    super.key,
    required this.state,
    required this.onRestart,
  });

  final GameState state;
  final VoidCallback onRestart;

  static const Map<BubbleColor, Color> _colors = {
    BubbleColor.red: Color(0xFFE53935),
    BubbleColor.green: Color(0xFF43A047),
    BubbleColor.blue: Color(0xFF1E88E5),
    BubbleColor.yellow: Color(0xFFFDD835),
    BubbleColor.purple: Color(0xFF8E24AA),
    BubbleColor.orange: Color(0xFFFB8C00),
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'LIVES ${state.lives}',
          style: const TextStyle(
              color: Color(0xFFFDD835),
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 12),
        Text(
          'LEVEL ${state.level}',
          style: const TextStyle(
              color: Color(0xFFB0BEC5),
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 16),
        const Text(
          'NEXT',
          style: TextStyle(
              color: Color(0xFFB0BEC5),
              fontSize: 12,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _colors[state.nextColors[0]],
                border: Border.all(
                    color: const Color(0xFFFDD835), width: 2.5),
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Color(0xFFFFFFFF),
              ),
            ),
            const SizedBox(height: 4),
            ...state.nextColors.skip(1).map((c) {
              return Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _colors[c],
                  border:
                      Border.all(color: Colors.white24, width: 1),
                ),
              );
            }),
          ],
        ),
        IconButton(
          onPressed: onRestart,
          icon: const Icon(Icons.refresh,
              color: Color(0xFFB0BEC5), size: 18),
          tooltip: 'Restart level',
        ),
      ],
    );
  }
}

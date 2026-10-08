/// HUD widget — displays the current score and combo streak.
library;

import 'package:flutter/material.dart';

import '../../game/model.dart';

class ScoreDisplay extends StatelessWidget {
  const ScoreDisplay({
    super.key,
    required this.state,
  });

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SCORE ${state.score}',
          style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
        if (state.combo >= 2)
          Text(
            'COMBO ×${state.combo}',
            style: const TextStyle(
                color: Color(0xFFFFB300),
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
      ],
    );
  }
}

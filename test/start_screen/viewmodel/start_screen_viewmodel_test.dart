import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:bust_a_move_clone/game/model.dart';
import 'package:bust_a_move_clone/start_screen/viewmodel/start_screen_viewmodel.dart';

void main() {
  group('StartViewModel', () {
    test('createGame returns a fresh level 1 game', () {
      final vm = StartViewModel(rng: math.Random(42));

      final game = vm.createGame();

      expect(game.state.level, 1);
      expect(game.state.status, GameStatus.playing);
      expect(game.state.projectile, isNull);

      game.dispose();
    });

    test('createGame returns independent sessions', () {
      final vm = StartViewModel(rng: math.Random(42));

      final a = vm.createGame();
      final b = vm.createGame();

      expect(identical(a, b), isFalse);
      expect(identical(a.state, b.state), isFalse);

      a.dispose();
      b.dispose();
    });
  });
}

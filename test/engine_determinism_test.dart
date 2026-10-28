import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:bust_a_move_clone/game/engine.dart';
import 'package:bust_a_move_clone/game/model.dart';

void main() {
  group('Engine Determinism', () {
    test('Two engines with same seed produce identical initial GameState', () {
      const seed = 12345;
      final rng1 = math.Random(seed);
      final rng2 = math.Random(seed);

      final engine1 = Engine.forLevel(1, rng: rng1);
      final engine2 = Engine.forLevel(1, rng: rng2);

      final state1 = engine1.startLevel();
      final state2 = engine2.startLevel();

      expect(state1, equals(state2), reason: 'Initial states must be identical for the same seed');
      expect(state1.bubbles.keys.toSet(), equals(state2.bubbles.keys.toSet()), reason: 'Bubble keys must match');
    });

    test('Identical input sequences produce identical GameStates', () {
      const seed = 42;
      final rng1 = math.Random(seed);
      final rng2 = math.Random(seed);

      final engine1 = Engine.forLevel(1, rng: rng1);
      final engine2 = Engine.forLevel(1, rng: rng2);

      var state1 = engine1.startLevel();
      var state2 = engine2.startLevel();

      expect(state1, equals(state2));

      // Sequence of inputs: various angles
      final inputs = [0.0, math.pi / 4, math.pi / 2, math.pi, 3 * math.pi / 4, math.pi / 2.1];

      for (final angle in inputs) {
        state1 = engine1.shoot(state1, angle);
        state2 = engine2.shoot(state2, angle);

        expect(state1.projectile, equals(state2.projectile), reason: 'Projectiles must match');
        expect(state1.nextColors, equals(state2.nextColors), reason: 'Next colors must match');

        // Simulate several ticks
        for (int tick = 0; tick < 10; tick++) {
          state1 = engine1.tick(state1);
          state2 = engine2.tick(state2);

          expect(state1, equals(state2), reason: 'GameState must be identical after tick $tick');
        }
      }
    });

    test('Determinism holds over many steps', () {
      const seed = 98765;
      final rng1 = math.Random(seed);
      final rng2 = math.Random(seed);

      final engine1 = Engine.forLevel(2, rng: rng1);
      final engine2 = Engine.forLevel(2, rng: rng2);

      var state1 = engine1.startLevel();
      var state2 = engine2.startLevel();

      expect(state1, equals(state2));

      for (int i = 0; i < 50; i++) {
        final angle = math.sin(i.toDouble()) * math.pi;
        state1 = engine1.shoot(state1, angle);
        state2 = engine2.shoot(state2, angle);

        for (int tick = 0; tick < 5; tick++) {
          state1 = engine1.tick(state1);
          state2 = engine2.tick(state2);
        }

        expect(state1, equals(state2), reason: 'Determinism failed at step $i');
      }
    });
  });
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bust_a_move_clone/game/engine.dart';
import 'package:bust_a_move_clone/game/model.dart';
import 'package:bust_a_move_clone/gameplay/viewmodel/game_viewmodel.dart';

Engine _engine() => Engine.forLevel(1, rng: math.Random(42));

void main() {
  group('GameViewModel', () {
    test('starts at level 1 in the playing state', () {
      final vm = GameViewModel(_engine());

      expect(vm.state.level, 1);
      expect(vm.state.status, GameStatus.playing);
      expect(vm.isPlaying, isTrue);
      expect(vm.isGameOver, isFalse);
      expect(vm.state.projectile, isNull);
    });

    test('exposes engine geometry', () {
      final engine = _engine();
      final vm = GameViewModel(engine);

      expect(vm.cols, engine.cols);
      expect(vm.rows, engine.rows);
      expect(vm.cannonX, engine.cannonX);
      expect(vm.cannonY, engine.cannonY);
    });

    test('fire spawns a projectile', () {
      final vm = GameViewModel(_engine());
      expect(vm.state.projectile, isNull);

      vm.fire();

      expect(vm.state.projectile, isNotNull);
    });

    test('fire is ignored while a projectile is in flight', () {
      final vm = GameViewModel(_engine());
      vm.fire();
      final first = vm.state.projectile;

      vm.fire();

      expect(vm.state.projectile, same(first));
    });

    test('fire notifies listeners', () {
      final vm = GameViewModel(_engine());
      var notified = 0;
      vm.addListener(() => notified++);

      vm.fire();

      expect(notified, 1);
    });

    test('updateAim clamps to +/- 60 degrees', () {
      final vm = GameViewModel(_engine());
      vm.computeLayout(const Size(800, 600));

      vm.updateAim(const Offset(10000, 100), const Size(800, 600));
      expect(vm.aimAngle, closeTo(math.pi / 3, 1e-9));
      expect(vm.hasPointer, isTrue);

      vm.updateAim(const Offset(-10000, 100), const Size(800, 600));
      expect(vm.aimAngle, closeTo(-math.pi / 3, 1e-9));
    });

    test('computeLayout keeps bubble size within bounds', () {
      final vm = GameViewModel(_engine());

      vm.computeLayout(const Size(800, 600));
      expect(vm.bubbleSize, greaterThanOrEqualTo(minBubbleSize));
      expect(vm.bubbleSize, lessThanOrEqualTo(maxBubbleSize));

      vm.computeLayout(const Size(100, 100));
      expect(vm.bubbleSize, minBubbleSize);

      vm.computeLayout(const Size(10000, 10000));
      expect(vm.bubbleSize, maxBubbleSize);
    });

    test('restart resets the level and clears juice state', () {
      final vm = GameViewModel(_engine());
      vm.fire();
      vm.computeLayout(const Size(800, 600));
      vm.updateAim(const Offset(400, 100), const Size(800, 600));

      vm.restart();

      expect(vm.state.projectile, isNull);
      expect(vm.aimAngle, 0);
      expect(vm.hasPointer, isFalse);
      expect(vm.popups, isEmpty);
      expect(vm.bursts, isEmpty);
      expect(vm.trail, isEmpty);
      expect(vm.shakeElapsedMs, isNull);
      expect(vm.recoilElapsedMs, isNull);
      expect(vm.bigPopElapsedMs, isNull);
      expect(vm.fxElapsedMs, 0);
    });

    test('dispose without init does not throw', () {
      final vm = GameViewModel(_engine());
      expect(vm.dispose, returnsNormally);
    });
  });
}

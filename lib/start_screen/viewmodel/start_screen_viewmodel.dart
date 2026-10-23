/// StartViewModel — the ViewModel layer for the start screen.
///
/// Owns the creation of a fresh game session. The View calls [createGame]
/// when the player taps PLAY and is responsible for navigating to it.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../game/engine.dart';
import '../../gameplay/viewmodel/game_viewmodel.dart';

/// ViewModel that drives the start screen.
class StartViewModel extends ChangeNotifier {
  StartViewModel({math.Random? rng}) : _rng = rng ?? math.Random();

  final math.Random _rng;

  /// Creates a fresh gameplay ViewModel for level 1.
  GameViewModel createGame() {
    final engine = Engine.forLevel(1, rng: _rng);
    return GameViewModel(engine);
  }
}

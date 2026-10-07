/// Core data model for the Bust-A-Move clone.
///
/// Pure Dart, no Flutter imports, so it can be unit tested headlessly.
library;

import 'dart:math' as math;

/// The 6 colors a bubble can be.
///
/// Kept as a simple enum so the model layer has no dependency on
/// `dart:ui` / `material`. The UI layer maps these to `Color` objects.
enum BubbleColor { red, green, blue, yellow, purple, orange }

/// A single bubble on the board.
class Bubble {
  const Bubble({
    required this.color,
    required this.row,
    required this.col,
  });

  final BubbleColor color;

  /// Row index from the top of the board (0 = topmost row).
  final int row;

  /// Column index within the row. Odd rows are offset by half a bubble.
  final int col;

  /// A key identifying the bubble's slot on the board. Two bubbles can never
  /// share a key, and a key is unique to a (row, col) pair.
  String get key => '$row:$col';

  @override
  String toString() => 'Bubble($color @ row $row, col $col)';
}

/// A moving bubble shot from the cannon.
class Projectile {
  Projectile({
    required this.color,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  });

  final BubbleColor color;

  /// Current position in board-space (units = bubble diameters, y grows down).
  double x;
  double y;

  /// Velocity in board-space units per tick.
  double vx;
  double vy;

  double get speed => math.sqrt(vx * vx + vy * vy);

  bool get isMoving => vx != 0 || vy != 0;

  /// Advance the projectile by [dt] ticks.
  void advance(double dt) {
    x += vx * dt;
    y += vy * dt;
  }
}

/// Snapshot of the game board + HUD state at a point in time.
///
/// Intentionally a value object: the UI renders from this, and the engine
/// returns a fresh [GameState] for every mutation so callers never have to
/// worry about stale references.
class GameState {
  const GameState({
    required this.bubbles,
    required this.projectile,
    required this.nextColors,
    required this.score,
    required this.lives,
    required this.level,
    required this.bubbleRow,
    required this.status,
    required this.poppedThisShot,
    required this.combo,
    required this.initialBubbleCount,
    required this.shotsTaken,
  });

  /// Bubbles currently attached to the board, indexed by [Bubble.key].
  final Map<String, Bubble> bubbles;

  /// The in-flight bubble, or null if none.
  final Projectile? projectile;

  /// Colors the cannon can shoot, in order. Index 0 is the loaded bubble.
  final List<BubbleColor> nextColors;

  final int score;
  final int lives;
  final int level;

  /// How many rows of bubbles have descended from the top (wall descent).
  final int bubbleRow;

  final GameStatus status;

  /// Number of bubbles popped in the current shot chain (for scoring / FX).
  final int poppedThisShot;

  /// Consecutive shots that popped 3+ bubbles. 0 = no active combo.
  /// The pop score is multiplied by this value (after increment) on each
  /// successful shot; a shot that pops fewer than 3 resets it to 0.
  final int combo;

  /// How many bubbles were on the board when the level (re)started.
  /// Used by the UI to render the level-clear progress bar.
  final int initialBubbleCount;

  /// Number of shots taken in the current level (for descent interval).
  final int shotsTaken;

  /// Return a copy of this state with the given fields replaced.
  GameState copyWith({
    Map<String, Bubble>? bubbles,
    Projectile? projectile,
    List<BubbleColor>? nextColors,
    int? score,
    int? lives,
    int? level,
    int? bubbleRow,
    GameStatus? status,
    int? poppedThisShot,
    int? combo,
    int? initialBubbleCount,
    int? shotsTaken,
  }) {
    return GameState(
      bubbles: bubbles ?? this.bubbles,
      projectile: projectile ?? this.projectile,
      nextColors: nextColors ?? this.nextColors,
      score: score ?? this.score,
      lives: lives ?? this.lives,
      level: level ?? this.level,
      bubbleRow: bubbleRow ?? this.bubbleRow,
      status: status ?? this.status,
      poppedThisShot: poppedThisShot ?? this.poppedThisShot,
      combo: combo ?? this.combo,
      initialBubbleCount: initialBubbleCount ?? this.initialBubbleCount,
      shotsTaken: shotsTaken ?? this.shotsTaken,
    );
  }
}

enum GameStatus { playing, won, lost }

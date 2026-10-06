/// The game engine: pure Dart, deterministic, no Flutter dependency.
///
/// Board geometry
/// --------------
/// The board is a hex-grid of circles. Rows are stacked vertically; odd rows
/// are offset by half a bubble horizontally so each bubble nests between the
/// two above it.
///
/// Coordinates:
///   * [GameState.bubbles] is keyed by `Bubble.key` ("row:col").
///   * Board-space is in "bubble diameters": (0, 0) is the top-left, and
///     y grows downward. The cannon sits at [cannonX], [cannonY].
///
/// A level is won when the board is empty; lost when the descended wall
/// reaches the cannon line.
library;

import 'dart:math' as math;

import 'model.dart';

/// Number of extra rows below the board used for BFS slack in
/// [_snapToHex] and [_matchGroupAt]. Descent bubbles occupy row
/// [rows] before the loss condition triggers, so the search must
/// extend at least one row past the board boundary.
const int descentSlack = 8;

class Engine {
  /// Number of columns on even rows (row 0). Odd rows have [cols]-1.
  final int cols;

  /// Number of rows on the board (top is row 0, bottom is row rows-1).
  final int rows;

  /// The cannon's x in board-space (center of the playfield).
  final double cannonX;

  /// The cannon's y in board-space (near the bottom of the playfield).
  final double cannonY;

  /// The speed of a projectile in board-space units per tick.
  final double projectileSpeed;

  /// A [math.Random] for all randomness in the level.
  final math.Random rng;

  /// How many colors are in the active palette (2..6).
  final int activeColorCount;

  Engine({
    required this.cols,
    required this.rows,
    required this.projectileSpeed,
    required this.rng,
    int? activeColorCount,
  })  : cannonX = cols / 2,
        cannonY = rows + 1,
        activeColorCount = math.min(6, activeColorCount ?? 6) {
    if (this.activeColorCount < 2) {
      throw ArgumentError.value(activeColorCount, 'activeColorCount',
          'must be >= 2');
    }
  }

  /// Build a fresh [GameState] for the start of a level.
  ///
  /// The initial bubble cluster fills the top half of the board, leaving
  /// room for the cluster to descend toward the cannon as the player
  /// shoots. The bottom half is empty and will be filled by the
  /// descending cluster.
  ///
  /// [initialLives] sets the starting lives count. Defaults to 3 for a
  /// new game; used internally when resetting after a life loss.
  GameState startLevel({int initialLives = 3}) {
    final rng = this.rng;
    final palette = _activePalette();

    // Fill the top half of the board with random bubbles. The cluster
    // descends from here toward the cannon as the player shoots.
    final clusterRows = (rows / 2).ceil();
    final bubbles = <String, Bubble>{};
    for (var r = 0; r < clusterRows; r++) {
      final colsInRow = r.isEven ? cols : cols - 1;
      for (var c = 0; c < colsInRow; c++) {
        final color = palette[rng.nextInt(palette.length)];
        bubbles['$r:$c'] =
            Bubble(color: color, row: r, col: c);
      }
    }

    final nextColors = List<BubbleColor>.generate(3, (_) {
      return palette[rng.nextInt(palette.length)];
    });

    return GameState(
      bubbles: bubbles,
      projectile: null,
      nextColors: nextColors,
      score: 0,
      lives: initialLives,
      level: 1,
      bubbleRow: 0,
      status: GameStatus.playing,
      poppedThisShot: 0,
    );
  }

  List<BubbleColor> _activePalette() {
    final all = BubbleColor.values;
    return all.sublist(0, activeColorCount);
  }

  /// Board-space position (center) of the bubble at (row, col).
  (double x, double y) centerOf(int row, int col) {
    // Odd rows are offset right by half a bubble.
    final x = col + (row.isOdd ? 0.5 : 0.0);
    // Row 0 is at the very top of the board; rows stack with a vertical
    // step of sqrt(3)/2 bubble diameters (hex packing).
    final y = row * _rowStep + _topPadding;
    return (x, y);
  }

  static double get _rowStep => 0.866; // sqrt(3) / 2
  static double get _topPadding => 0.0;

  /// The set of board-adjacent cells for a bubble at (row, col).
  ///
  /// On a "flat-top" hex grid with odd rows offset to the right:
  ///   even row: (-1,-1) (-1,0) (0,-1) (0,1) (1,-1) (1,0)
  ///   odd row:  (-1,0) (-1,1) (0,-1) (0,1) (1,0) (1,1)
  Set<(int, int)> neighborsOf(int row, int col) {
    final isEven = row.isEven;
    final result = <(int, int)>{};
    if (isEven) {
      // Even row: cells at x = 0, 1, 2, ...
      // Upper neighbors are in the odd row above (row-1), offset right by 0.5.
      result.add((row - 1, col - 1)); // upper-left
      result.add((row - 1, col)); // upper-right
      result.add((row, col - 1)); // left
      result.add((row, col + 1)); // right
      result.add((row + 1, col - 1)); // lower-left
      result.add((row + 1, col)); // lower-right
    } else {
      // Odd row: cells at x = 0.5, 1.5, 2.5, ...
      // Upper neighbors are in the even row above (row-1).
      result.add((row - 1, col)); // upper-left
      result.add((row - 1, col + 1)); // upper-right
      result.add((row, col - 1)); // left
      result.add((row, col + 1)); // right
      result.add((row + 1, col)); // lower-left
      result.add((row + 1, col + 1)); // lower-right
    }
    return result;
  }

  /// Fire a projectile from the cannon at [angle] (radians, 0 = straight up,
  /// positive = toward the right). Returns a new [GameState] with the
  /// projectile in flight.
  ///
  /// Angle convention: 0 radians points straight up (negative screen-y).
  /// Positive angles rotate clockwise (toward the right).
  ///   * x-velocity = sin(angle) * speed
  ///   * y-velocity = -cos(angle) * speed  (negative = upward on screen)
  GameState shoot(GameState s, double angle) {
    if (s.projectile != null || s.status != GameStatus.playing) return s;
    final color = s.nextColors.first;
    final sin = math.sin(angle);
    final cos = math.cos(angle);
    final proj = Projectile(
      color: color,
      x: cannonX,
      y: cannonY,
      vx: sin * projectileSpeed,
      vy: -cos * projectileSpeed,
    );
    final rest = List<BubbleColor>.from(s.nextColors);
    rest.removeAt(0);
    // Refill to keep 3 colors queued.
    while (rest.length < 3) {
      rest.add(_activePalette()[rng.nextInt(activeColorCount)]);
    }
    return s.copyWith(projectile: proj, nextColors: rest);
  }

  /// Advance the simulation by one tick. Returns a new [GameState] reflecting
  /// the projectile's new position and any collision / match / drop that
  /// happened.
  GameState tick(GameState s) {
    final proj = s.projectile;
    if (proj == null || s.status != GameStatus.playing) return s;

    var next = s;
    // Sub-step the projectile to avoid tunneling.
    const steps = 8;
    for (var i = 0; i < steps; i++) {
      proj.advance(projectileSpeed / steps);
      if (proj.y <= 0 || proj.x < 0 || proj.x > cols) {
        // Off the top or side: the shot is wasted; the bubble flies off screen.
        return s.copyWith(projectile: null, nextColors: _refill(s.nextColors));
      }
      if (_hitsBubbleOrWall(proj, s)) {
        next = _settleShot(s, proj);
        return next;
      }
    }
    return s.copyWith(projectile: proj);
  }

  bool _hitsBubbleOrWall(Projectile p, GameState s) {
    // Wall hit: the top of the board.
    if (p.y <= 0.5) return true;
    // Collision with any existing bubble (distance < one bubble diameter).
    for (final b in s.bubbles.values) {
      final (bx, by) = centerOf(b.row, b.col);
      final dx = p.x - bx;
      final dy = p.y - by;
      if (dx * dx + dy * dy <= 0.9) return true; // slightly forgiving
    }
    return false;
  }

  /// When a projectile lands, snap it into the nearest valid hex cell, attach
  /// it, find any 3+ match, pop it, drop detached clusters, and check for a
  /// win/loss.
  GameState _settleShot(GameState s, Projectile p) {
    final cell = _snapToHex(p.x, p.y);
    final key = '${cell.$1}:${cell.$2}';
    if (s.bubbles.containsKey(key)) {
      // Rare: the snapped cell is already occupied; try the nearest free cell.
      final alt = _nearestFreeCell(cell, s); // board full; shouldn't happen.
      return _settleShotAt(s, p, alt);
    }
    return _settleShotAt(s, p, cell);
  }

  (int, int) _nearestFreeCell((int, int) preferred, GameState s) {
    // BFS over hex neighbors until we find an empty slot.
    final queue = <(int, int)>[preferred];
    final seen = <(int, int)>{preferred};
    while (queue.isNotEmpty) {
      final (r, c) = queue.removeAt(0);
      if (r < 0 || r > rows) continue;
      if (r.isEven && (c < 0 || c >= cols)) continue;
      if (r.isOdd && (c < 0 || c >= cols - 1)) continue;
      if (!s.bubbles.containsKey('$r:$c')) return (r, c);
      for (final n in neighborsOf(r, c)) {
        if (!seen.contains(n)) {
          seen.add(n);
          queue.add(n);
        }
      }
    }
    return preferred;
  }

  GameState _settleShotAt(GameState s, Projectile p, (int, int) cell) {
    final newRow = s.bubbleRow;
    final bubbles = Map<String, Bubble>.from(s.bubbles);
    bubbles['${cell.$1}:${cell.$2}'] =
        Bubble(color: p.color, row: cell.$1, col: cell.$2);

    // Find the match group containing the new bubble.
    final group = _matchGroupAt(cell.$1, cell.$2, bubbles, p.color);
    var score = s.score;
    var popped = 0;
    if (group.length >= 3) {
      for (final k in group) {
        bubbles.remove(k);
        popped++;
      }
      score += _popScore(group.length, s.poppedThisShot + 1);
      // Detached clusters fall.
      final fallen = _dropDetached(bubbles);
      score += _dropScore(fallen);
    }

    // Descend the wall: after every shot the bubble cluster moves one row
    // toward the cannon (down the screen). Bubbles that were at row 0 are
    // now at row 1, etc. The top row becomes available for the next shot.
    final rekeyed = _applyDescent(bubbles);
    final newBubbleRow = newRow + 1;

    final nextColors = _refill(s.nextColors);
    var status = _computeStatus(rekeyed, newBubbleRow);
    var lives = s.lives;

    // Handle life loss: if a bubble reached the cannon line, decrement lives.
    if (status == GameStatus.lost) {
      lives--;
      if (lives > 0) {
        // Reset the board but preserve remaining lives.
        return startLevel(initialLives: lives);
      }
    }

    final next = GameState(
      bubbles: rekeyed,
      projectile: null,
      nextColors: nextColors,
      score: score,
      lives: lives,
      level: s.level,
      bubbleRow: newBubbleRow,
      status: status,
      poppedThisShot: popped,
    );
    return next;
  }

  /// Find all bubbles of [color] connected to (row, col) in [bubbles].
  Set<String> _matchGroupAt(
      int row, int col, Map<String, Bubble> bubbles, BubbleColor color) {
    final start = '$row:$col';
    if (!bubbles.containsKey(start)) return {};
    final group = <String>{start};
    final stack = <(int, int)>[(row, col)];
    while (stack.isNotEmpty) {
      final (r, c) = stack.removeLast();
      for (final n in neighborsOf(r, c)) {
        final (nr, nc) = n;
        if (nr < 0 || nr >= rows + descentSlack) continue;
        final key = '$nr:$nc';
        if (group.contains(key)) continue;
        final b = bubbles[key];
        if (b == null || b.color != color) continue;
        group.add(key);
        stack.add((nr, nc));
      }
    }
    return group;
  }

  /// Remove every bubble in [bubbles] that is no longer connected to the
  /// main cluster and return how many fell.
  ///
  /// In a bubble shooter, "attached" means connected to the top of the
  /// board (the wall). When a match pops, any cluster that is no longer
  /// touching the wall falls off the bottom of the board.
  ///
  /// We model this by flood-filling from the topmost row that still has
  /// bubbles. Any bubble not reached by the flood fill is detached and
  /// falls.
  int _dropDetached(Map<String, Bubble> bubbles) {
    if (bubbles.isEmpty) return 0;

    // Find the topmost row that has any bubbles.
    var topRow = 1000000;
    for (final b in bubbles.values) {
      if (b.row < topRow) topRow = b.row;
    }

    // Flood fill from every bubble in the topmost row.
    final attached = <String>{};
    final stack = <(int, int)>[];
    final colsInTopRow = topRow.isEven ? cols : cols - 1;
    for (var c = 0; c < colsInTopRow; c++) {
      final key = '$topRow:$c';
      if (bubbles.containsKey(key)) stack.add((topRow, c));
    }

    while (stack.isNotEmpty) {
      final (r, c) = stack.removeLast();
      final key = '$r:$c';
      if (attached.contains(key)) continue;
      attached.add(key);
      for (final n in neighborsOf(r, c)) {
        if (bubbles.containsKey('${n.$1}:${n.$2}')) {
          stack.add(n);
        }
      }
    }

    var fallen = 0;
    bubbles.removeWhere((k, b) {
      if (attached.contains(k)) return false;
      fallen++;
      return true;
    });
    return fallen;
  }

  /// Shift every bubble DOWN by one row (toward the cannon). This is the
  /// "wall descent" that happens after every shot.
  ///
  /// Bubbles at row 0 move to row 1, row 1 moves to row 2, etc. The top
  /// row of the board (row 0) becomes empty and is available for the next
  /// shot to land in.
  Map<String, Bubble> _applyDescent(Map<String, Bubble> bubbles) {
    final result = <String, Bubble>{};
    for (final entry in bubbles.entries) {
      final b = entry.value;
      final newRow = b.row + 1;
      result['$newRow:${b.col}'] =
          Bubble(color: b.color, row: newRow, col: b.col);
    }
    return result;
  }

  GameStatus _computeStatus(Map<String, Bubble> bubbles, int bubbleRow) {
    if (bubbles.isEmpty) return GameStatus.won;
    // Loss: a bubble has descended to the cannon line (row `rows`).
    // The cannon sits at board-space y = rows + 1. A bubble is on the
    // death line when its row index reaches `rows` (the row just above
    // the cannon).
    var lowest = -1;
    for (final b in bubbles.values) {
      if (b.row > lowest) lowest = b.row;
    }
    if (lowest >= rows) {
      return GameStatus.lost;
    }
    return GameStatus.playing;
  }

  List<BubbleColor> _refill(List<BubbleColor> current) {
    final rest = List<BubbleColor>.from(current);
    while (rest.length < 3) {
      rest.add(_activePalette()[rng.nextInt(activeColorCount)]);
    }
    return rest.take(3).toList();
  }

  int _popScore(int groupSize, int chainIndex) {
    // 100 per bubble, x2 bonus on a chain of 3+, x3 on 4+, etc.
    var base = groupSize * 100;
    if (chainIndex >= 2) base *= 2;
    if (groupSize >= 4) base += 50 * (groupSize - 3);
    return base;
  }

  int _dropScore(int fallen) => fallen * 50;
}

/// Snap a free-floating point to the nearest valid hex cell on the board.
extension on Engine {
  (int, int) _snapToHex(double x, double y) {
    // Find the (row, col) whose center is closest to (x, y).
    (int, int) best = (0, 0);
    double bestDist = double.infinity;
    for (var r = 0; r < rows + descentSlack; r++) {
      final colsInRow = r.isEven ? cols : cols - 1;
      for (var c = 0; c < colsInRow; c++) {
        final (cx, cy) = centerOf(r, c);
        final dx = x - cx;
        final dy = y - cy;
        final d = dx * dx + dy * dy;
        if (d < bestDist) {
          bestDist = d;
          best = (r, c);
        }
      }
    }
    return best;
  }
}

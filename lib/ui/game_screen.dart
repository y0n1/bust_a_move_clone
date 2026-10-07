/// The gameplay screen: canvas rendering of [GameState], pointer input for
/// aiming and firing, and a simple HUD.
///
/// The engine is the source of truth; this widget only holds a [GameState]
/// and replaces it wholesale on every tick / shot.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/engine.dart';
import '../game/model.dart';

/// Minimum supported viewport width (covers ~95% of smartphones).
const double minViewportWidth = 360;

/// Maximum supported viewport width (covers tablets and standard desktops).
const double maxViewportWidth = 1024;

/// Minimum bubble size in pixels (ensures touch targets ≥ 44px and text readable).
const double minBubbleSize = 32;

/// Maximum bubble size in pixels (prevents excessive scaling on large screens).
const double maxBubbleSize = 120;

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.engine});

  final Engine engine;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late final Engine _engine;
  late GameState _state;
  late final Ticker _ticker;

  /// The aim angle in radians (0 = straight up, positive = toward the right).
  double _aimAngle = 0;

  /// Has a pointer ever been received? (Avoids aim at (0,0) on first frame.)
  bool _hasPointer = false;

  /// Layout state: bubble size in pixels and offset to center the board.
  double _bubbleSize = 0;
  double _offsetX = 0;
  double _offsetY = 0;

  /// Ticker time when the "BIG POP!" banner started (null = not active).
  Duration? _bigPopAt;

  /// Milliseconds since the banner started; passed to the painter.
  int? _bigPopElapsedMs;

  @override
  void initState() {
    super.initState();
    _engine = widget.engine;
    _state = _engine.startLevel();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    // 60 fps tick: the engine advances the projectile by one step per tick.
    final prev = _state;
    if (_state.projectile != null && _state.status == GameStatus.playing) {
      _state = _engine.tick(_state);
    }
    // A settle just happened (projectile was in flight, now none) with a
    // 5+ pop: trigger the BIG POP banner.
    if (prev.projectile != null &&
        _state.projectile == null &&
        _state.poppedThisShot >= 5) {
      _bigPopAt = elapsed;
    }
    final bigPopAt = _bigPopAt;
    _bigPopElapsedMs =
        bigPopAt == null ? null : (elapsed - bigPopAt).inMilliseconds;
    if (!mounted) return;
    setState(() {});
  }

  /// Convert a pointer in logical pixels to a board-space aim angle.
  void _updateAim(Offset localPos, Size size) {
    if (size.width == 0 || size.height == 0) return;
    final cannonPx = _boardToScreen(_engine.cannonX, _engine.cannonY, size);
    final dx = localPos.dx - cannonPx.dx;
    final dy = localPos.dy - cannonPx.dy;
    // Only allow aiming upward (dy < 0 in screen space).
    var angle = math.atan2(dx, -dy);
    // Clamp to a reasonable range: -60° to +60° from vertical.
    const maxAngle = math.pi / 3;
    if (angle > maxAngle) angle = maxAngle;
    if (angle < -maxAngle) angle = -maxAngle;
    _aimAngle = angle;
  }

  /// Convert a board-space point to logical pixels given the canvas size.
  Offset _boardToScreen(double x, double y, Size size) {
    return Offset(x * _bubbleSize + _offsetX, y * _bubbleSize + _offsetY);
  }

  /// Compute the bubble size and offset to fit the board within [size].
  ///
  /// The board in board-space spans [cols] horizontally and [rows + 1.2]
  /// vertically (grid + cannon area). We scale to fit within [size] while
  /// preserving the aspect ratio, then center the result.
  ///
  /// Bubble size is clamped to [minBubbleSize]..[maxBubbleSize] to ensure
  /// touch targets remain usable and the game doesn't scale excessively on
  /// large viewports.
  void _computeLayout(Size size) {
    final boardWidth = _engine.cols;
    final boardHeight = _engine.rows + 1.2;
    final aspectRatio = boardWidth / boardHeight;

    double bubble;
    if (size.width / size.height > aspectRatio) {
      // Width is the limiting factor — fit by height.
      bubble = size.height / boardHeight;
    } else {
      // Height is the limiting factor — fit by width.
      bubble = size.width / boardWidth;
    }

    // Clamp bubble size to viewport constraints.
    bubble = bubble.clamp(minBubbleSize, maxBubbleSize);

    final boardPixelWidth = boardWidth * bubble;
    final boardPixelHeight = boardHeight * bubble;
    _offsetX = (size.width - boardPixelWidth) / 2;
    _offsetY = (size.height - boardPixelHeight) / 2;
    _bubbleSize = bubble;
  }

  void _fire() {
    if (_state.projectile != null || _state.status != GameStatus.playing) return;
    _state = _engine.shoot(_state, _aimAngle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1E3A),
      body: Column(
        children: [
          // HUD at top — no overlap with canvas.
          _Hud(state: _state, onRestart: _restart),
          // Canvas area below HUD, fills remaining space.
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final size = constraints.biggest;
              if (size.width == 0 || size.height == 0) return const SizedBox();
              _computeLayout(size);
              return Stack(
                fit: StackFit.expand,
                children: [
                  Listener(
                    onPointerMove: (event) {
                      _hasPointer = true;
                      _updateAim(event.localPosition, size);
                    },
                    onPointerDown: (event) {
                      _hasPointer = true;
                      _updateAim(event.localPosition, size);
                    },
                    onPointerUp: (_) => _fire(),
                    child: CustomPaint(
                      painter: _GamePainter(
                        state: _state,
                        engine: _engine,
                        aimAngle: _aimAngle,
                        hasPointer: _hasPointer,
                        bubbleSize: _bubbleSize,
                        offsetX: _offsetX,
                        offsetY: _offsetY,
                        bigPopElapsedMs: _bigPopElapsedMs,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  if (_state.status != GameStatus.playing)
                    _StatusOverlay(state: _state, onRestart: _restart),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  void _restart() {
    setState(() {
      if (_state.status == GameStatus.won) {
        // Level cleared — advance to next level.
        _state = _engine.startLevel(level: _state.level + 1);
      } else if (_state.status == GameStatus.lost && _state.lives > 0) {
        // Player lost a life and the wall reached the cannon.
        // Reset the board with remaining lives.
        _state = _engine.startLevel(initialLives: _state.lives - 1);
      } else {
        // Full restart (won and no lives, or lives == 0).
        _state = _engine.startLevel();
      }
      _aimAngle = 0;
      _hasPointer = false;
      _bigPopAt = null;
      _bigPopElapsedMs = null;
    });
  }
}

/// The canvas painter for a [GameState].
class _GamePainter extends CustomPainter {
  const _GamePainter({
    required this.state,
    required this.engine,
    required this.aimAngle,
    required this.hasPointer,
    required this.bubbleSize,
    required this.offsetX,
    required this.offsetY,
    this.bigPopElapsedMs,
  });

  final GameState state;
  final Engine engine;
  final double aimAngle;
  final bool hasPointer;
  final double bubbleSize;
  final double offsetX;
  final double offsetY;

  /// Milliseconds since the "BIG POP!" banner was triggered (null = none).
  final int? bigPopElapsedMs;

  static const Map<BubbleColor, Color> _colors = {
    BubbleColor.red: Color(0xFFE53935),
    BubbleColor.green: Color(0xFF43A047),
    BubbleColor.blue: Color(0xFF1E88E5),
    BubbleColor.yellow: Color(0xFFFDD835),
    BubbleColor.purple: Color(0xFF8E24AA),
    BubbleColor.orange: Color(0xFFFB8C00),
  };

  @override
  void paint(Canvas canvas, Size size) {
    // Background.
    final bg = Paint()..color = const Color(0xFF0B1E3A);
    canvas.drawRect(Offset.zero & size, bg);

    Offset boardToScreen(double x, double y) =>
        Offset(x * bubbleSize + offsetX, y * bubbleSize + offsetY);

    // Aim line (dotted).
    if (hasPointer && state.projectile == null &&
        state.status == GameStatus.playing) {
      final cannon = boardToScreen(engine.cannonX, engine.cannonY);
      const len = 3.5;
      final end = Offset(
        cannon.dx + math.sin(aimAngle) * len * bubbleSize,
        cannon.dy - math.cos(aimAngle) * len * bubbleSize,
      );
      final line = Paint()
        ..color = const Color(0x66FFFFFF)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final dashes = <Path>[];
      const dashLen = 0.15;
      for (var d = 0.0; d < len; d += dashLen * 2) {
        final t0 = d / len;
        final t1 = math.min(1.0, (d + dashLen) / len);
        final p0 = Offset.lerp(cannon, end, t0)!;
        final p1 = Offset.lerp(cannon, end, t1)!;
        dashes.add(Path()..moveTo(p0.dx, p0.dy)..lineTo(p1.dx, p1.dy));
      }
      for (final p in dashes) {
        canvas.drawPath(p, line);
      }
    }

    // Bubbles.
    for (final b in state.bubbles.values) {
      final (cx, cy) = engine.centerOf(b.row, b.col);
      final c = boardToScreen(cx, cy);
      _drawBubble(canvas, c, bubbleSize * 0.48, _colors[b.color]!);
    }

    // Projectile.
    final proj = state.projectile;
    if (proj != null) {
      final c = boardToScreen(proj.x, proj.y);
      _drawBubble(canvas, c, bubbleSize * 0.48, _colors[proj.color]!);
    }

    // Cannon.
    final cannon = boardToScreen(engine.cannonX, engine.cannonY);
    _drawCannon(canvas, cannon, bubbleSize * 0.55, aimAngle);

    // Death line (subtle).
    final deathY = boardToScreen(0, engine.rows.toDouble()).dy;
    final line = Paint()
      ..color = const Color(0x33FF5252)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, deathY), Offset(size.width, deathY), line);

    // Level progress bar: how close the board is to being cleared.
    final total = state.initialBubbleCount;
    if (total > 0) {
      final progress =
          ((total - state.bubbles.length) / total).clamp(0.0, 1.0);
      const barH = 4.0;
      final barW = size.width * 0.8;
      final barX = (size.width - barW) / 2;
      final barY = size.height - 10;
      final track = Paint()..color = const Color(0x33FFFFFF);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(barX, barY, barW, barH), const Radius.circular(2)),
        track,
      );
      if (progress > 0) {
        final fill = Paint()..color = const Color(0xCC66BB6A);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(barX, barY, barW * progress, barH),
              const Radius.circular(2)),
          fill,
        );
      }
    }

    // "BIG POP!" banner: slides in from the top (300 ms), holds (400 ms),
    // fades out (500 ms).
    if (bigPopElapsedMs != null) {
      const slideIn = 300.0;
      const hold = 400.0;
      const fade = 500.0;
      final t = bigPopElapsedMs!.toDouble();
      if (t < slideIn + hold + fade) {
        final bannerH = 40.0;
        final targetY = size.height * 0.18;
        double y;
        double alpha;
        if (t < slideIn) {
          final k = t / slideIn;
          final eased = 1 - (1 - k) * (1 - k); // ease-out
          y = -bannerH + (targetY + bannerH) * eased;
          alpha = 1.0;
        } else if (t < slideIn + hold) {
          y = targetY;
          alpha = 1.0;
        } else {
          y = targetY;
          alpha = 1.0 - (t - slideIn - hold) / fade;
        }
        final tp = TextPainter(
          text: TextSpan(
            text: 'BIG POP!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFD54F)
                  .withAlpha((alpha * 255).round()),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset((size.width - tp.width) / 2, y));
      }
    }
  }

  void _drawBubble(Canvas canvas, Offset center, double radius, Color color) {
    final base = Paint()..color = color;
    canvas.drawCircle(center, radius, base);
    // Glossy highlight.
    final hl = Paint()
      ..color = color.withAlpha(160)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(
      center - Offset(radius * 0.3, radius * 0.35),
      radius * 0.35,
      hl,
    );
    // Rim.
    final rim = Paint()
      ..color = Colors.black.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius - 0.5, rim);
  }

  void _drawCannon(Canvas canvas, Offset center, double size, double angle) {
    // Barrel: a rotated rectangle pointing in the aim direction.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-angle);
    final barrel = Paint()..color = const Color(0xFFB0BEC5);
    final r = Rect.fromCenter(center: Offset(0, -size * 0.5),
        width: size * 0.5, height: size);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), barrel);
    canvas.restore();
    // Base circle.
    final base = Paint()..color = const Color(0xFF37474F);
    canvas.drawCircle(center, size * 0.45, base);
    final inner = Paint()..color = const Color(0xFF546E7A);
    canvas.drawCircle(center, size * 0.28, inner);
  }

  @override
  bool shouldRepaint(_GamePainter old) =>
      old.state != state || old.aimAngle != aimAngle ||
      old.bubbleSize != bubbleSize || old.offsetX != offsetX || old.offsetY != offsetY ||
      old.hasPointer != hasPointer || old.bigPopElapsedMs != bigPopElapsedMs;
}

/// The top-of-screen HUD: score, lives, level, and the next-colors queue.
class _Hud extends StatelessWidget {
  const _Hud({required this.state, required this.onRestart});

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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
            children: [
              Expanded(
                child: Column(
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
                    // Combo streak: visible while 2+ consecutive pops.
                    if (state.combo >= 2)
                      Text(
                        'COMBO ×${state.combo}',
                        style: const TextStyle(
                            color: Color(0xFFFFB300),
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
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
              ...state.nextColors.map((c) {
                return Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _colors[c],
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                );
              }),
              IconButton(
                onPressed: onRestart,
                icon: const Icon(Icons.refresh,
                    color: Color(0xFFB0BEC5), size: 18),
                tooltip: 'Restart level',
              ),
            ],
          ),
        ),
    );
  }
}

/// A modal shown when the game is won or lost.
class _StatusOverlay extends StatelessWidget {
  const _StatusOverlay({required this.state, required this.onRestart});

  final GameState state;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final won = state.status == GameStatus.won;
    final lost = state.status == GameStatus.lost;
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Card(
        color: const Color(0xFF0B1E3A),
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won
                    ? 'LEVEL ${state.level} CLEARED!'
                    : 'GAME OVER',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFDD835),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Score: ${state.score}',
                style: const TextStyle(
                    color: Color(0xFFFFFFFF), fontSize: 20),
              ),
              if (won) ...[
                const SizedBox(height: 8),
                Text(
                  'Level ${state.level + 1} awaits!',
                  style: const TextStyle(
                      color: Color(0xFFFFFFFF), fontSize: 16),
                ),
              ],
              if (lost) ...[
                const SizedBox(height: 8),
                Text(
                  state.lives > 0
                      ? 'You have ${state.lives} lives left — tap to continue'
                      : 'No lives remaining',
                  style: const TextStyle(
                      color: Color(0xFFFFFFFF), fontSize: 16),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onRestart,
                child: Text(
                  won
                      ? 'CONTINUE'
                      : (lost && state.lives > 0 ? 'CONTINUE' : 'PLAY AGAIN'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

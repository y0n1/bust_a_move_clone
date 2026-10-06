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
    if (_state.projectile != null && _state.status == GameStatus.playing) {
      _state = _engine.tick(_state);
    }
    if (!mounted) return;
    setState(() {});
  }

  /// Convert a pointer in logical pixels to a board-space aim angle.
  void _updateAim(Offset globalPos, Size playfieldSize) {
    if (playfieldSize.width == 0 || playfieldSize.height == 0) return;
    final cannonX = _engine.cannonX;
    final cannonY = _engine.cannonY;
    // Convert the cannon to logical pixels.
    final px = _boardToScreen(cannonX, cannonY, playfieldSize);
    final dx = globalPos.dx - px.dx;
    final dy = globalPos.dy - px.dy;
    // Only allow aiming upward (dy < 0 in screen space).
    var angle = math.atan2(dx, -dy);
    // Clamp to a reasonable range: -60° to +60° from vertical.
    const maxAngle = math.pi / 3;
    if (angle > maxAngle) angle = maxAngle;
    if (angle < -maxAngle) angle = -maxAngle;
    _aimAngle = angle;
  }

  /// Convert a board-space point to logical pixels given the playfield size.
  Offset _boardToScreen(double x, double y, Size size) {
    // The playfield is `cols` bubbles wide and `rows + 1.2` bubbles tall.
    final bubble = size.width / _engine.cols;
    return Offset(
      (x - 0.5) * bubble + size.width / 2, // center the board
      (y - 0.0) * bubble,
    );
  }

  void _fire() {
    if (_state.projectile != null || _state.status != GameStatus.playing) return;
    _state = _engine.shoot(_state, _aimAngle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1E3A),
      body: LayoutBuilder(builder: (context, constraints) {
        final size = constraints.biggest;
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
                ),
                child: const SizedBox.expand(),
              ),
            ),
            _Hud(state: _state, onRestart: _restart),
            if (_state.status != GameStatus.playing)
              _StatusOverlay(state: _state, onRestart: _restart),
          ],
        );
      }),
    );
  }

  void _restart() {
    _state = _engine.startLevel();
    _aimAngle = 0;
    _hasPointer = false;
  }
}

/// The canvas painter for a [GameState].
class _GamePainter extends CustomPainter {
  const _GamePainter({
    required this.state,
    required this.engine,
    required this.aimAngle,
    required this.hasPointer,
  });

  final GameState state;
  final Engine engine;
  final double aimAngle;
  final bool hasPointer;

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

    final bubble = size.width / engine.cols;
    Offset boardToScreen(double x, double y) =>
        Offset((x - 0.5) * bubble + size.width / 2, y * bubble);

    // Aim line (dotted).
    if (hasPointer && state.projectile == null &&
        state.status == GameStatus.playing) {
      final cannon = boardToScreen(engine.cannonX, engine.cannonY);
      const len = 3.5;
      final end = Offset(
        cannon.dx + math.sin(aimAngle) * len * bubble,
        cannon.dy - math.cos(aimAngle) * len * bubble,
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
      _drawBubble(canvas, c, bubble * 0.48, _colors[b.color]!);
    }

    // Projectile.
    final proj = state.projectile;
    if (proj != null) {
      final c = boardToScreen(proj.x, proj.y);
      _drawBubble(canvas, c, bubble * 0.48, _colors[proj.color]!);
    }

    // Cannon.
    final cannon = boardToScreen(engine.cannonX, engine.cannonY);
    _drawCannon(canvas, cannon, bubble * 0.55, aimAngle);

    // Death line (subtle).
    final deathY = boardToScreen(0, engine.rows.toDouble()).dy + bubble * 0.5;
    final line = Paint()
      ..color = const Color(0x33FF5252)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, deathY), Offset(size.width, deathY), line);
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
      old.state != state || old.aimAngle != aimAngle;
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
    return Positioned(
      top: 8,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'SCORE ${state.score}',
                  style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
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
                won ? 'LEVEL CLEARED!' : 'GAME OVER',
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
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onRestart,
                child: const Text('PLAY AGAIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

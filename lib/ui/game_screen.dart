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

// ── Juice effect data ──────────────────────────────────────────────────

/// A floating score popup that rises and fades.
class _ScorePopup {
  const _ScorePopup({
    required this.text,
    required this.x,
    required this.y,
    required this.createdAt,
  });

  final String text;
  final double x; // board-space
  final double y; // board-space
  final Duration createdAt;
}

/// A single particle in a burst.
class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.createdAt,
  });

  double x, y;
  final double vx, vy;
  final Color color;
  final Duration createdAt;
}

/// A burst of particles at a location.
class _ParticleBurst {
  _ParticleBurst({
    required this.x,
    required this.y,
    required this.color,
    required this.particles,
    required this.createdAt,
  });

  final double x, y;
  final Color color;
  final List<_Particle> particles;
  final Duration createdAt;
}

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

  /// Lightweight RNG for juice-effect randomness (independent of engine RNG).
  final math.Random _rng = math.Random();

  math.Random get rng => _rng;

  /// Layout state: bubble size in pixels and offset to center the board.
  double _bubbleSize = 0;
  double _offsetX = 0;
  double _offsetY = 0;

  /// Ticker time when the "BIG POP!" banner started (null = not active).
  Duration? _bigPopAt;

  /// Milliseconds since the banner started; passed to the painter.
  int? _bigPopElapsedMs;

  // ── Juice effects ──────────────────────────────────────────────────────
  /// Active score popups: (text, board-space centroid, time of creation).
  final List<_ScorePopup> _popups = [];

  /// Active particle bursts: (center, color, particles).
  final List<_ParticleBurst> _bursts = [];

  /// Screen-shake elapsed ms (null = none active).
  int? _shakeElapsedMs;

  /// Projectile trail positions (board-space), oldest first.
  final List<Offset> _trail = [];

  /// Cannon recoil elapsed ms (null = none active).
  int? _recoilElapsedMs;

  /// Global effect timer (ms since last level start/restart).
  int _fxElapsedMs = 0;

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

    // Detect a settle: projectile was in flight, now settled.
    final settled = prev.projectile != null && _state.projectile == null;

    // BIG POP banner (5+ pops).
    if (settled && _state.poppedThisShot >= 5) {
      _bigPopAt = elapsed;
    }

    // ── Juice effects on settle ──────────────────────────────────────
    if (settled && _state.poppedThisShot > 0) {
      final popped = _state.poppedThisShot;

      // Approximate centroid from the projectile's last known position.
      final proj = prev.projectile!;
      final cx = proj.x;
      final cy = proj.y;

      // Score popup.
      final scoreText = '+${_state.score > 0 ? _state.score : 0}';
      _popups.add(_ScorePopup(
        text: scoreText,
        x: cx,
        y: cy,
        createdAt: elapsed,
      ));

      // Particle burst.
      final palette = <Color>[
        const Color(0xFFE53935),
        const Color(0xFF43A047),
        const Color(0xFF1E88E5),
        const Color(0xFFFDD835),
        const Color(0xFF8E24AA),
        const Color(0xFFFB8C00),
      ];
      final color = palette[_state.nextColors.first.index % palette.length];
      final particles = <_Particle>[];
      for (var i = 0; i < 8; i++) {
        final angle = (i / 8) * math.pi * 2 + (_rng.nextDouble() - 0.5) * 0.5;
        final speed = 0.02 + rng.nextDouble() * 0.03;
        particles.add(_Particle(
          x: cx,
          y: cy,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed,
          color: color,
          createdAt: elapsed,
        ));
      }
      _bursts.add(_ParticleBurst(
        x: cx,
        y: cy,
        color: color,
        particles: particles,
        createdAt: elapsed,
      ));

      // Screen shake on 4+ pops.
      if (popped >= 4) {
        _shakeElapsedMs = 0;
      }

      // Cannon recoil on any pop.
      if (popped >= 1) {
        _recoilElapsedMs = 0;
      }
    }

    // ── Update trail positions ───────────────────────────────────────
    if (_state.projectile != null) {
      final proj = _state.projectile!;
      _trail.add(Offset(proj.x, proj.y));
      while (_trail.length > 3) {
        _trail.removeAt(0);
      }
    } else {
      _trail.clear();
    }

    // ── Advance effect timers ────────────────────────────────────────
    final bigPopAt = _bigPopAt;
    _bigPopElapsedMs =
        bigPopAt == null ? null : (elapsed - bigPopAt).inMilliseconds;

    // Global FX timer increments each tick.
    _fxElapsedMs += elapsed.inMilliseconds;

    // Clean up expired popups (> 500ms).
    _popups.removeWhere((p) => (elapsed - p.createdAt).inMilliseconds > 500);

    // Clean up expired bursts (> 400ms).
    _bursts.removeWhere((b) => (elapsed - b.createdAt).inMilliseconds > 400);

    // Advance shake timer.
    if (_shakeElapsedMs != null) {
      _shakeElapsedMs = (_shakeElapsedMs!) + 16; // ~60fps tick
      if (_shakeElapsedMs! > 200) _shakeElapsedMs = null;
    }

    // Advance recoil timer.
    if (_recoilElapsedMs != null) {
      _recoilElapsedMs = (_recoilElapsedMs!) + 16;
      if (_recoilElapsedMs! > 100) _recoilElapsedMs = null;
    }

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
                        popups: _popups,
                        bursts: _bursts,
                        shakeElapsedMs: _shakeElapsedMs,
                        trail: _trail,
                        recoilElapsedMs: _recoilElapsedMs,
                        fxElapsedMs: _fxElapsedMs,
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
        // Reset the board with remaining lives, staying on the level.
        // (Unreachable today — the engine already resets the board on a
        // life loss — but must stay correct if that changes.)
        _state = _engine.startLevel(
            initialLives: _state.lives - 1, level: _state.level);
      } else {
        // Full restart (won and no lives, or lives == 0).
        _state = _engine.startLevel();
      }
      _aimAngle = 0;
      _hasPointer = false;
      _bigPopAt = null;
      _bigPopElapsedMs = null;
      _popups.clear();
      _bursts.clear();
      _shakeElapsedMs = null;
      _trail.clear();
      _recoilElapsedMs = null;
      _fxElapsedMs = 0;
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
    this.popups = const [],
    this.bursts = const [],
    this.shakeElapsedMs,
    this.trail = const [],
    this.recoilElapsedMs,
    this.fxElapsedMs = 0,
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

  /// Active score popups.
  final List<_ScorePopup> popups;

  /// Active particle bursts.
  final List<_ParticleBurst> bursts;

  /// Screen-shake elapsed ms (null = none active).
  final int? shakeElapsedMs;

  /// Projectile trail positions (board-space), oldest first.
  final List<Offset> trail;

  /// Cannon recoil elapsed ms (null = none active).
  final int? recoilElapsedMs;

  /// Global FX timer in ms.
  final int fxElapsedMs;

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

    // Screen shake offset.
    double shakeDx = 0, shakeDy = 0;
    if (shakeElapsedMs != null && shakeElapsedMs! < 200) {
      final t = shakeElapsedMs!.toDouble();
      // Pseudo-random jitter: use sine waves with different frequencies.
      shakeDx = math.sin(t * 0.5) * 2.0;
      shakeDy = math.cos(t * 0.7) * 2.0;
      canvas.save();
      canvas.translate(shakeDx, shakeDy);
    }

    // Current time for effect animations.
    final elapsed = Duration(milliseconds: fxElapsedMs);

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

    // Cannon (with recoil offset).
    final cannon = boardToScreen(engine.cannonX, engine.cannonY);
    double recoilOffset = 0;
    if (recoilElapsedMs != null && recoilElapsedMs! < 100) {
      // Recoil: kick back along the aim axis, then return.
      recoilOffset = math.cos(recoilElapsedMs!.toDouble() / 100 * math.pi) * 2.0;
    }
    _drawCannon(canvas, Offset(cannon.dx, cannon.dy), bubbleSize * 0.55, aimAngle, recoilOffset: recoilOffset);

    // Projectile trail: 3 ghost positions at decreasing opacity.
    for (var i = 0; i < trail.length; i++) {
      final pos = trail[i];
      final alpha = ((i + 1) / trail.length * 0.5 * 255).round().clamp(0, 255);
      final ghostPaint = Paint()
        ..color = const Color(0xFFFFFFFF).withAlpha(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
      canvas.drawCircle(
        boardToScreen(pos.dx, pos.dy),
        bubbleSize * 0.35,
        ghostPaint,
      );
    }

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

    // Particle bursts: each particle moves outward and fades over 400ms.
    for (final burst in bursts) {
      final age = (elapsed - burst.createdAt).inMilliseconds;
      if (age > 400) continue;
      final progress = age / 400.0;
      final alpha = ((1 - progress) * 255).round().clamp(0, 255);
      for (final p in burst.particles) {
        // Update position.
        p.x += p.vx;
        p.y += p.vy;
        final px = boardToScreen(p.x, p.y);
        final particlePaint = Paint()
          ..color = p.color.withAlpha(alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
        canvas.drawCircle(px, bubbleSize * 0.15, particlePaint);
      }
    }

    // Score popups: rise 30px and fade over 500ms.
    for (final popup in popups) {
      final age = (elapsed - popup.createdAt).inMilliseconds;
      if (age > 500) continue;
      final progress = age / 500.0;
      final alpha = ((1 - progress) * 255).round().clamp(0, 255);
      final rise = 30 * progress;
      final popupPos = boardToScreen(popup.x, popup.y - rise / bubbleSize);
      final tp = TextPainter(
        text: TextSpan(
          text: popup.text,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFFD54F).withAlpha(alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(popupPos.dx - tp.width / 2, popupPos.dy - tp.height / 2));
    }

    // "BIG POP!" banner: slides in from the top (300 ms), holds (400 ms),
    // fades out (500 ms).
    if (shakeElapsedMs != null && shakeElapsedMs! < 200) {
      canvas.restore();
    }
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

  void _drawCannon(Canvas canvas, Offset center, double size, double angle,
      {double recoilOffset = 0}) {
    // Barrel: a rotated rectangle pointing in the aim direction.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    // Apply recoil offset along the barrel axis (negative y in local space).
    canvas.translate(0, recoilOffset);
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
      old.hasPointer != hasPointer || old.bigPopElapsedMs != bigPopElapsedMs ||
      old.popups != popups || old.bursts != bursts ||
      old.shakeElapsedMs != shakeElapsedMs || old.trail != trail ||
      old.recoilElapsedMs != recoilElapsedMs || old.fxElapsedMs != fxElapsedMs;
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
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // First color (about to fire): large + highlighted.
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
                  // Remaining queue: small circles.
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

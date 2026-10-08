/// The gameplay screen: canvas rendering of [GameState], pointer input for
/// aiming and firing, and a simple HUD.
///
/// The engine is the source of truth; this widget only holds a [GameState]
/// and replaces it wholesale on every tick / shot.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../game/engine.dart';
import '../../game/model.dart';
import 'hud/score_display.dart';
import 'hud/level_display.dart';
import 'renderer/bubble_renderer.dart';

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
  final double x;
  final double y;
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

  double _aimAngle = 0;
  bool _hasPointer = false;
  final math.Random _rng = math.Random();

  math.Random get rng => _rng;

  double _bubbleSize = 0;
  double _offsetX = 0;
  double _offsetY = 0;

  Duration? _bigPopAt;
  int? _bigPopElapsedMs;

  final List<_ScorePopup> _popups = [];
  final List<_ParticleBurst> _bursts = [];
  int? _shakeElapsedMs;
  final List<Offset> _trail = [];
  int? _recoilElapsedMs;
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
    final prev = _state;
    if (_state.projectile != null && _state.status == GameStatus.playing) {
      _state = _engine.tick(_state);
    }

    final settled = prev.projectile != null && _state.projectile == null;

    if (settled && _state.poppedThisShot >= 5) {
      _bigPopAt = elapsed;
    }

    if (settled && _state.poppedThisShot > 0) {
      final popped = _state.poppedThisShot;
      final proj = prev.projectile!;
      final cx = proj.x;
      final cy = proj.y;

      final scoreText = '+${_state.score > 0 ? _state.score : 0}';
      _popups.add(_ScorePopup(
        text: scoreText,
        x: cx,
        y: cy,
        createdAt: elapsed,
      ));

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

      if (popped >= 4) {
        _shakeElapsedMs = 0;
      }
      if (popped >= 1) {
        _recoilElapsedMs = 0;
      }
    }

    if (_state.projectile != null) {
      final proj = _state.projectile!;
      _trail.add(Offset(proj.x, proj.y));
      while (_trail.length > 3) {
        _trail.removeAt(0);
      }
    } else {
      _trail.clear();
    }

    final bigPopAt = _bigPopAt;
    _bigPopElapsedMs =
        bigPopAt == null ? null : (elapsed - bigPopAt).inMilliseconds;

    _fxElapsedMs += elapsed.inMilliseconds;

    _popups.removeWhere((p) => (elapsed - p.createdAt).inMilliseconds > 500);
    _bursts.removeWhere((b) => (elapsed - b.createdAt).inMilliseconds > 400);

    if (_shakeElapsedMs != null) {
      _shakeElapsedMs = (_shakeElapsedMs!) + 16;
      if (_shakeElapsedMs! > 200) _shakeElapsedMs = null;
    }

    if (_recoilElapsedMs != null) {
      _recoilElapsedMs = (_recoilElapsedMs!) + 16;
      if (_recoilElapsedMs! > 100) _recoilElapsedMs = null;
    }

    if (!mounted) return;
    setState(() {});
  }

  void _updateAim(Offset localPos, Size size) {
    if (size.width == 0 || size.height == 0) return;
    final cannonPx = _boardToScreen(_engine.cannonX, _engine.cannonY, size);
    final dx = localPos.dx - cannonPx.dx;
    final dy = localPos.dy - cannonPx.dy;
    var angle = math.atan2(dx, -dy);
    const maxAngle = math.pi / 3;
    if (angle > maxAngle) angle = maxAngle;
    if (angle < -maxAngle) angle = -maxAngle;
    _aimAngle = angle;
  }

  Offset _boardToScreen(double x, double y, Size size) {
    return Offset(x * _bubbleSize + _offsetX, y * _bubbleSize + _offsetY);
  }

  void _computeLayout(Size size) {
    final boardWidth = _engine.cols;
    final boardHeight = _engine.rows + 1.2;
    final aspectRatio = boardWidth / boardHeight;

    double bubble;
    if (size.width / size.height > aspectRatio) {
      bubble = size.height / boardHeight;
    } else {
      bubble = size.width / boardWidth;
    }

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
          _Hud(state: _state, onRestart: _restart),
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
                      painter: GamePainter(
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
              ),
            }),
          ),
        ],
      ),
    );
  }

  void _restart() {
    setState(() {
      if (_state.status == GameStatus.won) {
        _state = _engine.startLevel(level: _state.level + 1);
      } else if (_state.status == GameStatus.lost && _state.lives > 0) {
        _state = _engine.startLevel(
            initialLives: _state.lives - 1, level: _state.level);
      } else {
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

/// HUD widget — inline composite of score, level, and controls.
class _Hud extends StatelessWidget {
  const _Hud({required this.state, required this.onRestart});

  final GameState state;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: ScoreDisplay(state: state),
            ),
            LevelDisplay(state: state, onRestart: onRestart),
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

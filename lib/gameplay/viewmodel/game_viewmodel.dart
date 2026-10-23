/// GameViewModel — the ViewModel layer for the gameplay screen.
///
/// Holds the Engine and current GameState. The UI observes this ViewModel
/// and rebuilds on every tick. All mutations flow through the ViewModel,
/// which delegates to the Engine and returns new GameState snapshots.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../game/engine.dart';
import '../../game/model.dart';
import '../ui/renderer/bubble_renderer.dart';

class GameViewModel extends ChangeNotifier {
  GameViewModel(Engine engine) : _engine = engine, _state = engine.startLevel();

  final Engine _engine;
  GameState _state;

  Engine get engine => _engine;
  GameState get state => _state;

  int get cols => _engine.cols;
  int get rows => _engine.rows;
  double get cannonX => _engine.cannonX;
  double get cannonY => _engine.cannonY;

  bool get isPlaying => _state.status == GameStatus.playing;
  bool get isGameOver => _state.status != GameStatus.playing;

  final math.Random _rng = math.Random();

  math.Random get rng => _rng;

  Ticker? _ticker;

  // Juice effect state (owned by the ViewModel, not the engine).
  Duration? _bigPopAt;
  int? _bigPopElapsedMs;

  final List<ScorePopup> _popups = [];
  final List<ParticleBurst> _bursts = [];
  int? _shakeElapsedMs;
  final List<Offset> _trail = [];
  int? _recoilElapsedMs;
  int _fxElapsedMs = 0;

  List<ScorePopup> get popups => List.unmodifiable(_popups);
  List<ParticleBurst> get bursts => List.unmodifiable(_bursts);
  int? get shakeElapsedMs => _shakeElapsedMs;
  List<Offset> get trail => List.unmodifiable(_trail);
  int? get recoilElapsedMs => _recoilElapsedMs;
  int get fxElapsedMs => _fxElapsedMs;
  int? get bigPopElapsedMs => _bigPopElapsedMs;

  double _aimAngle = 0;
  bool _hasPointer = false;

  double get aimAngle => _aimAngle;
  bool get hasPointer => _hasPointer;

  double _bubbleSize = 0;
  double _offsetX = 0;
  double _offsetY = 0;

  double get bubbleSize => _bubbleSize;
  double get offsetX => _offsetX;
  double get offsetY => _offsetY;

  void init() {
    _state = _engine.startLevel();
    final ticker = Ticker(_onTick);
    _ticker = ticker;
    ticker.start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
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
      _popups.add(ScorePopup(
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
      final particles = <Particle>[];
      for (var i = 0; i < 8; i++) {
        final angle = (i / 8) * math.pi * 2 + (_rng.nextDouble() - 0.5) * 0.5;
        final speed = 0.02 + _rng.nextDouble() * 0.03;
        particles.add(Particle(
          x: cx,
          y: cy,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed,
          color: color,
          createdAt: elapsed,
        ));
      }
      _bursts.add(ParticleBurst(
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

    notifyListeners();
  }

  void updateAim(Offset localPos, Size size) {
    if (size.width == 0 || size.height == 0) return;
    final cannonPx = boardToScreen(_engine.cannonX, _engine.cannonY, size);
    final dx = localPos.dx - cannonPx.dx;
    final dy = localPos.dy - cannonPx.dy;
    var angle = math.atan2(dx, -dy);
    const maxAngle = math.pi / 3;
    if (angle > maxAngle) angle = maxAngle;
    if (angle < -maxAngle) angle = -maxAngle;
    _aimAngle = angle;
    _hasPointer = true;
    notifyListeners();
  }

  Offset boardToScreen(double x, double y, Size size) {
    return Offset(x * _bubbleSize + _offsetX, y * _bubbleSize + _offsetY);
  }

  void computeLayout(Size size) {
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

  void fire() {
    if (_state.projectile != null || _state.status != GameStatus.playing) return;
    _state = _engine.shoot(_state, _aimAngle);
    notifyListeners();
  }

  void restart() {
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
    notifyListeners();
  }
}

// ── Constants ─────────────────────────────────────────────────────────

/// Minimum supported viewport width (covers ~95% of smartphones).
const double minViewportWidth = 360;

/// Maximum supported viewport width (covers tablets and standard desktops).
const double maxViewportWidth = 1024;

/// Minimum bubble size in pixels (ensures touch targets ≥ 44px and text readable).
const double minBubbleSize = 32;

/// Maximum bubble size in pixels (prevents excessive scaling on large screens).
const double maxBubbleSize = 120;


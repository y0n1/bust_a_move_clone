/// Bubble rendering — CustomPainter extracted from the original GameScreen.
///
/// Contains [_GamePainter] which draws the board, bubbles, cannon,
/// projectile, trail, HUD overlay elements (death line, progress bar),
/// and juice effects (score popups, particle bursts, shake, BIG POP banner).
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../game/engine.dart';
import '../../game/model.dart';

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

/// The canvas painter for a [GameState].
class GamePainter extends CustomPainter {
  const GamePainter({
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

    // Level progress bar.
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

    // Particle bursts.
    for (final burst in bursts) {
      final age = (elapsed - burst.createdAt).inMilliseconds;
      if (age > 400) continue;
      final progress = age / 400.0;
      final alpha = ((1 - progress) * 255).round().clamp(0, 255);
      for (final p in burst.particles) {
        p.x += p.vx;
        p.y += p.vy;
        final px = boardToScreen(p.x, p.y);
        final particlePaint = Paint()
          ..color = p.color.withAlpha(alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
        canvas.drawCircle(px, bubbleSize * 0.15, particlePaint);
      }
    }

    // Score popups.
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

    // "BIG POP!" banner.
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
          final eased = 1 - (1 - k) * (1 - k);
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
    final hl = Paint()
      ..color = color.withAlpha(160)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(
      center - Offset(radius * 0.3, radius * 0.35),
      radius * 0.35,
      hl,
    );
    final rim = Paint()
      ..color = Colors.black.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius - 0.5, rim);
  }

  void _drawCannon(Canvas canvas, Offset center, double size, double angle,
      {double recoilOffset = 0}) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.translate(0, recoilOffset);
    final barrel = Paint()..color = const Color(0xFFB0BEC5);
    final r = Rect.fromCenter(center: Offset(0, -size * 0.5),
        width: size * 0.4, height: size);
    canvas.drawRect(r, barrel);
    // Base circle.
    final base = Paint()..color = const Color(0xFF78909C);
    canvas.drawCircle(Offset(0, 0), size * 0.6, base);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.aimAngle != aimAngle ||
        oldDelegate.hasPointer != hasPointer ||
        oldDelegate.bubbleSize != bubbleSize ||
        oldDelegate.offsetX != offsetX ||
        oldDelegate.offsetY != offsetY ||
        oldDelegate.bigPopElapsedMs != bigPopElapsedMs ||
        oldDelegate.popups != popups ||
        oldDelegate.bursts != bursts ||
        oldDelegate.shakeElapsedMs != shakeElapsedMs ||
        oldDelegate.trail != trail ||
        oldDelegate.recoilElapsedMs != recoilElapsedMs ||
        oldDelegate.fxElapsedMs != fxElapsedMs;
  }
}

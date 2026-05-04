import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'game_engine.dart';
import 'game_models.dart';

class GamePainter extends CustomPainter {
  final GameEngine engine;
  final ui.Image? playerSprite;
  final Map<EnemyType, ui.Image?> enemySprites;

  GamePainter(
    this.engine, {
    this.playerSprite,
    required this.enemySprites,
  }) : super(repaint: engine);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawStars(canvas);
    _drawParticles(canvas);
    _drawBullets(canvas);
    _drawEnemies(canvas);
    _drawPlayer(canvas);
  }

  // ── Background ────────────────────────────
  void _drawBackground(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF000510), Color(0xFF05001A)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  // ── Stars ─────────────────────────────────
  void _drawStars(Canvas canvas) {
    final paint = Paint();
    for (final s in engine.stars) {
      paint.color = Color.fromRGBO(200, 220, 255, 0.35 + s.size / 6);
      canvas.drawCircle(Offset(s.x, s.y), s.size / 2, paint);
    }
  }

  // ── Particles ─────────────────────────────
  void _drawParticles(Canvas canvas) {
    final paint = Paint();
    for (final p in engine.particles) {
      paint.color = p.color.withOpacity(p.life.clamp(0, 1));
      canvas.drawCircle(Offset(p.pos.x, p.pos.y), p.size * p.life, paint);
    }
  }

  // ── Bullets ── (data stream / bits theme) ─
  void _drawBullets(Canvas canvas) {
    // Player: cyan data packets
    final playerGlow = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final playerCore = Paint()..color = const Color(0xFF00E5FF);

    // Enemy: red glitch shots
    final enemyGlow = Paint()
      ..color = const Color(0xFFFF1744).withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final enemyCore = Paint()..color = const Color(0xFFFF1744);

    for (final b in engine.bullets) {
      final glow = b.isPlayer ? playerGlow : enemyGlow;
      final core = b.isPlayer ? playerCore : enemyCore;
      final rect = Rect.fromCenter(center: Offset(b.pos.x, b.pos.y), width: b.width, height: b.height);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      canvas.drawRRect(rrect, glow);
      canvas.drawRRect(rrect, core);
    }
  }

  // ── Enemies (AI logos) ────────────────────
  void _drawEnemies(Canvas canvas) {
    for (final e in engine.enemies) {
      canvas.save();
      canvas.translate(e.pos.x, e.pos.y);
      final sprite = enemySprites[e.type];
      final glow = Paint()
        ..color = e.color.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(Offset.zero, e.width * 0.55, glow);

      if (sprite != null) {
        _drawSprite(canvas, sprite, e.width, e.height);
      } else {
        _drawAILogo(canvas, e);
      }

      _drawHealthBar(canvas, e);
      canvas.restore();
    }
  }

  void _drawAILogo(Canvas canvas, Enemy e) {
    switch (e.type) {
      case EnemyType.basic:
        _drawChatGPTLogo(canvas, e.width * 0.46, e.color);
        break;
      case EnemyType.fast:
        _drawGeminiLogo(canvas, e.width * 0.46, e.color);
        break;
      case EnemyType.tank:
        _drawCopilotLogo(canvas, e.width * 0.46, e.color);
        break;
      case EnemyType.shooter:
        _drawGrokLogo(canvas, e.width * 0.46, e.color);
        break;
    }
  }

  // ── ChatGPT logo (hexagon + swirl) ────────
  void _drawChatGPTLogo(Canvas canvas, double r, Color col) {
    // Dark hexagon background
    final bgPaint = Paint()..color = const Color(0xFF10A37F).withOpacity(0.9);
    final borderPaint = Paint()
      ..color = const Color(0xFF10A37F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final hexPath = _hexPath(r);
    canvas.drawPath(hexPath, bgPaint);
    canvas.drawPath(hexPath, borderPaint);

    // Swirl symbol
    final swirlPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.13
      ..strokeCap = StrokeCap.round;
    final sr = r * 0.5;
    canvas.drawArc(Rect.fromCircle(center: Offset(0, -sr * 0.15), radius: sr * 0.7), pi * 0.1, pi * 1.7, false, swirlPaint);
    canvas.drawArc(Rect.fromCircle(center: Offset(0, sr * 0.15), radius: sr * 0.7), pi * 1.1, pi * 1.7, false, swirlPaint);
  }

  // ── Gemini logo (two-tone diamond) ────────
  void _drawGeminiLogo(Canvas canvas, double r, Color col) {
    final bgPaint = Paint()..color = const Color(0xFF1A1A2E).withOpacity(0.95);
    final circle = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawOval(circle, bgPaint);

    // Gemini star shape: 4-pointed star
    final starPaint1 = Paint()
      ..shader = ui.Gradient.linear(
        Offset(-r, 0), Offset(r, 0),
        [const Color(0xFF4285F4), const Color(0xFF9C27B0)],
      );
    final starPaint2 = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, -r), Offset(0, r),
        [const Color(0xFF4FC3F7), const Color(0xFFE040FB)],
      );

    final starPath1 = _fourPointStar(r * 0.82, r * 0.18, horizontal: true);
    final starPath2 = _fourPointStar(r * 0.82, r * 0.18, horizontal: false);
    canvas.drawPath(starPath1, starPaint1);
    canvas.drawPath(starPath2, starPaint2);
  }

  // ── Copilot logo (two overlapping circles) ─
  void _drawCopilotLogo(Canvas canvas, double r, Color col) {
    final bgPaint = Paint()..color = const Color(0xFF1A1A1A).withOpacity(0.95);
    canvas.drawOval(Rect.fromCircle(center: Offset.zero, radius: r), bgPaint);

    final borderPaint = Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(Rect.fromCircle(center: Offset.zero, radius: r), borderPaint);

    // Copilot "face" — two overlapping ovals (helmet-like)
    final leftPaint = Paint()
      ..color = const Color(0xFF0078D4)
      ..style = PaintingStyle.fill;
    final rightPaint = Paint()
      ..color = const Color(0xFF50E6FF)
      ..style = PaintingStyle.fill;

    final or_ = r * 0.52;
    final ox = r * 0.22;
    final oy = r * 0.05;
    canvas.drawOval(Rect.fromCenter(center: Offset(-ox, oy), width: or_ * 1.4, height: or_ * 1.7), leftPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(ox, oy), width: or_ * 1.4, height: or_ * 1.7), rightPaint);

    // Visor highlight
    final visorPaint = Paint()..color = Colors.white.withOpacity(0.25);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, -oy * 0.5), width: r * 0.55, height: r * 0.4), visorPaint);

    // Eyes
    final eyePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(-r * 0.2, r * 0.08), r * 0.1, eyePaint);
    canvas.drawCircle(Offset(r * 0.2, r * 0.08), r * 0.1, eyePaint);

    // Pupils
    final pupilPaint = Paint()..color = const Color(0xFF001A33);
    canvas.drawCircle(Offset(-r * 0.2, r * 0.1), r * 0.055, pupilPaint);
    canvas.drawCircle(Offset(r * 0.2, r * 0.1), r * 0.055, pupilPaint);
  }

  // ── Grok logo (X mark) ────────────────────
  void _drawGrokLogo(Canvas canvas, double r, Color col) {
    final bgPaint = Paint()..color = const Color(0xFF000000).withOpacity(0.92);
    canvas.drawOval(Rect.fromCircle(center: Offset.zero, radius: r), bgPaint);

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(Rect.fromCircle(center: Offset.zero, radius: r), borderPaint);

    // Bold "X" (xAI / Grok logo)
    final xPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = r * 0.28
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final xr = r * 0.52;
    canvas.drawLine(Offset(-xr, -xr), Offset(xr, xr), xPaint);
    canvas.drawLine(Offset(xr, -xr), Offset(-xr, xr), xPaint);

    // Inner dot
    canvas.drawCircle(Offset.zero, r * 0.09, Paint()..color = const Color(0xFF888888));
  }

  // ── Path helpers ──────────────────────────
  Path _hexPath(double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = pi / 6 + i * pi / 3;
      final x = r * cos(angle);
      final y = r * sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    return path..close();
  }

  Path _fourPointStar(double outerR, double innerR, {required bool horizontal}) {
    final path = Path();
    final angles = horizontal
        ? [0.0, pi / 2, pi, 3 * pi / 2]
        : [pi / 4, 3 * pi / 4, 5 * pi / 4, 7 * pi / 4];

    for (int i = 0; i < 4; i++) {
      final tipAngle = angles[i];
      final midAngle = tipAngle + pi / 4;
      final tx = outerR * cos(tipAngle);
      final ty = outerR * sin(tipAngle);
      final mx = innerR * cos(midAngle);
      final my = innerR * sin(midAngle);
      if (i == 0) {
        path.moveTo(tx, ty);
      } else {
        path.lineTo(mx, my);
        path.lineTo(tx, ty);
      }
    }
    // Close back through midpoints
    path.lineTo(innerR * cos(angles[0] - pi / 4), innerR * sin(angles[0] - pi / 4));
    return path..close();
  }

  void _drawHealthBar(Canvas c, Enemy e) {
    if (e.maxHealth <= 1) return;
    final w = e.width;
    final barW = w * 0.95;
    final barH = 5.0;
    final y = e.height / 2 + 8;
    final bg = Paint()..color = Colors.white.withOpacity(0.15);
    final fg = Paint()..color = Color.lerp(const Color(0xFFFF1744), const Color(0xFF00E676), e.health / e.maxHealth)!;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, y), width: barW, height: barH), const Radius.circular(3)), bg);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-barW / 2, y - barH / 2, barW * (e.health / e.maxHealth), barH), const Radius.circular(3)), fg);
  }

  // ══════════════════════════════════════════
  // ── Player: RAM Chip ──────────────────────
  // ══════════════════════════════════════════
  void _drawPlayer(Canvas canvas) {
    final p = engine.player;
    if (p.isInvincible && (DateTime.now().millisecondsSinceEpoch ~/ 100) % 2 == 0) return;

    canvas.save();
    canvas.translate(p.pos.x, p.pos.y);

    if (playerSprite != null) {
      _drawSprite(canvas, playerSprite!, p.width, p.height);
      canvas.restore();
      return;
    }

    // ── Thruster flames (bottom) ─────────────
    final flameTime = DateTime.now().millisecondsSinceEpoch / 80.0;
    final flicker = 0.85 + 0.15 * sin(flameTime);

    final flamePaint1 = Paint()
      ..color = const Color(0xFFFF6D00).withOpacity(0.9 * flicker)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final flamePaint2 = Paint()
      ..color = const Color(0xFFFFFF00).withOpacity(0.7 * flicker);

    // Left thruster
    _drawFlame(canvas, const Offset(-14, 18), flicker, flamePaint1, flamePaint2);
    // Right thruster
    _drawFlame(canvas, const Offset(14, 18), flicker, flamePaint1, flamePaint2);

    // ── Chip body glow ────────────────────────
    final chipGlow = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 52, height: 40), const Radius.circular(6)),
      chipGlow,
    );

    // ── PCB substrate (dark green board) ─────
    final pcbPaint = Paint()..color = const Color(0xFF1B5E20);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 48, height: 36), const Radius.circular(5)),
      pcbPaint,
    );

    // PCB texture lines
    final tracePaint = Paint()
      ..color = const Color(0xFF2E7D32).withOpacity(0.8)
      ..strokeWidth = 1.0;
    for (double tx = -20; tx <= 20; tx += 8) {
      canvas.drawLine(Offset(tx, -18), Offset(tx, 18), tracePaint);
    }
    for (double ty = -14; ty <= 14; ty += 7) {
      canvas.drawLine(const Offset(-24, 0), Offset(0, ty), tracePaint);
      canvas.drawLine(const Offset(24, 0), Offset(0, ty), tracePaint);
    }

    // ── Chip package (black IC body) ─────────
    final icPaint = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 40, height: 28), const Radius.circular(4)),
      icPaint,
    );

    // ── Chip border ───────────────────────────
    final icBorder = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 40, height: 28), const Radius.circular(4)),
      icBorder,
    );

    // ── Memory pins (left & right sides) ─────
    final pinPaint = Paint()
      ..color = const Color(0xFFB8860B)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final pinGlow = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.6)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final pinYs = [-10.0, -4.0, 2.0, 8.0];
    for (final py in pinYs) {
      // Left pins
      canvas.drawLine(Offset(-24, py), Offset(-20, py), pinGlow);
      canvas.drawLine(Offset(-24, py), Offset(-20, py), pinPaint);
      // Right pins
      canvas.drawLine(Offset(20, py), Offset(24, py), pinGlow);
      canvas.drawLine(Offset(20, py), Offset(24, py), pinPaint);
    }

    // ── RAM label ─────────────────────────────
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'RAM',
        style: TextStyle(
          color: Color(0xFF00E5FF),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -5));

    // ── Tiny LED indicators ───────────────────
    final ledActive = Paint()
      ..color = const Color(0xFF00FF41)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final ledDim = Paint()..color = const Color(0xFF003300);
    final ledPhase = (DateTime.now().millisecondsSinceEpoch ~/ 200) % 4;
    final ledXs = [-12.0, -4.0, 4.0, 12.0];
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(Offset(ledXs[i], 9), 2.0, i == ledPhase ? ledActive : ledDim);
    }

    // ── Corner notch (IC notch mark) ─────────
    final notchPaint = Paint()..color = const Color(0xFF333333);
    canvas.drawOval(Rect.fromCenter(center: const Offset(-18, -12), width: 5, height: 5), notchPaint);

    canvas.restore();
  }

  void _drawSprite(Canvas canvas, ui.Image sprite, double width, double height) {
    final src = Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble());
    final dst = Rect.fromCenter(center: Offset.zero, width: width, height: height);
    canvas.drawImageRect(sprite, src, dst, Paint());
  }

  void _drawFlame(Canvas canvas, Offset origin, double flicker, Paint paint1, Paint paint2) {
    final h = 14.0 * flicker;
    final w = 6.0;
    final flamePath = Path()
      ..moveTo(origin.dx - w / 2, origin.dy)
      ..quadraticBezierTo(origin.dx - w * 0.8, origin.dy + h * 0.5, origin.dx, origin.dy + h)
      ..quadraticBezierTo(origin.dx + w * 0.8, origin.dy + h * 0.5, origin.dx + w / 2, origin.dy)
      ..close();
    canvas.drawPath(flamePath, paint1);

    final innerPath = Path()
      ..moveTo(origin.dx - w * 0.3, origin.dy)
      ..quadraticBezierTo(origin.dx - w * 0.4, origin.dy + h * 0.45, origin.dx, origin.dy + h * 0.7)
      ..quadraticBezierTo(origin.dx + w * 0.4, origin.dy + h * 0.45, origin.dx + w * 0.3, origin.dy)
      ..close();
    canvas.drawPath(innerPath, paint2);
  }

  @override
  bool shouldRepaint(covariant GamePainter old) => true;
}

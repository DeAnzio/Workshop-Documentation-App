import 'dart:math';
import 'package:flutter/material.dart';
import 'game_engine.dart';
import 'game_models.dart';

class GamePainter extends CustomPainter {
  final GameEngine engine;
  GamePainter(this.engine) : super(repaint: engine);

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
        colors: [Color(0xFF000010), Color(0xFF0A001A)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  // ── Stars ─────────────────────────────────
  void _drawStars(Canvas canvas) {
    final paint = Paint();
    for (final s in engine.stars) {
      paint.color = Color.fromRGBO(255, 255, 255, 0.4 + s.size / 6);
      canvas.drawCircle(Offset(s.x, s.y), s.size / 2, paint);
    }
  }

  // ── Particles ─────────────────────────────
  void _drawParticles(Canvas canvas) {
    final paint = Paint();
    for (final p in engine.particles) {
      paint.color = p.color.withOpacity(p.life.clamp(0, 1) as double);
      canvas.drawCircle(Offset(p.pos.x, p.pos.y), p.size * p.life, paint);
    }
  }

  // ── Bullets ───────────────────────────────
  void _drawBullets(Canvas canvas) {
    final playerPaint = Paint()
      ..color = const Color(0xFF80D8FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final enemyPaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (final b in engine.bullets) {
      final paint = b.isPlayer ? playerPaint : enemyPaint;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(b.pos.x, b.pos.y),
          width: b.width,
          height: b.height,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  // ── Enemies ───────────────────────────────
  void _drawEnemies(Canvas canvas) {
    for (final e in engine.enemies) {
      canvas.save();
      canvas.translate(e.pos.x, e.pos.y);
      _drawEnemyShape(canvas, e);
      _drawHealthBar(canvas, e);
      canvas.restore();
    }
  }

  void _drawEnemyShape(Canvas canvas, Enemy e) {
    final paint = Paint()..color = e.color;
    final glowPaint = Paint()
      ..color = e.color.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final darkPaint = Paint()..color = e.color.withOpacity(0.6);

    switch (e.type) {
      case EnemyType.basic:
        _drawBasicEnemy(canvas, paint, glowPaint, darkPaint, e.width);
        break;
      case EnemyType.fast:
        _drawFastEnemy(canvas, paint, glowPaint, darkPaint, e.width);
        break;
      case EnemyType.tank:
        _drawTankEnemy(canvas, paint, glowPaint, darkPaint, e.width);
        break;
      case EnemyType.shooter:
        _drawShooterEnemy(canvas, paint, glowPaint, darkPaint, e.width);
        break;
    }
  }

  void _drawBasicEnemy(Canvas c, Paint p, Paint glow, Paint dark, double w) {
    final half = w / 2;
    // Glow
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.8), glow);
    // Wings
    final wingPath = Path()
      ..moveTo(0, -half * 0.5)
      ..lineTo(-half, half * 0.4)
      ..lineTo(-half * 0.5, half * 0.5)
      ..lineTo(0, half * 0.2)
      ..lineTo(half * 0.5, half * 0.5)
      ..lineTo(half, half * 0.4)
      ..close();
    c.drawPath(wingPath, p);
    // Body
    final bodyPath = Path()
      ..moveTo(0, -half * 0.8)
      ..lineTo(-half * 0.3, half * 0.5)
      ..lineTo(0, half * 0.3)
      ..lineTo(half * 0.3, half * 0.5)
      ..close();
    c.drawPath(bodyPath, dark);
    // Cockpit
    c.drawOval(Rect.fromCenter(center: Offset(0, -half * 0.2), width: half * 0.4, height: half * 0.5),
        Paint()..color = Colors.white.withOpacity(0.7));
  }

  void _drawFastEnemy(Canvas c, Paint p, Paint glow, Paint dark, double w) {
    final half = w / 2;
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: w * 0.8, height: w), glow);
    final path = Path()
      ..moveTo(0, -half)
      ..lineTo(-half * 0.6, half * 0.2)
      ..lineTo(-half * 0.9, half)
      ..lineTo(0, half * 0.5)
      ..lineTo(half * 0.9, half)
      ..lineTo(half * 0.6, half * 0.2)
      ..close();
    c.drawPath(path, p);
    c.drawPath(path, dark..color = p.color.withOpacity(0.4));
    // Engine glow
    c.drawOval(
        Rect.fromCenter(center: Offset(0, half * 0.7), width: half * 0.5, height: half * 0.3),
        Paint()..color = Colors.orangeAccent.withOpacity(0.9));
  }

  void _drawTankEnemy(Canvas c, Paint p, Paint glow, Paint dark, double w) {
    final half = w / 2;
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.9), const Radius.circular(8)),
        glow);
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.9), const Radius.circular(8)),
        p);
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w * 0.6, height: w * 0.7), const Radius.circular(5)),
        dark..color = p.color.withOpacity(0.8));
    // Armor lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 2;
    for (int i = -1; i <= 1; i++) {
      c.drawLine(Offset(i * half * 0.5, -half * 0.4), Offset(i * half * 0.5, half * 0.4), linePaint);
    }
    // Cockpit
    c.drawOval(Rect.fromCenter(center: Offset(0, -half * 0.15), width: half * 0.5, height: half * 0.4),
        Paint()..color = Colors.white.withOpacity(0.6));
  }

  void _drawShooterEnemy(Canvas c, Paint p, Paint glow, Paint dark, double w) {
    final half = w / 2;
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: w * 1.2, height: w * 0.8), glow);
    // Body
    final path = Path()
      ..moveTo(0, -half * 0.8)
      ..lineTo(-half * 0.5, half * 0.5)
      ..lineTo(0, half * 0.2)
      ..lineTo(half * 0.5, half * 0.5)
      ..close();
    c.drawPath(path, p);
    // Side cannons
    final cannonPaint = Paint()..color = p.color;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(-half * 0.8, 0), width: half * 0.3, height: half * 0.8), const Radius.circular(4)), cannonPaint);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(half * 0.8, 0), width: half * 0.3, height: half * 0.8), const Radius.circular(4)), cannonPaint);
    c.drawOval(Rect.fromCenter(center: Offset(0, 0), width: half * 0.5, height: half * 0.5),
        Paint()..color = Colors.cyanAccent.withOpacity(0.8));
  }

  void _drawHealthBar(Canvas c, Enemy e) {
    if (e.maxHealth <= 1) return;
    final w = e.width;
    final barW = w * 0.9;
    final barH = 5.0;
    final y = e.height / 2 + 6;
    final bg = Paint()..color = Colors.white.withOpacity(0.2);
    final fg = Paint()..color = Color.lerp(Colors.red, Colors.green, e.health / e.maxHealth)!;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, y), width: barW, height: barH), const Radius.circular(3)), bg);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-barW / 2, y - barH / 2, barW * (e.health / e.maxHealth), barH), const Radius.circular(3)), fg);
  }

  // ── Player ────────────────────────────────
  void _drawPlayer(Canvas canvas) {
    final p = engine.player;
    if (p.isInvincible && (DateTime.now().millisecondsSinceEpoch ~/ 100) % 2 == 0) return;

    canvas.save();
    canvas.translate(p.pos.x, p.pos.y);

    // Engine glow
    final engineGlow = Paint()
      ..color = const Color(0xFF40C4FF).withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 20), width: 20, height: 30), engineGlow);

    // Engine flame
    final flamePath = Path()
      ..moveTo(-8, 18)
      ..lineTo(0, 35)
      ..lineTo(8, 18);
    canvas.drawPath(flamePath, Paint()..color = Colors.orangeAccent.withOpacity(0.9));
    canvas.drawPath(flamePath, Paint()..color = Colors.yellow.withOpacity(0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // Body glow
    final bodyGlow = Paint()
      ..color = const Color(0xFF40C4FF).withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 44, height: 54), bodyGlow);

    // Fuselage
    final bodyPath = Path()
      ..moveTo(0, -27)
      ..lineTo(-8, 10)
      ..lineTo(-4, 20)
      ..lineTo(4, 20)
      ..lineTo(8, 10)
      ..close();
    canvas.drawPath(bodyPath, Paint()..color = const Color(0xFF1565C0));

    // Wings
    final wingPath = Path()
      ..moveTo(-8, 5)
      ..lineTo(-22, 18)
      ..lineTo(-14, 22)
      ..lineTo(-4, 18)
      ..moveTo(8, 5)
      ..lineTo(22, 18)
      ..lineTo(14, 22)
      ..lineTo(4, 18);
    canvas.drawPath(wingPath, Paint()..color = const Color(0xFF1E88E5));

    // Cockpit
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -12), width: 10, height: 14),
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.lightBlueAccent, Color(0xFF1565C0)],
        ).createShader(Rect.fromCenter(center: const Offset(0, -12), width: 10, height: 14)),
    );

    // Wing tip lights
    final tipPaint = Paint()..color = Colors.cyanAccent;
    canvas.drawCircle(const Offset(-22, 18), 2.5, tipPaint);
    canvas.drawCircle(const Offset(22, 18), 2.5, tipPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GamePainter old) => true;
}

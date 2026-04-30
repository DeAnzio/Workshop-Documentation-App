import 'dart:math';
import 'package:flutter/material.dart';

// ─── Vector2 helper ──────────────────────────────────────────────────────────
class Vec2 {
  double x, y;
  Vec2(this.x, this.y);
  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);
  Vec2 copy() => Vec2(x, y);
}

// ─── Bullet ──────────────────────────────────────────────────────────────────
class Bullet {
  Vec2 pos;
  Vec2 vel;
  bool isPlayer;
  bool dead = false;
  double width = 6;
  double height = 16;

  Bullet({required this.pos, required this.vel, required this.isPlayer});

  void update(double dt) {
    pos.x += vel.x * dt;
    pos.y += vel.y * dt;
  }

  Rect get rect => Rect.fromCenter(
        center: Offset(pos.x, pos.y),
        width: width,
        height: height,
      );
}

// ─── Particle ─────────────────────────────────────────────────────────────────
class Particle {
  Vec2 pos;
  Vec2 vel;
  Color color;
  double life; // 0..1
  double size;
  bool dead = false;

  Particle({
    required this.pos,
    required this.vel,
    required this.color,
    this.life = 1.0,
    this.size = 4,
  });

  void update(double dt) {
    pos.x += vel.x * dt;
    pos.y += vel.y * dt;
    life -= dt * 1.8;
    if (life <= 0) dead = true;
  }
}

// ─── Star (background) ───────────────────────────────────────────────────────
class Star {
  double x, y, speed, size;
  Star({required this.x, required this.y, required this.speed, required this.size});
}

// ─── Player ──────────────────────────────────────────────────────────────────
class Player {
  Vec2 pos;
  double width = 44;
  double height = 54;
  int lives = 3;
  int score = 0;
  double shootCooldown = 0;
  double invincibleTimer = 0;

  Player({required this.pos});

  Rect get rect => Rect.fromCenter(
        center: Offset(pos.x, pos.y),
        width: width * 0.7,
        height: height * 0.8,
      );

  bool get isInvincible => invincibleTimer > 0;

  void update(double dt) {
    if (shootCooldown > 0) shootCooldown -= dt;
    if (invincibleTimer > 0) invincibleTimer -= dt;
  }
}

// ─── Enemy types ─────────────────────────────────────────────────────────────
enum EnemyType { basic, fast, tank, shooter }

class Enemy {
  Vec2 pos;
  Vec2 vel;
  EnemyType type;
  int health;
  int maxHealth;
  double width;
  double height;
  bool dead = false;
  double shootCooldown;
  double shootInterval;
  double zigzagTimer = 0;
  double amplitude;

  Enemy({
    required this.pos,
    required this.vel,
    required this.type,
    required this.health,
    required this.width,
    required this.height,
    required this.shootInterval,
    required this.amplitude,
  })  : maxHealth = health,
        shootCooldown = Random().nextDouble() * 2;

  Rect get rect => Rect.fromCenter(
        center: Offset(pos.x, pos.y),
        width: width * 0.75,
        height: height * 0.75,
      );

  int get scoreValue {
    switch (type) {
      case EnemyType.basic:
        return 10;
      case EnemyType.fast:
        return 20;
      case EnemyType.tank:
        return 50;
      case EnemyType.shooter:
        return 30;
    }
  }

  Color get color {
    switch (type) {
      case EnemyType.basic:
        return const Color(0xFF10A37F); // ChatGPT green
      case EnemyType.fast:
        return const Color(0xFF4285F4); // Gemini blue
      case EnemyType.tank:
        return const Color(0xFF0078D4); // Copilot blue
      case EnemyType.shooter:
        return const Color(0xFFCCCCCC); // Grok/xAI white-grey
    }
  }

  void update(double dt, double screenWidth) {
    zigzagTimer += dt;
    pos.x += vel.x * dt + sin(zigzagTimer * 2.5) * amplitude * dt;
    pos.y += vel.y * dt;

    // Bounce horizontally
    if (pos.x < width / 2) {
      pos.x = width / 2;
      vel.x = vel.x.abs();
    }
    if (pos.x > screenWidth - width / 2) {
      pos.x = screenWidth - width / 2;
      vel.x = -vel.x.abs();
    }

    if (shootCooldown > 0) shootCooldown -= dt;
  }
}

// ─── Factory ─────────────────────────────────────────────────────────────────
Enemy spawnEnemy(EnemyType type, double screenWidth, double wave) {
  final rng = Random();
  final x = rng.nextDouble() * (screenWidth - 60) + 30;
  final waveBonus = wave * 0.15;

  switch (type) {
    case EnemyType.basic:
      return Enemy(
        pos: Vec2(x, -30),
        vel: Vec2((rng.nextDouble() - 0.5) * 60, 90 + waveBonus * 40),
        type: type,
        health: 1,
        width: 40,
        height: 40,
        shootInterval: 999,
        amplitude: 40,
      );
    case EnemyType.fast:
      return Enemy(
        pos: Vec2(x, -30),
        vel: Vec2((rng.nextDouble() - 0.5) * 100, 160 + waveBonus * 50),
        type: type,
        health: 1,
        width: 32,
        height: 32,
        shootInterval: 999,
        amplitude: 60,
      );
    case EnemyType.tank:
      return Enemy(
        pos: Vec2(x, -30),
        vel: Vec2((rng.nextDouble() - 0.5) * 40, 55 + waveBonus * 20),
        type: type,
        health: 4 + wave.toInt(),
        width: 56,
        height: 52,
        shootInterval: 999,
        amplitude: 20,
      );
    case EnemyType.shooter:
      return Enemy(
        pos: Vec2(x, -30),
        vel: Vec2((rng.nextDouble() - 0.5) * 50, 70 + waveBonus * 30),
        type: type,
        health: 2,
        width: 42,
        height: 42,
        shootInterval: 2.2 - waveBonus * 0.3,
        amplitude: 30,
      );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'game_models.dart';

enum GameState { menu, playing, paused, gameOver }

class GameEngine extends ChangeNotifier {
  // ── Screen dimensions set on first layout ──
  double screenW = 400;
  double screenH = 800;

  // ── State ──────────────────────────────────
  GameState state = GameState.menu;

  late Player player;
  final List<Enemy> enemies = [];
  final List<Bullet> bullets = [];
  final List<Particle> particles = [];
  final List<Star> stars = [];

  int wave = 1;
  double waveTimer = 0;
  double spawnTimer = 0;
  double spawnInterval = 1.8;
  int enemiesThisWave = 0;
  int enemiesKilledThisWave = 0;
  int enemiesPerWave = 8;

  final _rng = Random();
  DateTime? _lastTick;

  // ── Input ──────────────────────────────────
  double _dragX = 0;
  double _dragY = 0;
  bool _isDragging = false;

  // ─────────────────────────────────────────────────────────────────────────
  void init(double w, double h) {
    screenW = w;
    screenH = h;
    _generateStars();
  }

  void _generateStars() {
    stars.clear();
    for (int i = 0; i < 80; i++) {
      stars.add(Star(
        x: _rng.nextDouble() * screenW,
        y: _rng.nextDouble() * screenH,
        speed: 30 + _rng.nextDouble() * 80,
        size: 0.8 + _rng.nextDouble() * 2.2,
      ));
    }
  }

  void startGame() {
    player = Player(pos: Vec2(screenW / 2, screenH * 0.82));
    enemies.clear();
    bullets.clear();
    particles.clear();
    wave = 1;
    waveTimer = 0;
    spawnTimer = 0;
    spawnInterval = 1.8;
    enemiesThisWave = 0;
    enemiesKilledThisWave = 0;
    enemiesPerWave = 8;
    state = GameState.playing;
    _lastTick = DateTime.now();
    notifyListeners();
  }

  void togglePause() {
    if (state == GameState.playing) {
      state = GameState.paused;
    } else if (state == GameState.paused) {
      state = GameState.playing;
      _lastTick = DateTime.now();
    }
    notifyListeners();
  }

  // ── Drag controls ─────────────────────────
  void onDragStart(Offset pos) {
    _isDragging = true;
    _dragX = pos.dx;
    _dragY = pos.dy;
  }

  void onDragUpdate(Offset pos) {
    if (!_isDragging || state != GameState.playing) return;
    final dx = pos.dx - _dragX;
    final dy = pos.dy - _dragY;
    _dragX = pos.dx;
    _dragY = pos.dy;

    player.pos.x = (player.pos.x + dx).clamp(player.width / 2, screenW - player.width / 2);
    player.pos.y = (player.pos.y + dy).clamp(screenH * 0.4, screenH - player.height / 2);
  }

  void onDragEnd() => _isDragging = false;

  void onGyroInput(double dx, double dy) {
    if (state != GameState.playing) return;
    player.pos.x = (player.pos.x + dx).clamp(player.width / 2, screenW - player.width / 2);
    player.pos.y = (player.pos.y + dy).clamp(screenH * 0.4, screenH - player.height / 2);
    notifyListeners();
  }

  // ── Main tick ─────────────────────────────
  void tick() {
    if (state != GameState.playing) return;

    final now = DateTime.now();
    final dt = min((_lastTick == null ? 0.0 : now.difference(_lastTick!).inMicroseconds / 1e6), 0.05).toDouble();
    _lastTick = now;

    _updateStars(dt);
    _updatePlayer(dt);
    _updateEnemies(dt);
    _updateBullets(dt);
    _updateParticles(dt);
    _checkCollisions();
    _handleSpawning(dt);
    _cleanUp();

    notifyListeners();
  }

  // ── Stars ─────────────────────────────────
  void _updateStars(double dt) {
    for (final s in stars) {
      s.y += s.speed * dt;
      if (s.y > screenH) {
        s.y = -2;
        s.x = _rng.nextDouble() * screenW;
      }
    }
  }

  // ── Player ────────────────────────────────
  void _updatePlayer(double dt) {
    player.update(dt);

    // Auto-shoot
    if (player.shootCooldown <= 0) {
      _spawnPlayerBullet();
      player.shootCooldown = 0.22;
    }
  }

  void _spawnPlayerBullet() {
    bullets.add(Bullet(
      pos: Vec2(player.pos.x - 10, player.pos.y - 20),
      vel: Vec2(0, -600),
      isPlayer: true,
    ));
    bullets.add(Bullet(
      pos: Vec2(player.pos.x + 10, player.pos.y - 20),
      vel: Vec2(0, -600),
      isPlayer: true,
    ));
  }

  // ── Enemies ───────────────────────────────
  void _updateEnemies(double dt) {
    for (final e in enemies) {
      e.update(dt, screenW);

      // Enemy shooting
      if (e.type == EnemyType.shooter && e.shootCooldown <= 0) {
        final angle = atan2(
          player.pos.y - e.pos.y,
          player.pos.x - e.pos.x,
        );
        bullets.add(Bullet(
          pos: Vec2(e.pos.x, e.pos.y + 10),
          vel: Vec2(cos(angle) * 200, sin(angle) * 200),
          isPlayer: false,
        ));
        e.shootCooldown = e.shootInterval;
      }

      // Off-screen bottom → lose life
      if (e.pos.y > screenH + 40) {
        e.dead = true;
        _hitPlayer();
      }
    }
  }

  // ── Bullets ───────────────────────────────
  void _updateBullets(double dt) {
    for (final b in bullets) {
      b.update(dt);
      if (b.pos.y < -20 || b.pos.y > screenH + 20 ||
          b.pos.x < -20 || b.pos.x > screenW + 20) {
        b.dead = true;
      }
    }
  }

  // ── Particles ─────────────────────────────
  void _updateParticles(double dt) {
    for (final p in particles) {
      p.update(dt);
    }
  }

  // ── Collisions ────────────────────────────
  void _checkCollisions() {
    for (final b in bullets) {
      if (b.dead) continue;

      if (b.isPlayer) {
        for (final e in enemies) {
          if (!e.dead && b.rect.overlaps(e.rect)) {
            b.dead = true;
            e.health--;
            _spawnHitParticles(e.pos, e.color, 5);
            if (e.health <= 0) {
              e.dead = true;
              player.score += e.scoreValue;
              enemiesKilledThisWave++;
              _spawnExplosion(e.pos, e.color);
            }
            break;
          }
        }
      } else {
        if (!player.isInvincible && b.rect.overlaps(player.rect)) {
          b.dead = true;
          _hitPlayer();
          _spawnHitParticles(player.pos, const Color(0xFF42A5F5), 8);
        }
      }
    }

    // Enemy–player collision
    if (!player.isInvincible) {
      for (final e in enemies) {
        if (!e.dead && e.rect.overlaps(player.rect)) {
          e.dead = true;
          _hitPlayer();
          _spawnExplosion(e.pos, e.color);
        }
      }
    }
  }

  void _hitPlayer() {
    player.lives--;
    player.invincibleTimer = 2.0;
    if (player.lives <= 0) {
      _spawnExplosion(player.pos, const Color(0xFF42A5F5));
      state = GameState.gameOver;
    }
  }

  // ── Particles helpers ─────────────────────
  void _spawnExplosion(Vec2 pos, Color color) {
    for (int i = 0; i < 24; i++) {
      final angle = _rng.nextDouble() * pi * 2;
      final speed = 60 + _rng.nextDouble() * 200;
      particles.add(Particle(
        pos: Vec2(pos.x, pos.y),
        vel: Vec2(cos(angle) * speed, sin(angle) * speed),
        color: color,
        size: 3 + _rng.nextDouble() * 5,
      ));
    }
  }

  void _spawnHitParticles(Vec2 pos, Color color, int count) {
    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * pi * 2;
      final speed = 40 + _rng.nextDouble() * 100;
      particles.add(Particle(
        pos: Vec2(pos.x, pos.y),
        vel: Vec2(cos(angle) * speed, sin(angle) * speed),
        color: color,
        size: 2 + _rng.nextDouble() * 3,
      ));
    }
  }

  // ── Spawning / waves ──────────────────────
  void _handleSpawning(double dt) {
    if (enemiesThisWave >= enemiesPerWave) {
      // Wait for all killed then next wave
      if (enemies.isEmpty) {
        waveTimer += dt;
        if (waveTimer >= 2.5) {
          wave++;
          waveTimer = 0;
          enemiesThisWave = 0;
          enemiesKilledThisWave = 0;
          enemiesPerWave = 8 + (wave - 1) * 2;
          spawnInterval = max(0.5, 1.8 - wave * 0.1);
        }
      }
      return;
    }

    spawnTimer += dt;
    if (spawnTimer >= spawnInterval) {
      spawnTimer = 0;
      _spawnRandomEnemy();
      enemiesThisWave++;
    }
  }

  void _spawnRandomEnemy() {
    EnemyType type;
    final r = _rng.nextDouble();
    if (wave < 2) {
      type = EnemyType.basic;
    } else if (wave < 4) {
      type = r < 0.6 ? EnemyType.basic : EnemyType.fast;
    } else {
      if (r < 0.35) {
        type = EnemyType.basic;
      } else if (r < 0.60) {
        type = EnemyType.fast;
      } else if (r < 0.80) {
        type = EnemyType.shooter;
      } else {
        type = EnemyType.tank;
      }
    }
    enemies.add(spawnEnemy(type, screenW, wave.toDouble()));
  }

  // ── Cleanup ───────────────────────────────
  void _cleanUp() {
    enemies.removeWhere((e) => e.dead);
    bullets.removeWhere((b) => b.dead);
    particles.removeWhere((p) => p.dead);
  }
}

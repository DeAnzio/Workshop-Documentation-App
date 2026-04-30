import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'game_engine.dart';
import 'game_painter.dart';
import 'hud_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final GameEngine _engine = GameEngine();
  Timer? _gameLoop;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  bool _gyroEnabled = false;
  double _smoothedGyroX = 0.0;
  double _smoothedGyroY = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLoop();
    _gyroSubscription = gyroscopeEvents.listen(_onGyroEvent);
  }

  void _startLoop() {
    _gameLoop = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _engine.tick();
    });
  }

  void _onGyroEvent(GyroscopeEvent event) {
    if (!_gyroEnabled || _engine.state != GameState.playing) return;
    const smoothing = 0.82;
    const deadzone = 0.02;
    const horizontalScale = 45.0;
    const verticalScale = 28.0;

    _smoothedGyroX = _smoothedGyroX * smoothing + event.y * (1 - smoothing);
    _smoothedGyroY = _smoothedGyroY * smoothing + event.x * (1 - smoothing);

    final rawDx = _smoothedGyroX.abs() > deadzone ? _smoothedGyroX : 0.0;
    final rawDy = _smoothedGyroY.abs() > deadzone ? _smoothedGyroY : 0.0;

    final dx = (rawDx * horizontalScale).clamp(-35.0, 35.0);
    final dy = (rawDy * verticalScale).clamp(-22.0, 22.0);

    _engine.onGyroInput(dx, dy);
  }

  void _toggleGyro() {
    setState(() {
      _gyroEnabled = !_gyroEnabled;
    });
  }

  @override
  void dispose() {
    _gameLoop?.cancel();
    _gyroSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _engine.state == GameState.playing) {
      _engine.togglePause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        if (_engine.screenW != w || _engine.screenH != h) {
          _engine.init(w, h);
        }

        return AnimatedBuilder(
          animation: _engine,
          builder: (context, _) {
            return GestureDetector(
              onPanStart: (d) => _engine.onDragStart(d.localPosition),
              onPanUpdate: (d) => _engine.onDragUpdate(d.localPosition),
              onPanEnd: (_) => _engine.onDragEnd(),
              child: Stack(
                children: [
                  // Game canvas
                  CustomPaint(
                    painter: GamePainter(_engine),
                    size: Size(w, h),
                    child: const SizedBox.expand(),
                  ),

                  // HUD (only when playing or paused)
                  if (_engine.state == GameState.playing || _engine.state == GameState.paused)
                    HudOverlay(
                      engine: _engine,
                      gyroEnabled: _gyroEnabled,
                      onToggleGyro: _toggleGyro,
                    ),

                  // Overlays
                  if (_engine.state == GameState.menu) _MenuOverlay(engine: _engine),
                  if (_engine.state == GameState.paused) _PauseOverlay(engine: _engine),
                  if (_engine.state == GameState.gameOver) _GameOverOverlay(engine: _engine),

                  // Wave announcement
                  if (_engine.state == GameState.playing && _engine.waveTimer > 0 && _engine.waveTimer < 1.5)
                    _WaveAnnouncement(wave: _engine.wave),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}

// ─── Menu ─────────────────────────────────────────────────────────────────────
class _MenuOverlay extends StatelessWidget {
  final GameEngine engine;
  const _MenuOverlay({required this.engine});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '🚀',
              style: TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.cyanAccent, Colors.blueAccent],
              ).createShader(bounds),
              child: const Text(
                'SPACE SHOOTER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Geser layar untuk mengendalikan pesawat',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            _GlowButton(
              label: 'MULAI GAME',
              onTap: engine.startGame,
              color: Colors.cyanAccent,
            ),
            const SizedBox(height: 32),
            const EnemyLegend(),
          ],
        ),
      ),
    );
  }
}

// ─── Pause ────────────────────────────────────────────────────────────────────
class _PauseOverlay extends StatelessWidget {
  final GameEngine engine;
  const _PauseOverlay({required this.engine});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'PAUSE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 32),
            _GlowButton(
              label: 'LANJUTKAN',
              onTap: engine.togglePause,
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 16),
            _GlowButton(
              label: 'MAIN LAGI',
              onTap: engine.startGame,
              color: Colors.orangeAccent,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Game Over ────────────────────────────────────────────────────────────────
class _GameOverOverlay extends StatelessWidget {
  final GameEngine engine;
  const _GameOverOverlay({required this.engine});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'GAME OVER',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                shadows: [Shadow(color: Colors.red, blurRadius: 20)],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Skor: ${engine.player.score}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Wave yang dicapai: ${engine.wave}',
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 40),
            _GlowButton(
              label: 'MAIN LAGI',
              onTap: engine.startGame,
              color: Colors.cyanAccent,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Wave Announcement ────────────────────────────────────────────────────────
class _WaveAnnouncement extends StatelessWidget {
  final int wave;
  const _WaveAnnouncement({required this.wave});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.3,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          'WAVE $wave',
          style: TextStyle(
            color: Colors.yellowAccent.withOpacity(0.9),
            fontSize: 40,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            shadows: const [Shadow(color: Colors.orange, blurRadius: 20)],
          ),
        ),
      ),
    );
  }
}

// ─── Glowing Button ───────────────────────────────────────────────────────────
class _GlowButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _GlowButton({required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: color.withOpacity(0.15),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 16, spreadRadius: 2),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
}

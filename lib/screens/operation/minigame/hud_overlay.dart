import 'package:flutter/material.dart';
import 'game_engine.dart';
import 'game_models.dart';

class HudOverlay extends StatelessWidget {
  final GameEngine engine;
  final bool gyroEnabled;
  final VoidCallback onToggleGyro;
  const HudOverlay({super.key, required this.engine, required this.gyroEnabled, required this.onToggleGyro});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _LivesWidget(lives: engine.player.lives),
                _WaveWidget(wave: engine.wave),
                _GyroButton(enabled: gyroEnabled, onTap: onToggleGyro),
                _PauseButton(engine: engine),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: _ScoreWidget(score: engine.player.score),
            ),
          ],
        ),
      ),
    );
  }
}

class _LivesWidget extends StatelessWidget {
  final int lives;
  const _LivesWidget({required this.lives});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            Icons.favorite,
            color: i < lives ? Colors.redAccent : Colors.white24,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _ScoreWidget extends StatelessWidget {
  final int score;
  const _ScoreWidget({required this.score});
  @override
  Widget build(BuildContext context) {
    return Text(
      'Score: $score',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 8)],
      ),
    );
  }
}

class _WaveWidget extends StatelessWidget {
  final int wave;
  const _WaveWidget({required this.wave});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white10,
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        'WAVE $wave',
        style: const TextStyle(
          color: Colors.yellowAccent,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _GyroButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _GyroButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? Colors.cyanAccent : Colors.white12,
          border: Border.all(color: enabled ? Colors.cyan : Colors.white30),
        ),
        child: Icon(
          Icons.screen_rotation,
          color: enabled ? Colors.black : Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

class _PauseButton extends StatelessWidget {
  final GameEngine engine;
  const _PauseButton({required this.engine});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: engine.togglePause,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white12,
          border: Border.all(color: Colors.white30),
        ),
        child: const Icon(Icons.pause, color: Colors.white, size: 20),
      ),
    );
  }
}

// ─── Enemy legend bar ─────────────────────────────────────────────────────────
class EnemyLegend extends StatelessWidget {
  const EnemyLegend({super.key});
  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      children: const [
        _LegendItem(color: Color(0xFFE53935), label: 'Basic'),
        _LegendItem(color: Color(0xFFFF6F00), label: 'Fast'),
        _LegendItem(color: Color(0xFF6A1B9A), label: 'Tank'),
        _LegendItem(color: Color(0xFF00838F), label: 'Shooter'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

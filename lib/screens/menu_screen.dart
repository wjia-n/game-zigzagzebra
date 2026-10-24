// DISTINCT ROLLOUT V4 — zigzagzebra: "Left rows + side badge"
// Layout template from distinct-samples/turboturtle.
import 'package:flutter/material.dart';
import '../theme/arcade_config.dart';
import '../engine/arcade_engine.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'support_screen.dart';

const List<String> _emojiFb = ['Noto Color Emoji'];

class MenuScreen extends StatefulWidget {
  final ArcadeConfig config;
  const MenuScreen({super.key, required this.config});
  @override State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int highScore = 0;
  String playerName = 'Player 1';

  @override void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = SettingsService('${widget.config.slug}_');
    final h = await svc.getHighScore();
    final n = await svc.getPlayerName();
    if (mounted) setState(() { highScore = h; playerName = n; });
  }

  void _play() async {
    final svc = SettingsService('${widget.config.slug}_');
    final diff = await svc.getDifficulty();
    final shape = await svc.getShape();
    final mul = [0.8, 1.0, 1.3][diff.clamp(0, 2)];
    final sound = SoundService('${widget.config.slug}_');
    await sound.load();
    await sound.click();
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(
      config: widget.config,
      engine: ArcadeEngine(cfg: widget.config, diffMul: mul),
      sound: sound,
      shape: shape,
    ))).then((_) => _load());
  }

  @override Widget build(BuildContext context) {
    final c = widget.config;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.centerLeft, end: Alignment.centerRight,
          colors: [c.darkColor, c.primaryColor.withOpacity(0.4)])),
        child: SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.displayName.toUpperCase(), textAlign: TextAlign.left,
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, fontFamilyFallback: _emojiFb)),
                const SizedBox(height: 6),
                Text(c.tagline, textAlign: TextAlign.left,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, fontFamilyFallback: _emojiFb)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('🏆 $playerName — Best: $highScore',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontFamilyFallback: _emojiFb)),
                ),
              ])),
              const SizedBox(width: 16),
              Column(children: [
                Container(
                  width: 84, height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.accentColor.withOpacity(0.2),
                    border: Border.all(color: c.accentColor, width: 2),
                  ),
                  child: Center(child: Text(c.playerEmoji,
                      style: const TextStyle(fontSize: 44, fontFamilyFallback: _emojiFb))),
                ),
                const SizedBox(height: 6),
                Text('ZIGZAG', style: TextStyle(color: c.accentColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2.0, fontFamilyFallback: _emojiFb)),
              ]),
            ]),
            const SizedBox(height: 28),
            _rowBtn('▶  PLAY', c.accentColor, Colors.black, _play),
            _rowBtn('❓  HOW TO PLAY', Colors.white24, Colors.white,
                () => _howTo(context, c)),
            _rowBtn('⚙️  SETTINGS', Colors.white24, Colors.white, () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SettingsScreen(config: c))).then((_) => _load());
            }),
            _rowBtn('💛  SUPPORT', c.primaryColor, Colors.white, () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SupportScreen(config: c)));
            }),
            const SizedBox(height: 28),
            const Text('Credits: WAJIHA', style: TextStyle(color: Colors.white38, fontSize: 12, fontFamilyFallback: _emojiFb)),
          ])))),
      );
  }

  void _howTo(BuildContext ctx, ArcadeConfig c) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: c.darkColor,
      title: Text(c.displayName, style: const TextStyle(color: Colors.white, fontFamilyFallback: _emojiFb)),
      content: Text(c.howTo, style: const TextStyle(color: Colors.white70, fontFamilyFallback: _emojiFb)),
      actions: [TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: Text('GOT IT', style: TextStyle(color: c.accentColor, fontFamilyFallback: _emojiFb)))],
    ));
  }

  Widget _rowBtn(String label, Color bg, Color fg, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: SizedBox(width: double.infinity, child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: bg, foregroundColor: fg,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
      onPressed: onTap,
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamilyFallback: _emojiFb))),
        const Text('›', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamilyFallback: _emojiFb)),
      ]))),
  );
}

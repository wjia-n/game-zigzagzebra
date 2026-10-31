import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/arcade_engine.dart';
import '../theme/arcade_config.dart';
import '../theme/shading.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';

class GameScreen extends StatefulWidget {
  final ArcadeConfig config;
  final ArcadeEngine engine;
  final SoundService sound;
  final int shape;
  const GameScreen({super.key, required this.config, required this.engine, required this.sound, required this.shape});
  @override State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _saved = false;

  @override void initState() {
    super.initState();
    widget.engine.onScore = () => widget.sound.good();
    widget.engine.onHit = () { widget.sound.bad(); _buzz(); };
    widget.engine.onJump = () => widget.sound.jump();
    widget.engine.onLevelUp = () => widget.sound.level();
    widget.engine.addListener(_onEngine);
    widget.engine.start();
    widget.sound.startMusic();
  }

  void _onEngine() {
    if (widget.engine.gameOver && !_saved) {
      _saved = true;
      widget.sound.lose();
      final svc = SettingsService('${widget.config.slug}_');
      svc.getHighScore().then((h) {
        if (widget.engine.score > h) svc.setHighScore(widget.engine.score);
      });
      if (mounted) setState(() {});
    }
  }

  Future<void> _buzz() async {
    final svc = SettingsService('${widget.config.slug}_');
    if (await svc.getVibration()) {
      try { await HapticFeedback.mediumImpact(); } catch (_) {}
    }
  }

  @override void dispose() {
    widget.engine.removeListener(_onEngine);
    widget.engine.stop();
    widget.sound.stopMusic();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    final c = widget.config;
    return Scaffold(
      backgroundColor: c.darkColor,
      appBar: AppBar(
        backgroundColor: c.primaryColor, foregroundColor: Colors.white,
        title: Text(c.displayName),
        actions: [
          IconButton(icon: const Icon(Icons.pause), onPressed: () => setState(() => widget.engine.togglePause())),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() { _saved = false; widget.engine.start(); })),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.engine,
        builder: (_, __) {
          final e = widget.engine;
          if (e.gameOver) return _gameOver(c, e);
          return Column(children: [
            _hud(c, e),
            Expanded(child: _playArea(c, e)),
          ]);
        },
      ),
    );
  }

  Widget _hud(ArcadeConfig c, ArcadeEngine e) {
    return Container(
      decoration: BoxDecoration(
        color: c.primaryColor.withOpacity(0.22),
        boxShadow: const [
          BoxShadow(color: Colors.black54, offset: Offset(0, 3), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: _stat('LEVEL', '${e.level}')),
        Container(width: 1, height: 28, color: Colors.white24),
        Expanded(child: _stat('❤', '${e.lives}')),
        Container(width: 1, height: 28, color: Colors.white24),
        Expanded(child: _stat('COMBO', 'x${e.combo}')),
        Container(width: 1, height: 28, color: Colors.white24),
        Expanded(child: _stat('SCORE', '${e.score}')),
      ]),
    );
  }

  Widget _stat(String label, String value) => Column(children: [
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9, fontFamilyFallback: ['Noto Color Emoji'])),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamilyFallback: ['Noto Color Emoji'])),
  ]);

  Widget _playArea(ArcadeConfig c, ArcadeEngine e) {
    return GestureDetector(
      onTapDown: (d) {
        final xy = _norm(d.globalPosition);
        if (c.mode == ArcadeMode.glide) e.onHoldStart();
        else e.onTap(xy[0], xy[1]);
      },
      onTapUp: (_) { if (c.mode == ArcadeMode.glide) e.onHoldEnd(); },
      onTapCancel: () { if (c.mode == ArcadeMode.glide) e.onHoldEnd(); },
      onPanStart: (d) { final xy = _norm(d.globalPosition); e.onDrag(xy[0], xy[1], 0, 0); },
      onPanUpdate: (d) { final xy = _norm(d.globalPosition); e.onDrag(xy[0], xy[1], d.delta.dx / 300, d.delta.dy / 300); },
      onPanEnd: (_) => e.onHoldEnd(),
      child: CustomPaint(
        painter: _ArcadePainter(engine: e, config: c, shape: widget.shape),
        child: Container(),
      ),
    );
  }

  List<double> _norm(Offset g) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(g);
    final s = box.size;
    return [(local.dx / s.width).clamp(0.0, 1.0), (local.dy / s.height).clamp(0.0, 1.0)];
  }

  Widget _gameOver(ArcadeConfig c, ArcadeEngine e) {
    return Center(child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withOpacity(0.14), Colors.white.withOpacity(0.04)]), border: Border.all(color: Colors.white.withOpacity(0.20)), boxShadow: const [BoxShadow(color: Colors.black54, offset: Offset(0, 8), blurRadius: 16)]), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(c.bgEmoji, style: const TextStyle(fontFamilyFallback: const ['Noto Color Emoji'], fontSize: 64)),
      const SizedBox(height: 12),
      const Text('GAME OVER', style: TextStyle(fontFamilyFallback: const ['Noto Color Emoji'], color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Flexible(child: Text('Score: ${e.score}', textAlign: TextAlign.center, style: const TextStyle(fontFamilyFallback: const ['Noto Color Emoji'], color: Colors.white, fontSize: 22))),
        const SizedBox(width: 16),
        Flexible(child: Text('Best combo: x${e.bestCombo}  •  Level ${e.level}', textAlign: TextAlign.center,
            style: const TextStyle(fontFamilyFallback: const ['Noto Color Emoji'], color: Colors.white70))),
      ]),
      const SizedBox(height: 24),
      ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: c.accentColor,
            elevation: 6, shadowColor: Colors.black54,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16)),
        onPressed: () => setState(() { _saved = false; e.start(); }),
        child: const Text('PLAY AGAIN', style: TextStyle(fontFamilyFallback: const ['Noto Color Emoji'], fontSize: 18, color: Colors.black))),
      TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Menu', style: TextStyle(fontFamilyFallback: const ['Noto Color Emoji'], color: Colors.white70))),
    ])));
  }
}

class _ArcadePainter extends CustomPainter {
  final ArcadeEngine engine;
  final ArcadeConfig config;
  final int shape;
  _ArcadePainter({required this.engine, required this.config, required this.shape});

  void _emoji(Canvas cv, String em, double x, double y, double pxSize, Size size, {double opacity = 1}) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(text: em,
        style: TextStyle(fontFamilyFallback: const ['Noto Color Emoji'], fontSize: pxSize, color: Colors.white.withOpacity(opacity)));
    tp.layout();
    tp.paint(cv, Offset(x * size.width - tp.width / 2, y * size.height - tp.height / 2));
  }

  void _shadow(Canvas cv, double x, double y, double r, Size size) {
    cv.drawOval(
      Rect.fromCenter(center: Offset(x * size.width, (y + r * 0.9) * size.height),
          width: r * 2.4 * size.width, height: r * 0.5 * size.width),
      Paint()..color = Colors.black.withOpacity(0.3));
  }

  void _badge(Canvas cv, double x, double y, double r, Size size) {
    // 3D treatment: every drawn badge shape gets the shaded treatment at the
    // SAME centre/size as the flat shape it replaces. The heart (case 4) is
    // an emoji glyph, so it keeps its original flat draw + offset shadow —
    // see GENERATOR.md "explicitly not shaded".
    final cx = x * size.width, cy = y * size.height;
    final pr = r * size.width;
    final base = config.accentColor.withOpacity(0.9);
    switch (shape % 6) {
      case 0:
        paintShadedCircle(cv, Offset(cx, cy), pr, base);
        break;
      case 1:
        paintBeveledRect(cv, Rect.fromCenter(center: Offset(cx, cy), width: pr * 1.7, height: pr * 1.7), 6, base);
        break;
      case 2:
        final star = Path();
        for (int i = 0; i < 10; i++) {
          final ang = -1.5708 + i * 0.6283;
          final rr = i.isEven ? pr : pr * 0.45;
          final pt = Offset(cx + rr * cos(ang), cy + rr * sin(ang));
          if (i == 0) star.moveTo(pt.dx, pt.dy); else star.lineTo(pt.dx, pt.dy);
        }
        star.close();
        paintShadedPath(cv, star, Rect.fromCircle(center: Offset(cx, cy), radius: pr), base);
        break;
      case 3:
        final diamond = Path()
          ..moveTo(cx, cy - pr)..lineTo(cx + pr, cy)..lineTo(cx, cy + pr)..lineTo(cx - pr, cy)..close();
        paintShadedPath(cv, diamond, Rect.fromCircle(center: Offset(cx, cy), radius: pr), base);
        break;
      case 4:
        cv.drawCircle(Offset(cx + 2, cy + 3), pr, Paint()..color = Colors.black.withOpacity(0.25));
        _emoji(cv, '♥', x, y, pr * 2.4, size, opacity: 0.9);
        break;
      default:
        paintShadedOval(cv, Rect.fromCenter(center: Offset(cx, cy), width: pr * 1.9, height: pr * 1.5), base);
    }
  }


  @override
  void paint(Canvas canvas, Size size) {
    final e = engine;
    paintDepthBackground(canvas, size, config.darkColor, config.primaryColor);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(text: config.bgEmoji,
        style: TextStyle(fontFamilyFallback: const ['Noto Color Emoji'], fontSize: 26, color: Colors.white.withOpacity(0.07)));
    tp.layout();
    for (int i = 0; i < 10; i++) {
      tp.paint(canvas, Offset((i * 113) % size.width, (i * 67) % size.height));
    }
    switch (config.mode) {
      case ArcadeMode.dodge: _paintDodge(canvas, size); break;
      case ArcadeMode.jump: _paintJump(canvas, size); break;
      case ArcadeMode.catch_: _paintCatch(canvas, size); break;
      case ArcadeMode.breakout: _paintBreakout(canvas, size); break;
      case ArcadeMode.flip: _paintFlip(canvas, size); break;
      case ArcadeMode.sling: _paintSling(canvas, size); break;
      case ArcadeMode.stack: _paintStack(canvas, size); break;
      case ArcadeMode.glide: _paintGlide(canvas, size); break;
      case ArcadeMode.pinball: _paintPinball(canvas, size); break;
      case ArcadeMode.maze: _paintMaze(canvas, size); break;
      case ArcadeMode.spin: _paintSpin(canvas, size); break;
      case ArcadeMode.rhythm: _paintRhythm(canvas, size); break;
      case ArcadeMode.balance: _paintBalance(canvas, size); break;
    }
    for (final f in e.fx) {
      final a = 1 - f.t / 0.4;
      canvas.drawCircle(Offset(f.x * size.width, f.y * size.height), 26 * a + 8,
          Paint()..color = (f.kind == 1 ? Colors.red : config.accentColor).withOpacity(a * 0.7));
    }
    if (e.paused) {
      tp.text = const TextSpan(text: '⏸ PAUSED', style: TextStyle(fontFamilyFallback: const ['Noto Color Emoji'], fontSize: 34, color: Colors.white, shadows: [Shadow(color: Colors.black, offset: Offset(0, 3), blurRadius: 6)]));
      tp.layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height / 2 - 30));
    }
    if (e.invuln > 0 && e.invuln % 12 < 6) {
      canvas.drawCircle(Offset(e.px * size.width, e.py * size.height),
          (e.pr + 0.03) * size.width,
          Paint()..color = Colors.white.withOpacity(0.35)
            ..style = PaintingStyle.stroke..strokeWidth = 3);
    }
  }

  void _player(Canvas cv, ArcadeEngine e, Size size, double x, double y, double r) {
    _shadow(cv, x, y, r, size);
    _badge(cv, x, y, r, size);
    _emoji(cv, config.playerEmoji, x, y, r * size.width * 1.5, size);
  }

  void _paintDodge(Canvas cv, Size size) {
    final e = engine;
    for (final o in e.obs) {
      _shadow(cv, o.x, o.y, o.r, size);
      _emoji(cv, config.obstacleEmoji, o.x, o.y, o.r * size.width * 1.7, size);
    }
    for (final c in e.cols) _emoji(cv, config.collectEmoji, c.x, c.y, c.r * size.width * 1.6, size);
    _player(cv, e, size, e.px, e.py, e.pr);
  }

  void _paintJump(Canvas cv, Size size) {
    final e = engine;
    // Platforms are beveled by paintBeveledRect below (3D treatment).
    for (final p in e.misc) {
      if (config.fallDown) {
        final gapL = p.a * size.width, gapR = p.t * size.width;
        final y = p.y * size.height;
        paintBeveledRect(cv, Rect.fromLTWH(0, y - 7, gapL, 14), 7, config.primaryColor);
        paintBeveledRect(cv, Rect.fromLTWH(gapR, y - 7, size.width - gapR, 14), 7, config.primaryColor);
      } else {
        final w = p.w * size.width;
        const h = 14.0;
        final rect = Rect.fromCenter(center: Offset(p.x * size.width, p.y * size.height), width: w, height: h);
        paintBeveledRect(cv, rect, 7, config.primaryColor);
      }
    }
    for (final c in e.cols) _emoji(cv, config.collectEmoji, c.x, c.y, c.r * size.width * 1.6, size);
    _player(cv, e, size, e.px, e.py, e.pr);
  }

  void _paintCatch(Canvas cv, Size size) {
    final e = engine;
    for (final c in e.cols) {
      final em = c.kind == 1 ? config.collectEmoji : c.kind == 4 ? '⭐' : config.obstacleEmoji;
      _emoji(cv, em, c.x, c.y, c.r * size.width * 1.7, size);
    }
    _emoji(cv, '🧺', e.px, 0.88, 64, size);
    _player(cv, e, size, e.px, 0.78, e.pr * 0.9);
  }

  void _paintBreakout(Canvas cv, Size size) {
    final e = engine;
    for (final b in e.misc) {
      final rect = Rect.fromCenter(
          center: Offset(b.x * size.width, b.y * size.height),
          width: b.w * size.width, height: 26);
      final col = b.hp > 1 ? config.accentColor : config.primaryColor;
      paintBeveledRect(cv, rect, 6, col);
    }
    final pw = 0.24 * size.width;
    paintBeveledRect(cv, Rect.fromCenter(center: Offset(e.px * size.width, 0.9 * size.height), width: pw, height: 16), 8, config.accentColor);
    _shadow(cv, e.bx, e.by, 0.025, size);
    paintShadedCircle(cv, Offset(e.bx * size.width, e.by * size.height), 0.028 * size.width, Colors.white);
    if (e.ballHeld) _emoji(cv, '👆', e.px, 0.78, 40, size);
  }

  void _paintFlip(Canvas cv, Size size) {
    final e = engine;
    paintBeveledRect(cv, Rect.fromLTWH(0, 0.9 * size.height, size.width, size.height * 0.1), 0, config.primaryColor.withOpacity(0.5));
    paintBeveledRect(cv, Rect.fromLTWH(0, 0, size.width, size.height * 0.1), 0, config.primaryColor.withOpacity(0.5));
    for (final o in e.obs) _emoji(cv, config.obstacleEmoji, o.x, o.y, o.r * size.width * 1.7, size);
    for (final c in e.cols) _emoji(cv, config.collectEmoji, c.x, c.y, c.r * size.width * 1.6, size);
    _player(cv, e, size, 0.3, e.py, e.pr);
  }

  void _paintSling(Canvas cv, Size size) {
    final e = engine;
    _emoji(cv, '🎯', 0.15, 0.85, 52, size);
    if (e.aiming) {
      double dx = 0.15 - e.aimX, dy = 0.85 - e.aimY;
      final m = 0.15 > sqrt(dx * dx + dy * dy) ? 0.15 : sqrt(dx * dx + dy * dy);
      dx /= m; dy /= m;
      double tx = 0.15, ty = 0.85, tvx = dx * 1.15, tvy = dy * 1.15 - 0.25;
      for (int i = 0; i < 12; i++) {
        tvy += 1.1 * 0.05; tx += tvx * 0.05; ty += tvy * 0.05;
        cv.drawCircle(Offset(tx * size.width, ty * size.height), 3,
            Paint()..color = Colors.white.withOpacity(0.6));
      }
    }
    for (final m in e.misc) {
      if (m.kind == 4) _emoji(cv, config.obstacleEmoji, m.x, m.y, m.r * size.width * 1.7, size);
      else if (m.kind == 7) paintShadedCircle(cv, Offset(m.x * size.width, m.y * size.height), m.r * size.width, config.accentColor);
    }
    _player(cv, e, size, 0.15, 0.85, e.pr * 0.8);
  }

  void _paintStack(Canvas cv, Size size) {
    final e = engine;
    final bw = e.towerW * size.width, bh = size.height * 0.07;
    for (int i = 0; i < e.towerH + 1; i++) {
      final y = e.towerTopY * size.height + i * bh;
      if (y > size.height + bh) break;
      final wob = bw * (1 - i * 0.004);
      paintBeveledRect(cv, Rect.fromCenter(center: Offset(e.towerX * size.width, y), width: wob, height: bh - 3), 4, i.isEven ? config.primaryColor : config.accentColor.withOpacity(0.85));
    }
    final by = e.dropping ? e.dropY : 0.15;
    paintBeveledRect(cv, Rect.fromCenter(center: Offset(e.stackX * size.width, by * size.height), width: bw, height: bh - 3), 4, Colors.white.withOpacity(0.9));
    _emoji(cv, config.bgEmoji, 0.5, 0.96, 40, size);
  }

  void _paintGlide(Canvas cv, Size size) {
    final e = engine;
    for (final o in e.obs) {
      final x = o.x * size.width, w = o.w * size.width;
      final gapT = (o.y - o.a / 2) * size.height, gapB = (o.y + o.a / 2) * size.height;
      paintBeveledRect(cv, Rect.fromLTWH(x - w / 2, 0, w, gapT), 0, config.primaryColor, direction: Axis.horizontal);
      paintBeveledRect(cv, Rect.fromLTWH(x - w / 2, gapB, w, size.height - gapB), 0, config.primaryColor, direction: Axis.horizontal);
      _emoji(cv, config.obstacleEmoji, o.x, o.y - o.a / 2 - 0.04, 30, size);
    }
    for (final c in e.cols) _emoji(cv, config.collectEmoji, c.x, c.y, c.r * size.width * 1.6, size);
    _player(cv, e, size, 0.3, e.py, e.pr);
  }

  void _paintPinball(Canvas cv, Size size) {
    final e = engine;
    for (final b in e.misc) {
      _shadow(cv, b.x, b.y, b.r, size);
      paintShadedCircle(cv, Offset(b.x * size.width, b.y * size.height), b.r * size.width, config.primaryColor);
      paintShadedCircle(cv, Offset(b.x * size.width, b.y * size.height), b.r * size.width * 0.55, config.accentColor);
      _emoji(cv, config.collectEmoji, b.x, b.y, b.r * size.width * 0.9, size);
    }
    // Flippers are shaded by paintShadedLine below (3D treatment).
    final y0 = 0.88 * size.height;
    final la = e.flipSide < 0 && e.flipT > 0 ? -0.5 : 0.25;
    final ra = e.flipSide > 0 && e.flipT > 0 ? 0.5 : -0.25;
    paintShadedLine(cv, Offset(0.2 * size.width, y0), Offset(0.2 * size.width + 0.14 * size.width * cos(la), y0 + 0.14 * size.width * sin(la)), config.accentColor, 10);
    paintShadedLine(cv, Offset(0.8 * size.width, y0), Offset(0.8 * size.width + 0.14 * size.width * cos(ra), y0 + 0.14 * size.width * sin(ra)), config.accentColor, 10);
    _shadow(cv, e.bx, e.by, 0.025, size);
    paintShadedCircle(cv, Offset(e.bx * size.width, e.by * size.height), 0.03 * size.width, Colors.white);
  }

  void _paintMaze(Canvas cv, Size size) {
    final e = engine;
    if (e.maze.isEmpty) return;
    final n = e.mazeN, m = e.mazeM;
    final cw = size.width / n, ch = (size.height * 0.92) / m;
    final y0 = size.height * 0.04;
    // Maze walls are beveled by paintBeveledRect below (3D treatment).
    for (int gy = 0; gy < m; gy++) {
      for (int gx = 0; gx < n; gx++) {
        if (e.maze[gy][gx] == 1) {
          paintBeveledRect(cv, Rect.fromLTWH(gx * cw + 1, y0 + gy * ch + 1, cw - 2, ch - 2), 2, config.primaryColor.withOpacity(0.85), direction: Axis.horizontal);
        }
      }
    }
    _emoji(cv, '🏁', e.goalX, e.goalY, 40, size);
    for (final c in e.cols) _emoji(cv, config.collectEmoji, c.x, c.y, c.r * size.width * 1.6, size);
    _player(cv, e, size, e.px, e.py, e.pr * 0.9);
  }

  void _paintSpin(Canvas cv, Size size) {
    final e = engine;
    final radii = [0.16, 0.28, 0.40];
    final cx = 0.5 * size.width, cy = 0.5 * size.height;
    for (int i = 0; i < 3; i++) {
      final rr = radii[i] * size.width;
      final gapC = e.ringGaps[i] % 6.2832;
      paintShadedArc(cv, Rect.fromCircle(center: Offset(cx, cy), radius: rr), gapC + 0.28, 6.2832 - 0.56, i == e.ringIdx ? config.accentColor : config.primaryColor, 10);
    }
    for (final c in e.cols) _emoji(cv, config.collectEmoji, c.x, c.y, c.r * size.width * 1.6, size);
    _player(cv, e, size, e.px, e.py, e.pr);
  }

  void _paintRhythm(Canvas cv, Size size) {
    final e = engine;
    for (int lane = 0; lane < 3; lane++) {
      final x = (0.2 + lane * 0.3) * size.width;
      cv.drawLine(Offset(x, 0), Offset(x, size.height),
          Paint()..color = Colors.white.withOpacity(0.12)..strokeWidth = 4);
    }
    paintShadedLine(cv, Offset(0, 0.8 * size.height), Offset(size.width, 0.8 * size.height), config.accentColor, 5);
    for (final n in e.misc) {
      paintShadedCircle(cv, Offset(n.x * size.width, n.y * size.height), n.r * size.width, config.primaryColor);
      _emoji(cv, config.collectEmoji, n.x, n.y, n.r * size.width * 1.1, size);
    }
    _emoji(cv, config.playerEmoji, 0.5, 0.92, 52, size);
  }

  void _paintBalance(Canvas cv, Size size) {
    final e = engine;
    final cx = 0.5 * size.width, cy = 0.62 * size.height;
    final len = size.width * 0.42;
    paintShadedCircle(cv, Offset(cx, cy + 26), 10, config.primaryColor);
    cv.save();
    cv.translate(cx, cy);
    cv.rotate(e.beamA);
    paintBeveledRect(cv, Rect.fromCenter(center: Offset.zero, width: len * 2, height: 14), 7, config.primaryColor);
    cv.restore();
    final bx = cx + (e.px - 0.5) * size.width;
    final by = cy - e.beamA * (e.px - 0.5) * size.width - 20;
    _shadow(cv, bx / size.width, by / size.height + 0.02, 0.035, size);
    paintShadedCircle(cv, Offset(bx, by), 0.04 * size.width, config.accentColor);
    _emoji(cv, config.playerEmoji, bx / size.width, by / size.height, 30, size);
    if (e.gustF.abs() > 0.2) {
      _emoji(cv, '💨', e.gustF > 0 ? 0.12 : 0.88, 0.2, 40, size);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

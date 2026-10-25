import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

const _kRed = Color(0xFFE11D26);

enum GameMode { battleRoyale, training }

const _kArenaSize = 2400.0;
const _matchDuration = 90.0;
const _startZoneRadius = 1100.0;
const _endZoneRadius = 120.0;

enum LootType { weapon, ammo, heal }

class _LootItem {
  Offset pos;
  LootType type;
  bool taken = false;
  _LootItem(this.pos, this.type);
}

class _Bullet {
  Offset pos;
  Offset dir;
  bool fromPlayer;
  double life = 1.2;
  _Bullet(this.pos, this.dir, this.fromPlayer);
}

class _Bot {
  Offset pos;
  double health = 100;
  bool alive = true;
  double aimAngle = 0;
  double shootCooldown = 0;
  Offset wanderTarget;
  _Bot(this.pos) : wanderTarget = pos;
}

class _Dummy {
  Offset pos;
  int hits = 0;
  _Dummy(this.pos);
}

class GameScreen extends StatefulWidget {
  final GameMode mode;
  const GameScreen({super.key, required this.mode});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final _rand = Random();
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;

  Offset _playerPos = const Offset(_kArenaSize / 2, _kArenaSize / 2);
  double _playerHealth = 100;
  bool _playerArmed = false;
  int _playerAmmo = 0;
  double _shootCooldown = 0;
  double _aimAngle = -pi / 2;

  Offset _moveDir = Offset.zero;
  Offset _aimDir = Offset.zero;
  bool _firing = false;

  final List<_Bot> _bots = [];
  final List<_LootItem> _loot = [];
  final List<_Bullet> _bullets = [];
  final List<_Dummy> _dummies = [];
  final List<String> _killFeed = [];

  double _matchTime = 0;
  double _zoneRadius = _startZoneRadius;
  final Offset _zoneCenter = const Offset(_kArenaSize / 2, _kArenaSize / 2);

  bool _dropping = true;
  bool _gameOver = false;
  bool _won = false;

  @override
  void initState() {
    super.initState();
    _setupWorld();
    _ticker = createTicker(_tick)..start();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _dropping = false);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _setupWorld() {
    _playerPos = const Offset(_kArenaSize / 2, _kArenaSize / 2);
    if (widget.mode == GameMode.training) {
      _playerArmed = true;
      _playerAmmo = 999;
      for (int i = 0; i < 5; i++) {
        _dummies.add(_Dummy(Offset(
          _kArenaSize / 2 + cos(i * pi / 2.5) * 260,
          _kArenaSize / 2 + sin(i * pi / 2.5) * 260,
        )));
      }
      return;
    }

    for (int i = 0; i < 9; i++) {
      final angle = _rand.nextDouble() * 2 * pi;
      final dist = _rand.nextDouble() * (_startZoneRadius - 150);
      _bots.add(_Bot(_zoneCenter + Offset(cos(angle), sin(angle)) * dist));
    }
    for (int i = 0; i < 18; i++) {
      final angle = _rand.nextDouble() * 2 * pi;
      final dist = _rand.nextDouble() * (_startZoneRadius - 100);
      final type = LootType.values[_rand.nextInt(LootType.values.length)];
      _loot.add(_LootItem(
          _zoneCenter + Offset(cos(angle), sin(angle)) * dist, type));
    }
    _loot.add(_LootItem(_playerPos + const Offset(40, 0), LootType.weapon));
  }

  void _tick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.0
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (_dropping || _gameOver || dt <= 0 || dt > 0.1) return;

    setState(() {
      _updatePlayer(dt);
      _updateBullets(dt);
      _updateLoot();
      if (widget.mode == GameMode.battleRoyale) {
        _updateZone(dt);
        _updateBots(dt);
        _checkWinLose();
      }
    });
  }

  void _updatePlayer(double dt) {
    const speed = 220.0;
    if (_moveDir.distance > 0.1) {
      _playerPos += _moveDir * speed * dt;
      _playerPos = Offset(
        _playerPos.dx.clamp(0, _kArenaSize),
        _playerPos.dy.clamp(0, _kArenaSize),
      );
    }
    if (_aimDir.distance > 0.2) {
      _aimAngle = atan2(_aimDir.dy, _aimDir.dx);
    }
    if (_shootCooldown > 0) _shootCooldown -= dt;
    if (_firing && _playerArmed && _playerAmmo > 0 && _shootCooldown <= 0) {
      _shootCooldown = 0.18;
      _playerAmmo--;
      _bullets.add(_Bullet(
        _playerPos,
        Offset(cos(_aimAngle), sin(_aimAngle)),
        true,
      ));
    }

    if (widget.mode == GameMode.battleRoyale) {
      final outside = (_playerPos - _zoneCenter).distance > _zoneRadius;
      if (outside) _playerHealth -= 6 * dt;
    }
  }

  void _updateBullets(double dt) {
    for (final b in _bullets) {
      b.pos += b.dir * 620 * dt;
      b.life -= dt;
    }

    for (final bot in _bots) {
      if (!bot.alive) continue;
      for (final b in _bullets) {
        if (!b.fromPlayer || b.life <= 0) continue;
        if ((b.pos - bot.pos).distance < 22) {
          bot.health -= 34;
          b.life = 0;
          if (bot.health <= 0) {
            bot.alive = false;
            _killFeed.insert(0, 'أنت قتلت لاعب');
          }
        }
      }
    }
    for (final d in _dummies) {
      for (final b in _bullets) {
        if (!b.fromPlayer || b.life <= 0) continue;
        if ((b.pos - d.pos).distance < 22) {
          d.hits++;
          b.life = 0;
        }
      }
    }
    for (final b in _bullets) {
      if (b.fromPlayer || b.life <= 0) continue;
      if ((b.pos - _playerPos).distance < 20) {
        _playerHealth -= 14;
        b.life = 0;
      }
    }
    _bullets.removeWhere((b) => b.life <= 0);
    if (_killFeed.length > 4) _killFeed.removeRange(4, _killFeed.length);
  }

  void _updateLoot() {
    for (final l in _loot) {
      if (l.taken) continue;
      if ((l.pos - _playerPos).distance < 36) {
        l.taken = true;
        switch (l.type) {
          case LootType.weapon:
            _playerArmed = true;
            _playerAmmo += 30;
            break;
          case LootType.ammo:
            _playerAmmo += 20;
            break;
          case LootType.heal:
            _playerHealth = min(100, _playerHealth + 35);
            break;
        }
      }
    }
  }

  void _updateZone(double dt) {
    _matchTime += dt;
    final t = (_matchTime / _matchDuration).clamp(0.0, 1.0);
    _zoneRadius = _startZoneRadius + (_endZoneRadius - _startZoneRadius) * t;
  }

  void _updateBots(double dt) {
    for (final bot in _bots) {
      if (!bot.alive) continue;

      final outside = (bot.pos - _zoneCenter).distance > _zoneRadius;
      if (outside) bot.health -= 6 * dt;

      final toPlayer = _playerPos - bot.pos;
      final distToPlayer = toPlayer.distance;

      Offset moveDir;
      if (distToPlayer < 420) {
        moveDir = toPlayer / max(distToPlayer, 1);
        bot.aimAngle = atan2(toPlayer.dy, toPlayer.dx);
        bot.shootCooldown -= dt;
        if (bot.shootCooldown <= 0 && distToPlayer < 380) {
          bot.shootCooldown = 0.9 + _rand.nextDouble() * 0.6;
          final spread = (_rand.nextDouble() - 0.5) * 0.25;
          _bullets.add(_Bullet(
            bot.pos,
            Offset(cos(bot.aimAngle + spread), sin(bot.aimAngle + spread)),
            false,
          ));
        }
        if (distToPlayer < 140) moveDir = -moveDir;
      } else {
        if ((bot.pos - bot.wanderTarget).distance < 20) {
          final angle = _rand.nextDouble() * 2 * pi;
          final dist = _rand.nextDouble() * 300;
          bot.wanderTarget = bot.pos + Offset(cos(angle), sin(angle)) * dist;
        }
        final d = bot.wanderTarget - bot.pos;
        moveDir = d.distance > 1 ? d / d.distance : Offset.zero;
      }

      bot.pos += moveDir * 130 * dt;
      bot.pos = Offset(
        bot.pos.dx.clamp(0, _kArenaSize),
        bot.pos.dy.clamp(0, _kArenaSize),
      );

      if (bot.health <= 0) bot.alive = false;
    }
  }

  void _checkWinLose() {
    if (_playerHealth <= 0 && !_gameOver) {
      _gameOver = true;
      _won = false;
    }
    final aliveBots = _bots.where((b) => b.alive).length;
    if (aliveBots == 0 && !_gameOver) {
      _gameOver = true;
      _won = true;
    }
  }

  void _restart() {
    setState(() {
      _playerHealth = 100;
      _playerArmed = widget.mode == GameMode.training;
      _playerAmmo = widget.mode == GameMode.training ? 999 : 0;
      _bots.clear();
      _loot.clear();
      _bullets.clear();
      _dummies.clear();
      _killFeed.clear();
      _matchTime = 0;
      _zoneRadius = _startZoneRadius;
      _gameOver = false;
      _won = false;
      _dropping = true;
      _setupWorld();
    });
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _dropping = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1A0F),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ArenaPainter(
                playerPos: _playerPos,
                aimAngle: _aimAngle,
                bots: _bots,
                loot: _loot,
                bullets: _bullets,
                dummies: _dummies,
                zoneCenter: _zoneCenter,
                zoneRadius: _zoneRadius,
                mode: widget.mode,
              ),
            ),
          ),
          _buildHud(),
          if (!_dropping && !_gameOver) _buildControls(),
          if (_dropping) _buildDropOverlay(),
          if (_gameOver) _buildEndOverlay(),
        ],
      ),
    );
  }

  Widget _buildHud() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
                const Spacer(),
                if (widget.mode == GameMode.battleRoyale)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'الباقون: ${_bots.where((b) => b.alive).length + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الصحة',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (_playerHealth / 100).clamp(0, 1),
                      minHeight: 10,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _playerHealth > 40 ? Colors.greenAccent : _kRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_killFeed.isNotEmpty)
              ..._killFeed.take(3).map(
                    (k) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(k,
                          style:
                              const TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Stack(
      children: [
        Positioned(
          left: 24,
          bottom: 24,
          child: _Joystick(
            onChanged: (d) => _moveDir = d,
          ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: _Joystick(
            color: _kRed,
            onChanged: (d) {
              _aimDir = d;
              _firing = d.distance > 0.3 && _playerArmed && _playerAmmo > 0;
            },
            onEnd: () => _firing = false,
          ),
        ),
        if (!_playerArmed)
          Positioned(
            bottom: 140,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('دور على سلاح على الأرض',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        if (_playerArmed)
          Positioned(
            right: 24,
            bottom: 140,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('الذخيرة: $_playerAmmo',
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
      ],
    );
  }

  Widget _buildDropOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.35),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight, color: Colors.white, size: 54),
            SizedBox(height: 16),
            Text(
              'جاري القفز...',
              style:
                  TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
              color: _won ? Colors.amber : _kRed,
              size: 72,
            ),
            const SizedBox(height: 16),
            Text(
              _won ? 'فوز - أنت الأخير الباقي!' : 'هزيمة',
              style: const TextStyle(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _restart,
              style: ElevatedButton.styleFrom(backgroundColor: _kRed),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text('إعادة المحاولة',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  const Text('رجوع للرئيسية', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Joystick extends StatefulWidget {
  final ValueChanged<Offset> onChanged;
  final VoidCallback? onEnd;
  final Color color;
  const _Joystick(
      {required this.onChanged, this.onEnd, this.color = Colors.white});

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  Offset _knob = Offset.zero;
  static const _radius = 50.0;

  void _update(Offset local) {
    const center = Offset(_radius, _radius);
    var d = local - center;
    if (d.distance > _radius) d = d / d.distance * _radius;
    setState(() => _knob = d);
    widget.onChanged(d / _radius);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (e) => _update(e.localPosition),
      onPanUpdate: (e) => _update(e.localPosition),
      onPanEnd: (_) {
        setState(() => _knob = Offset.zero);
        widget.onChanged(Offset.zero);
        widget.onEnd?.call();
      },
      child: Container(
        width: _radius * 2,
        height: _radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black38,
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: Align(
          alignment: Alignment.center,
          child: Transform.translate(
            offset: _knob,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(0.85),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArenaPainter extends CustomPainter {
  final Offset playerPos;
  final double aimAngle;
  final List<_Bot> bots;
  final List<_LootItem> loot;
  final List<_Bullet> bullets;
  final List<_Dummy> dummies;
  final Offset zoneCenter;
  final double zoneRadius;
  final GameMode mode;

  _ArenaPainter({
    required this.playerPos,
    required this.aimAngle,
    required this.bots,
    required this.loot,
    required this.bullets,
    required this.dummies,
    required this.zoneCenter,
    required this.zoneRadius,
    required this.mode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cam = playerPos - Offset(size.width / 2, size.height / 2);
    Offset toScreen(Offset world) => world - cam;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF17331D),
    );

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.035)
      ..strokeWidth = 1;
    const step = 80.0;
    final startX = -(cam.dx % step);
    final startY = -(cam.dy % step);
    for (double x = startX; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = startY; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final border = const Rect.fromLTWH(0, 0, _kArenaSize, _kArenaSize).shift(-cam);
    canvas.drawRect(
      border,
      Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );

    if (mode == GameMode.battleRoyale) {
      final safeCenterScreen = toScreen(zoneCenter);
      final path = Path()
        ..addRect(Offset.zero & size)
        ..addOval(Rect.fromCircle(center: safeCenterScreen, radius: zoneRadius))
        ..fillType = PathFillType.evenOdd;
      canvas.drawPath(
          path, Paint()..color = const Color(0xFF3A0000).withOpacity(0.45));
      canvas.drawCircle(
        safeCenterScreen,
        zoneRadius,
        Paint()
          ..color = Colors.lightBlueAccent.withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    for (final l in loot) {
      if (l.taken) continue;
      final p = toScreen(l.pos);
      Color c;
      switch (l.type) {
        case LootType.weapon:
          c = Colors.amber;
          break;
        case LootType.ammo:
          c = Colors.lightBlueAccent;
          break;
        case LootType.heal:
          c = Colors.greenAccent;
          break;
      }
      final rect = Rect.fromCenter(center: p, width: 26, height: 26);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = c.withOpacity(0.85),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    for (final d in dummies) {
      final p = toScreen(d.pos);
      canvas.drawCircle(p, 22, Paint()..color = Colors.brown.shade300);
      canvas.drawCircle(
          p,
          22,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.black54
            ..strokeWidth = 3);
      _drawText(canvas, p - const Offset(0, 36), '${d.hits}');
    }

    for (final bot in bots) {
      if (!bot.alive) continue;
      final p = toScreen(bot.pos);
      _drawCharacter(canvas, p, bot.aimAngle, _kRed);
      canvas.drawRect(
        Rect.fromCenter(center: p - const Offset(0, 34), width: 36, height: 5),
        Paint()..color = Colors.black54,
      );
      canvas.drawRect(
        Rect.fromLTWH(p.dx - 18, p.dy - 36.5,
            36 * (bot.health / 100).clamp(0, 1), 5),
        Paint()..color = Colors.redAccent,
      );
    }

    for (final b in bullets) {
      final p = toScreen(b.pos);
      canvas.drawCircle(
          p, 4, Paint()..color = b.fromPlayer ? Colors.yellowAccent : Colors.orangeAccent);
    }

    _drawCharacter(
        canvas, Offset(size.width / 2, size.height / 2), aimAngle, Colors.lightBlueAccent);
  }

  void _drawCharacter(Canvas canvas, Offset p, double angle, Color color) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.drawCircle(Offset.zero, 18, Paint()..color = color);
    canvas.drawCircle(
        Offset.zero,
        18,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.black45
          ..strokeWidth = 2);
    canvas.rotate(angle);
    canvas.drawRect(
      const Rect.fromLTWH(0, -3, 26, 6),
      Paint()..color = Colors.black87,
    );
    canvas.restore();
  }

  void _drawText(Canvas canvas, Offset pos, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) => true;
}

// 金币粒子场（M2 核心爽感）——CustomPainter 每帧自绘，逻辑与渲染分离。
// 只负责"把金币画得华丽"，每秒爆多少枚由 CoinEngine（spawnPerSecond）提供。
//
// 实现（手册 §5.3 骨架 + 增强）：
//   · 重力下落 + 落地弹跳两次后堆积成"金堆"
//   · 金币精灵 4 帧旋转（帧 0→1→2→3 循环 = 旋转一圈）
//   · 出生瞬间白色径向闪光 + "+1" 飘字上浮淡出
//   · 每 60 秒一次"金币瀑布"（出币速率临时 ×20，持续 3 秒）
//   · 触觉反馈限频 5 次/秒
//   · 粒子硬上限 maxCoins = 300（防越爆越卡）
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// 一枚在屏幕上的金币粒子
class _Coin {
  _Coin({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.frame,
  });

  double x, y, vx, vy;
  double size;
  int frame;
  double spin = 0; // 帧推进计时（满 1 换下一帧）
  bool landed = false; // 已落地（留在底部金堆）
  double flash = 0; // 出生闪光，1 → 0
}

/// 出生瞬间的 "+1" 飘字
class _FloatText {
  _FloatText(this.x, this.y);
  double x, y;
  double life = 1.0;
}

class CoinField extends StatefulWidget {
  const CoinField({super.key, required this.spawnPerSecond});

  /// 屏幕出币速率（枚/秒）= 账本速率 × 视觉倍率，由 CoinEngine 提供
  final double spawnPerSecond;

  @override
  State<CoinField> createState() => _CoinFieldState();
}

class _CoinFieldState extends State<CoinField>
    with SingleTickerProviderStateMixin {
  static const maxCoins = 300; // 粒子硬上限：保命，防止越爆越卡
  static const _gravity = 900.0; // 重力加速度 px/s²
  static const _settleSpeed = 200.0; // 落地速度低于此值则堆积，不再弹跳
  static const _surgeEvery = 60.0; // 每 60 秒一次金币瀑布
  static const _surgeDuration = 3.0; // 瀑布持续 3 秒
  static const _surgeFactor = 20.0; // 瀑布期间速率 ×20

  late final Ticker _ticker;
  Duration? _lastTick;
  final List<_Coin> _coins = [];
  final List<_FloatText> _floats = [];
  final Random _rng = Random();
  final List<ui.Image> _frames = [];

  double _width = 0;
  double _height = 0;
  double _spawnAcc = 0;
  double _surgeRemaining = 0;
  double _surgeClock = 0;
  double _hapticClock = 0;

  static const _spriteAssets = [
    'assets/images/coin_0.png',
    'assets/images/coin_1.png',
    'assets/images/coin_2.png',
    'assets/images/coin_3.png',
  ];

  /// 实际出币速率（金币瀑布期间临时 ×20）
  double get _effectiveSpawn =>
      widget.spawnPerSecond * (_surgeRemaining > 0 ? _surgeFactor : 1);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_update)..start();
    _loadSprites();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _loadSprites() async {
    for (final path in _spriteAssets) {
      try {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        _frames.add((await codec.getNextFrame()).image);
      } catch (_) {
        // 素材缺失时退回占位圆（不阻塞动画）
      }
    }
  }

  void _update(Duration elapsed) {
    // 用真实 dt（而非固定 1/60）：掉帧时动画不加速，切后台回来跳过超大帧
    final dt = _lastTick == null
        ? 1 / 60
        : (elapsed - _lastTick!).inMicroseconds /
            Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.1) return;

    // ① 金币瀑布计时（每 60 秒爆发一次）
    if (_surgeRemaining > 0) {
      _surgeRemaining -= dt;
    } else {
      _surgeClock += dt;
      if (_surgeClock >= _surgeEvery) {
        _surgeClock = 0;
        _surgeRemaining = _surgeDuration;
      }
    }

    // ② 按速率出生
    final rate = _effectiveSpawn;
    if (rate > 0) {
      _spawnAcc += rate * dt;
      while (_spawnAcc >= 1 && _coins.length < maxCoins) {
        _spawnAcc -= 1;
        // 瀑布期间不飘字（太多会糊），平时每枚都飘 "+1"
        _spawn(x: _rng.nextDouble() * _width, showText: _surgeRemaining <= 0);
      }
    }

    // ③ 物理推进：重力 + 落地弹跳/堆积
    final floor = _height - 150; // 底部金堆区（在下方按钮区之上，金堆可见）
    for (final c in _coins) {
      if (c.landed) continue;
      c.vy += _gravity * dt;
      c.x += c.vx * dt;
      c.y += c.vy * dt;
      c.spin += dt * 10;
      if (c.spin >= 1 && _frames.isNotEmpty) {
        c.spin -= 1;
        c.frame = (c.frame + 1) % _frames.length;
      }
      if (c.flash > 0) c.flash = max(0, c.flash - dt * 3);
      if (c.y >= floor) {
        if (c.vy > _settleSpeed) {
          c.y = floor;
          c.vy = -c.vy * 0.42; // 弹跳衰减
        } else {
          c.vy = 0;
          c.landed = true;
          c.y = floor - _rng.nextDouble() * 36; // 随机高度，堆出"金山"层次感
        }
      }
    }

    // ④ 飘字上浮淡出
    for (final f in _floats) {
      f.y -= 46 * dt;
      f.life -= dt * 1.1;
    }
    _floats.removeWhere((f) => f.life <= 0);

    // ⑤ 超限移除最老的金币（金山不无限涨）
    while (_coins.length > maxCoins) {
      _coins.removeAt(0);
    }

    setState(() {});
  }

  void _spawn({required double x, bool showText = false}) {
    final c = _Coin(
      x: x,
      y: -30 - _rng.nextDouble() * 50,
      vx: (_rng.nextDouble() - 0.5) * 70,
      vy: 130 + _rng.nextDouble() * 140,
      size: 26 + _rng.nextDouble() * 16,
      frame: _frames.isEmpty ? 0 : _rng.nextInt(_frames.length),
    )..flash = 1.0;
    _coins.add(c);
    if (showText) _floats.add(_FloatText(c.x, c.y + 22));
    _maybeHaptic();
  }

  /// 触觉反馈（限频 5 次/秒，防手麻）
  void _maybeHaptic() {
    if (_hapticClock > 0) return;
    _hapticClock = 0.2;
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        _height = constraints.maxHeight;
        final landed = _coins.where((c) => c.landed).length;
        return RepaintBoundary(
          child: CustomPaint(
            painter: _CoinPainter(
              coins: _coins,
              floats: _floats,
              frames: _frames,
              pileRatio: _coins.isEmpty ? 0 : landed / _coins.length,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _CoinPainter extends CustomPainter {
  _CoinPainter({
    required this.coins,
    required this.floats,
    required this.frames,
    required this.pileRatio,
  });

  final List<_Coin> coins;
  final List<_FloatText> floats;
  final List<ui.Image> frames;
  final double pileRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.medium;

    // 底部金堆：落地越多，金堆越高越亮（向上长到金币落地区）
    if (pileRatio > 0.02) {
      final pileH = 8 + 150 * pileRatio;
      final rect = Rect.fromLTWH(0, size.height - pileH, size.width, pileH);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              kGold.withValues(alpha: 0.12 + 0.35 * pileRatio),
              kGold.withValues(alpha: 0.1 + 0.55 * pileRatio),
            ],
          ).createShader(rect),
      );
    }

    for (final c in coins) {
      // 出生闪光（白色径向光晕，一帧即逝）
      if (c.flash > 0) {
        final r = c.size * (1.6 - c.flash * 0.6);
        canvas.drawCircle(
          Offset(c.x, c.y),
          r,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.5 * c.flash),
                Colors.white.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: Offset(c.x, c.y), radius: r)),
        );
      }

      if (frames.isEmpty) {
        // 素材没加载完时的占位画法
        canvas.drawCircle(Offset(c.x, c.y), c.size / 2, Paint()..color = kGold);
        continue;
      }
      final img = frames[c.frame.clamp(0, frames.length - 1)];
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromCenter(center: Offset(c.x, c.y), width: c.size, height: c.size),
        paint,
      );
    }

    // "+1" 飘字
    for (final f in floats) {
      final tp = TextPainter(
        text: TextSpan(
          text: '+1',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: kGold.withValues(alpha: f.life),
            shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(f.x - tp.width / 2, f.y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _CoinPainter oldDelegate) => true;
}

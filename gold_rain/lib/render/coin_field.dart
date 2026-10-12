// 金币粒子场（M2 核心爽感 + P1 + v0.5.0 改进版）——CustomPainter 每帧自绘，逻辑与渲染分离。
// 只负责"把金币画得华丽"，每秒爆多少枚由 CoinEngine（spawnPerSecond）提供。
//
// 实现（手册 §5.3 骨架 + 增强）：
//   · 重力下落 + 落地弹跳两次后堆积成"金堆"
//   · 金币精灵 4 帧旋转（帧 0→1→2→3 循环 = 旋转一圈）
//   · 出生瞬间白色径向闪光 + "+1" 飘字上浮淡出
//   · 每 60 秒一次"金币瀑布"（速率 ×20，3 秒）；P1 整点再爆一次更猛的（×40，4 秒）
//   · P1 音效：金币落地"叮"（限频）+ 瀑布"唰"，有静音开关
//   · P1 皮肤：精灵图与主题色由 CoinSkin 提供（金库余额解锁）
//   · v0.5.0 爆屏屏震：任何爆发（瀑布/整点/彩蛋）的头 0.5s 屏幕随机抖动衰减
//   · v0.5.0 落地溅小金币：金币落地溅出 1~2 颗微尘火花（短命淡出）
//   · v0.5.0 瀑布密集叮声：爆发期间叮声放宽限频到 40ms、音量稍大（噼里啪啦）
//   · v0.5.0 彩蛋：公开 CoinFieldState.triggerSurge()，页面可随时引爆大爆发
//   · 触觉反馈限频 5 次/秒；粒子硬上限 maxCoins = 300（防越爆越卡）
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'skins.dart';
import 'sound_player.dart';

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

/// 落地溅出的微尘火花（短命、淡出、越小越亮）
class _Spark {
  _Spark({required this.x, required this.y, required this.vx, required this.vy});

  double x, y, vx, vy;
  double life = 1.0;
}

/// 出生瞬间的 "+1" 飘字
class _FloatText {
  _FloatText(this.x, this.y);
  double x, y;
  double life = 1.0;
}

class CoinField extends StatefulWidget {
  const CoinField({
    super.key,
    required this.spawnPerSecond,
    this.skin = kGoldSkin,
    this.soundOn = true,
    this.onHourlySurge,
  });

  /// 屏幕出币速率（枚/秒）= 账本速率 × 视觉倍率，由 CoinEngine 提供
  final double spawnPerSecond;

  /// 当前皮肤（精灵图 + 主题色），切肤自动重载
  final CoinSkin skin;

  /// 音效开关（来自设置）
  final bool soundOn;

  /// 整点大爆发回调（参数=当前小时），给页面弹"恭喜存活到 X 点"
  final ValueChanged<int>? onHourlySurge;

  @override
  State<CoinField> createState() => CoinFieldState();
}

class CoinFieldState extends State<CoinField>
    with SingleTickerProviderStateMixin {
  static const maxCoins = 300; // 粒子硬上限：保命，防止越爆越卡
  static const _gravity = 900.0; // 重力加速度 px/s²
  static const _settleSpeed = 200.0; // 落地速度低于此值则堆积，不再弹跳
  static const _surgeEvery = 60.0; // 每 60 秒一次金币瀑布
  static const _surgeDuration = 3.0; // 瀑布持续 3 秒
  static const _surgeFactor = 20.0; // 瀑布期间速率 ×20
  static const _hourlyFactor = 40.0; // P1 整点大爆发：速率 ×40
  static const _hourlyDuration = 4.0; // 持续 4 秒
  static const _shakeDuration = 0.5; // 爆屏屏震持续 0.5 秒
  static const _shakeAmp = 8.0; // 屏震最大振幅 px

  late final Ticker _ticker;
  late final SoundPlayer _sound;
  Duration? _lastTick;
  final List<_Coin> _coins = [];
  final List<_Spark> _sparks = [];
  final List<_FloatText> _floats = [];
  final Random _rng = Random();
  final List<ui.Image> _frames = [];

  double _width = 0;
  double _height = 0;
  double _spawnAcc = 0;
  double _surgeRemaining = 0;
  double _surgeClock = 0;
  double _surgeFactorNow = _surgeFactor; // 当前瀑布倍率（可被整点/彩蛋覆盖）
  double _hapticClock = 0;
  double _shakeTime = 0; // 屏震剩余时间（>0 则画面抖动）
  int _landedCount = 0; // 已落地金币数（避免每帧 where 统计分配）
  int _lastHourSurge = -1; // 已触发整点的"小时"，防同小时重复爆

  /// 实际出币速率（瀑布/整点/彩蛋期间临时放大）
  double get _effectiveSpawn =>
      widget.spawnPerSecond * (_surgeRemaining > 0 ? _surgeFactorNow : 1);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_update)..start();
    _sound = SoundPlayer(enabled: widget.soundOn);
    _loadSprites();
  }

  @override
  void didUpdateWidget(covariant CoinField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sound.enabled = widget.soundOn;
    if (oldWidget.skin.id != widget.skin.id) _loadSprites(); // 换肤重载精灵
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _loadSprites() async {
    _frames.clear();
    for (final path in widget.skin.framePaths) {
      try {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        _frames.add((await codec.getNextFrame()).image);
      } catch (_) {
        // 素材缺失时退回占位圆（不阻塞动画）
      }
    }
  }

  /// 引爆一次大爆发（瀑布/整点/彩蛋共用）：指定倍率与时长
  void triggerSurge({double factor = _surgeFactor, double duration = _surgeDuration}) {
    _surgeRemaining = duration;
    _surgeFactorNow = factor;
    _shakeTime = _shakeDuration; // 爆屏屏震
    _sound.whoosh(); // 爆发"唰"
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
      if (_surgeRemaining <= 0) _surgeFactorNow = _surgeFactor;
    } else {
      _surgeClock += dt;
      if (_surgeClock >= _surgeEvery) {
        _surgeClock = 0;
        triggerSurge();
      }
    }

    // ② P1 整点大爆发：跨过整点那一刻爆一次更猛的（同小时只爆一次）
    final now = DateTime.now();
    if (now.minute == 0 && _lastHourSurge != now.hour) {
      _lastHourSurge = now.hour;
      triggerSurge(factor: _hourlyFactor, duration: _hourlyDuration);
      widget.onHourlySurge?.call(now.hour);
    }

    // ③ 按速率出生
    final rate = _effectiveSpawn;
    if (rate > 0) {
      _spawnAcc += rate * dt;
      while (_spawnAcc >= 1 && _coins.length < maxCoins) {
        _spawnAcc -= 1;
        // 爆发期间不飘字（太多会糊），平时每枚都飘 "+1"
        _spawn(x: _rng.nextDouble() * _width, showText: _surgeRemaining <= 0);
      }
    }

    // ④ 物理推进：重力 + 落地弹跳/堆积 + 溅火花
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
          _landedCount++;
          _splash(c); // 落地溅小金币
          if (_surgeRemaining > 0) {
            _sound.burstDing(); // 爆发期密集叮声
          } else {
            _sound.ding(); // 平时"叮"（播放器内部限频）
          }
        }
      }
    }

    // ⑤ 火花：微重力上抛后散落、淡出
    for (final s in _sparks) {
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vy += 500 * dt;
      s.life -= dt * 3.2;
    }
    _sparks.removeWhere((s) => s.life <= 0);

    // ⑥ 飘字上浮淡出
    for (final f in _floats) {
      f.y -= 46 * dt;
      f.life -= dt * 1.1;
    }
    _floats.removeWhere((f) => f.life <= 0);

    // ⑦ 屏震计时衰减
    if (_shakeTime > 0) _shakeTime -= dt;

    // ⑧ 超限移除最老的金币（金山不无限涨）
    while (_coins.length > maxCoins) {
      final removed = _coins.removeAt(0);
      if (removed.landed) _landedCount--;
    }

    setState(() {});
  }

  /// 落地溅出 1~2 颗微尘火花（主题色小圆点，短命）
  void _splash(_Coin c) {
    if (_sparks.length >= 80) return; // 火花上限，防爆
    final n = 1 + _rng.nextInt(2);
    for (var i = 0; i < n; i++) {
      _sparks.add(_Spark(
        x: c.x,
        y: c.y,
        vx: (_rng.nextDouble() - 0.5) * 160,
        vy: -40 - _rng.nextDouble() * 90,
      ));
    }
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
        return RepaintBoundary(
          child: Transform.translate(
            offset: _shakeOffset,
            child: CustomPaint(
              painter: _CoinPainter(
                coins: _coins,
                sparks: _sparks,
                floats: _floats,
                frames: _frames,
                pileRatio: _coins.isEmpty ? 0 : _landedCount / _coins.length,
                themeColor: widget.skin.themeColor,
              ),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }

  /// 屏震偏移：爆发头 0.5s 内随机抖动，随时间衰减到 0
  Offset get _shakeOffset {
    if (_shakeTime <= 0) return Offset.zero;
    final k = _shakeAmp * (_shakeTime / _shakeDuration);
    return Offset(
      (_rng.nextDouble() - 0.5) * 2 * k,
      (_rng.nextDouble() - 0.5) * 2 * k,
    );
  }
}

class _CoinPainter extends CustomPainter {
  _CoinPainter({
    required this.coins,
    required this.sparks,
    required this.floats,
    required this.frames,
    required this.pileRatio,
    required this.themeColor,
  });

  final List<_Coin> coins;
  final List<_Spark> sparks;
  final List<_FloatText> floats;
  final List<ui.Image> frames;
  final double pileRatio;
  final Color themeColor; // 皮肤主题色（堆山/占位圆/飘字）

  // 性能缓存：金堆渐变 Paint 与飘字 TextPainter 复用到画面变化才重建
  double _lastPileRatio = -1;
  Rect _pileRect = Rect.zero;
  Paint? _pilePaint;
  TextPainter? _floatTp;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.medium;

    // 底部金堆：落地越多，金堆越高越亮（向上长到金币落地区）。
    // 高度/透明度随 pileRatio 缓慢变化，变化小于阈值时复用上次的渐变（省每帧建 shader）
    if (pileRatio > 0.02) {
      final pileH = 8 + 150 * pileRatio;
      final rect = Rect.fromLTWH(0, size.height - pileH, size.width, pileH);
      if (_pilePaint == null || (pileRatio - _lastPileRatio).abs() > 0.004) {
        _lastPileRatio = pileRatio;
        _pileRect = rect;
        _pilePaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              themeColor.withValues(alpha: 0.12 + 0.35 * pileRatio),
              themeColor.withValues(alpha: 0.1 + 0.55 * pileRatio),
            ],
          ).createShader(rect);
      }
      canvas.drawRect(_pileRect, _pilePaint!);
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
        canvas.drawCircle(
            Offset(c.x, c.y), c.size / 2, Paint()..color = themeColor);
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

    // 落地溅火花：主题色小圆点，随生命值缩小淡出
    if (sparks.isNotEmpty) {
      for (final s in sparks) {
        final r = 1.5 + s.life * 2;
        canvas.drawCircle(
          Offset(s.x, s.y),
          r,
          Paint()..color = themeColor.withValues(alpha: 0.75 * s.life),
        );
      }
    }

    // "+1" 飘字（缓存 TextPainter，只换 style 省创建）
    if (floats.isNotEmpty) {
      final tp = _floatTp ??= TextPainter(textDirection: TextDirection.ltr);
      for (final f in floats) {
        tp.text = TextSpan(
          text: '+1',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: themeColor.withValues(alpha: f.life),
            shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
          ),
        );
        tp.layout();
        tp.paint(canvas, Offset(f.x - tp.width / 2, f.y - tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CoinPainter oldDelegate) => true;
}

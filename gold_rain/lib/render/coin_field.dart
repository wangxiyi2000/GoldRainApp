// 金币粒子场（M2 核心爽感 + P1 + v0.5.0 改进版）——CustomPainter 每帧自绘，逻辑与渲染分离。
// 只负责"把金币画得华丽"，每秒爆多少枚由 CoinEngine（spawnPerSecond）提供。
//
// 实现（手册 §5.3 骨架 + 增强）：
//   · 重力下落 + 落地弹跳两次后停在落地线堆积（v0.6.1 起不画底部金堆渐变带）
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
  bool landed = false; // 已落地（停在落地线）
  bool collecting = false; // 收仓中：飞向钱袋
  bool dead = false; // 已被吸入袋口（下帧移除）
  double flash = 0; // 出生闪光，1 → 0
}

/// 落地溅出的微尘火花（短命、淡出、越小越亮）
class _Spark {
  _Spark({required this.x, required this.y, required this.vx, required this.vy});

  double x, y, vx, vy;
  double life = 1.0;
}

/// 出生瞬间的 "+1" 飘字（可自定义文案，如收仓"已入仓"）
class _FloatText {
  _FloatText(this.x, this.y, {this.text = '+1'});
  double x, y;
  final String text;
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
  static const _surgeEvery = 10.0; // 每 10 秒一次金币瀑布（v0.6.8 由 60 秒下调）
  static const _surgeDuration = 3.0; // 瀑布持续 3 秒
  static const _surgeFactor = 20.0; // 瀑布期间速率 ×20
  static const _hourlyFactor = 40.0; // P1 整点大爆发：速率 ×40
  static const _hourlyDuration = 4.0; // 持续 4 秒
  static const _shakeDuration = 0.5; // 爆屏屏震持续 0.5 秒
  static const _shakeAmp = 8.0; // 屏震最大振幅 px
  static const _collectAt = 10; // 攒够 10 颗自动收仓（纯视觉，不动账本；v0.6.7 由 20 下调）
  static const _collectMaxSec = 1.2; // 收仓动画最长时长（超时兜底清场）
  static const _collectCooldownSec = 1.5; // 收仓冷却：防"收完立刻又收"的抽搐感

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
  int? _surgeLiveCap; // 爆发期间在场金币上限（null=不限，彩蛋用 20 防卡顿）
  double _hapticClock = 0;
  double _shakeTime = 0; // 屏震剩余时间（>0 则画面抖动）
  int _lastHourSurge = -1; // 已触发整点的"小时"，防同小时重复爆
  double _collectClock = 0; // 收仓计时（>0 表示收仓进行中）
  int _collectTarget = 0; // 本次收仓参与的金币数（吸满或超时即完成）
  int _collectCount = 0; // 已吸入袋口的金币数
  Offset _bagPos = Offset.zero; // 钱袋锚点（右下落地线附近）
  double _collectCooldown = 0; // 收仓冷却（防连续抽搐）

  /// 实际出币速率（瀑布/整点/彩蛋期间临时放大）
  double get _effectiveSpawn =>
      widget.spawnPerSecond * (_surgeRemaining > 0 ? _surgeFactorNow : 1);

  /// 是否正在收仓（供测试/调试观察）
  bool get isCollecting => _collectClock > 0;

  /// 当前屏幕金币数（供测试/调试观察）
  int get coinCount => _coins.length;

  bool get _collecting => _collectClock > 0;

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
  void triggerSurge({double factor = _surgeFactor, double duration = _surgeDuration, int? liveCap}) {
    _surgeRemaining = duration;
    _surgeFactorNow = factor;
    _surgeLiveCap = liveCap; // 传 liveCap 可限制爆发期间在场金币数（防满屏卡顿）
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
        triggerSurge(liveCap: 10); // 普通金币雨在场金币封顶 10 颗
      }
    }

    // ② P1 整点大爆发：跨过整点那一刻爆一次更猛的（同小时只爆一次）
    final now = DateTime.now();
    if (now.minute == 0 && _lastHourSurge != now.hour) {
      _lastHourSurge = now.hour;
      triggerSurge(
          factor: _hourlyFactor,
          duration: _hourlyDuration,
          liveCap: 30); // 整点爆发在场金币封顶 30 颗
      widget.onHourlySurge?.call(now.hour);
    }

    // ③ 按速率出生
    final rate = _effectiveSpawn;
    if (rate > 0) {
      _spawnAcc += rate * dt;
      while (_spawnAcc >= 1 && _coins.length < maxCoins) {
        // 爆发期达到在场金币上限（如彩蛋 liveCap=20）→ 暂停出生，防满屏卡顿
        final cap = _surgeLiveCap;
        if (_surgeRemaining > 0 && cap != null && _coins.length >= cap) {
          break;
        }
        _spawnAcc -= 1;
        // 爆发期间不飘字（太多会糊），平时每枚都飘 "+1"
        _spawn(x: _rng.nextDouble() * _width, showText: _surgeRemaining <= 0);
      }
    }

    // ④ 物理推进：重力 + 落地弹跳/堆积 + 溅火花
    final floor = _height - 150; // 落地线（在下方按钮区之上）
    for (final c in _coins) {
      if (c.landed || c.collecting) continue;
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
          c.y = floor - _rng.nextDouble() * 36; // 随机高度，堆出层次感
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
      _coins.removeAt(0);
    }

    // ⑨ 收仓：屏幕金币攒够 20 颗（非爆发期 + 非冷却）→ 钱袋出现，全部金币飞入
    if (_collectCooldown > 0) _collectCooldown -= dt;
    if (_collecting) {
      _collectClock -= dt;
      final bx = _bagPos.dx;
      final by = _bagPos.dy;
      for (final c in _coins) {
        if (!c.collecting) continue;
        final dx = bx - c.x;
        final dy = by - c.y;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < 26) {
          c.dead = true; // 吸入袋口，下帧移除
          _collectCount++;
          continue;
        }
        // 向钱袋加速（像被吸进去），飞得快自然转起来
        c.vx += dx / dist * 2600 * dt;
        c.vy += dy / dist * 2600 * dt;
        c.x += c.vx * dt;
        c.y += c.vy * dt;
        c.spin += dt * 30;
      }
      _coins.removeWhere((c) => c.dead);
      if (_collectClock <= 0 || _collectCount >= _collectTarget) {
        _finishCollect(); // 入袋反馈 + 清残留
      }
    } else if (_coins.length >= _collectAt &&
        _surgeRemaining <= 0 &&
        _collectCooldown <= 0) {
      _startCollect();
    }

    setState(() {});
  }

  /// 触发收仓：钱袋出现在右下落地线，当前所有金币飞向钱袋（纯视觉，不动账本）
  void _startCollect() {
    _collectClock = _collectMaxSec;
    _collectTarget = _coins.length;
    _collectCount = 0;
    _bagPos = Offset(_width - 64, _height - 150); // 钱袋坐在右下落地线上
    for (final c in _coins) {
      c.collecting = true;
      c.landed = false;
      final dx = _bagPos.dx - c.x;
      final dy = _bagPos.dy - c.y;
      final dist = max(1.0, sqrt(dx * dx + dy * dy));
      c.vx = dx / dist * 900; // 初速指向钱袋
      c.vy = dy / dist * 900;
    }
    _sound.whoosh(); // 收仓"唰"
  }

  /// 收仓完成：清残留金币 + 袋口闪光/飘字/叮 + 冷却
  void _finishCollect() {
    _coins.removeWhere((c) => c.collecting);
    _collectClock = 0;
    _collectCooldown = _collectCooldownSec;
    _sound.ding();
    _floats.add(_FloatText(_bagPos.dx, _bagPos.dy - 46, text: '已入仓'));
    for (var i = 0; i < 8; i++) {
      _sparks.add(_Spark(
        x: _bagPos.dx,
        y: _bagPos.dy,
        vx: cos(i / 8 * 2 * pi) * 130,
        vy: sin(i / 8 * 2 * pi) * 130 - 60,
      ));
    }
    HapticFeedback.lightImpact();
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
                themeColor: widget.skin.themeColor,
                collectPos: _collecting ? _bagPos : null,
                collectPulse: _collectClock,
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
    required this.themeColor,
    required this.collectPos,
    required this.collectPulse,
  });

  final List<_Coin> coins;
  final List<_Spark> sparks;
  final List<_FloatText> floats;
  final List<ui.Image> frames;
  final Color themeColor; // 皮肤主题色（占位圆/火花/飘字/袋口）
  final Offset? collectPos; // 收仓中：钱袋锚点（null = 未收仓）
  final double collectPulse; // 收仓计时（驱动钱袋脉动）

  // 性能缓存：飘字/钱袋"¥" TextPainter 复用到画面变化才重建
  TextPainter? _floatTp;
  TextPainter? _bagTp;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.medium;

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

    // 收仓钱袋：袋口金色 + 棕色袋身 + "¥"（脉动呼吸）
    if (collectPos != null) {
      final bx = collectPos!.dx;
      final by = collectPos!.dy;
      final p = 1 + 0.05 * sin(collectPulse * 30); // 脉动
      final bag = Paint()..color = const Color(0xFF6B4A1F);
      final bagLine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF3E2A12);
      // 袋身
      final body = Path()
        ..moveTo(bx - 20 * p, by - 8 * p)
        ..quadraticBezierTo(bx - 25 * p, by + 22 * p, bx, by + 27 * p)
        ..quadraticBezierTo(bx + 25 * p, by + 22 * p, bx + 20 * p, by - 8 * p)
        ..close();
      canvas.drawPath(body, bag);
      canvas.drawPath(body, bagLine);
      // 袋口
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(bx, by - 12 * p), width: 44 * p, height: 12),
          const Radius.circular(5),
        ),
        Paint()..color = themeColor,
      );
      // 袋身"¥"
      final tp = _bagTp ??= TextPainter(textDirection: TextDirection.ltr);
      tp.text = const TextSpan(
        text: '¥',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: Color(0xFFF5E6C8),
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(bx - tp.width / 2, by + 2 - tp.height / 2));
    }

    // 飘字（"+1"/"已入仓"，缓存 TextPainter，只换 style 省创建）
    if (floats.isNotEmpty) {
      final tp = _floatTp ??= TextPainter(textDirection: TextDirection.ltr);
      for (final f in floats) {
        tp.text = TextSpan(
          text: f.text,
          style: TextStyle(
            fontSize: f.text == '+1' ? 17 : 15,
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

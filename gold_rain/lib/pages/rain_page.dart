// 搬砖中页面（PRD v1.3 + M2 + P1 + v0.5.0）：金币实时爆屏 + 金额 3 位小数连续跳动。
// 不需要「下班打卡」——过了下班时间会自动收工、自动入库。
// M2：叠上 CoinField 金币粒子动画（灵魂功能）。
// P1：整点大爆发时弹「恭喜存活到 X 点」提示条；皮肤/音效设置透传给粒子场。
// v0.5.0：今日收益每跨 ¥100 触发彩蛋——×100 大爆发 + 「今日破百」提示条。
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../render/coin_field.dart';
import '../theme.dart';

class RainPage extends StatefulWidget {
  const RainPage({
    super.key,
    required this.settings,
    required this.coins,
    required this.elapsed,
    required this.onOpenVault,
    required this.onOpenSettings,
  });

  final AppSettings settings;
  final double coins; // 今日已赚（元），由「上班时间 → 现在」推算
  final Duration elapsed; // 已搬砖时长
  final VoidCallback onOpenVault;
  final VoidCallback onOpenSettings;

  @override
  State<RainPage> createState() => _RainPageState();
}

class _RainPageState extends State<RainPage> {
  final GlobalKey<CoinFieldState> _fieldKey = GlobalKey<CoinFieldState>();
  String? _toastText; // 提示条文案（整点 / 彩蛋共用，null = 不显示）
  Timer? _toastTimer;
  late int _eggLevel; // 今日已跨过的"百元档位"（彩蛋去重）

  // 彩蛋：今日收益跨过整百的瞬间，引爆 ×100 大爆发（每档只触发一次）
  int get _eggDiv => 100;

  @override
  void initState() {
    super.initState();
    _eggLevel = widget.coins ~/ _eggDiv; // 进页面就已在某档，不触发
  }

  /// 统一弹提示条，3 秒后自动消失
  void _showToast(String text) {
    _toastTimer?.cancel();
    setState(() => _toastText = text);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toastText = null);
    });
  }

  /// 整点大爆发：弹「恭喜存活到 X 点」
  void _onHourlySurge(int hour) {
    _showToast('恭喜存活到 $hour 点！金币雨 ×40');
  }

  @override
  void didUpdateWidget(covariant RainPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 彩蛋：今日收益跨过整百的瞬间，引爆 ×100 大爆发（每档只触发一次）
    final level = widget.coins ~/ _eggDiv;
    if (level > _eggLevel && level >= 1) {
      _eggLevel = level;
      _fieldKey.currentState?.triggerSurge(factor: 100, duration: 6);
      _showToast('今日破百！彩蛋 ×100');
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.settings.toEngine();
    final total = widget.settings.toShift().total;
    var remaining = total - widget.elapsed;
    if (remaining.isNegative) remaining = Duration.zero;

    return Stack(
      children: [
        // 金币粒子层（传「屏幕出币速率」= 账本速率 × 视觉倍率；皮肤/音效/整点回调一起透传）
        Positioned.fill(
          child: CoinField(
            key: _fieldKey,
            spawnPerSecond: engine.spawnPerSecond,
            skin: widget.settings.skin,
            soundOn: widget.settings.soundEnabled,
            onHourlySurge: _onHourlySurge,
          ),
        ),
        // 信息层（半透明底，金币穿过也看得清）
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 28),
              Text('搬砖中…血汗钱实时到账',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
              const Spacer(),
              _BigAmount(coins: widget.coins),
              const SizedBox(height: 10),
              Text(
                '时薪 ${engine.hourlyRate.toStringAsFixed(2)} 元 ｜ '
                '账本 ＋${engine.coinsPerSecond.toStringAsFixed(4)} 枚/秒'
                '（屏幕 ×${widget.settings.visualMultiplier}）',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                '已搬 ${formatDuration(widget.elapsed)} ｜ '
                '距 ${widget.settings.workEndLabel} 下班还有 ${formatDuration(remaining)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: widget.onOpenVault,
                    icon:
                        const Icon(Icons.account_balance, size: 18, color: kGold),
                    label: const Text('金库', style: TextStyle(color: kGold)),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: widget.onOpenSettings,
                    icon: const Icon(Icons.settings, size: 18, color: kGold),
                    label: const Text('设置', style: TextStyle(color: kGold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        // 整点提示条（金币层之上，金币穿过也显眼）
        if (_toastText != null)
          Positioned(
            top: 64,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(_toastText),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: kGold.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    _toastText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: kGold,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 大金额数字（半透明底上，金币穿过也能看清）
class _BigAmount extends StatelessWidget {
  const _BigAmount({required this.coins});

  final double coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(24),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: coins),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
        builder: (_, v, __) => Text(
          formatCoins(v),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 58,
            fontWeight: FontWeight.w900,
            color: kGold,
            shadows: [Shadow(color: kGoldDark, blurRadius: 30)],
          ),
        ),
      ),
    );
  }
}

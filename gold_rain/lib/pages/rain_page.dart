// 搬砖中页面（PRD v1.3 + M2 + P1 + v0.5.0 + v0.6.0）：金币实时爆屏 + 金额 3 位小数连续跳动。
// 不需要「下班打卡」——过了下班时间会自动收工、自动入库。
// M2：叠上 CoinField 金币粒子动画（灵魂功能）。
// P1：整点大爆发时弹「恭喜存活到 X 点」提示条；皮肤/音效设置透传给粒子场。
// v0.5.0：今日收益每跨 ¥100 触发彩蛋——×40 大爆发 + 「今日破百」提示条。
// v0.6.0：彩蛋补放——错过跨百、下次打开 App 时补放一次彩蛋（「你错过的彩蛋」），
//         档位持久化在 main 层（eggDate/eggLevel），这里只负责检测与引爆。
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
    required this.eggLevel,
    required this.onEggAdvanced,
    required this.onOpenVault,
    required this.onOpenFinance,
    required this.onOpenSettings,
  });

  final AppSettings settings;
  final double coins; // 今日已赚（元），由「上班时间 → 现在」推算
  final Duration elapsed; // 已搬砖时长

  /// 今日已庆祝到的"百元档位"（main 层持久化，跨天自动归 0）
  final int eggLevel;

  /// 彩蛋档位前进回调（跨百 / 补放共用），由 main 层持久化防重复
  final ValueChanged<int> onEggAdvanced;

  final VoidCallback onOpenVault;
  final VoidCallback onOpenFinance;
  final VoidCallback onOpenSettings;

  @override
  State<RainPage> createState() => _RainPageState();
}

class _RainPageState extends State<RainPage> {
  final GlobalKey<CoinFieldState> _fieldKey = GlobalKey<CoinFieldState>();
  String? _toastText; // 提示条文案（整点 / 彩蛋共用，null = 不显示）
  Timer? _toastTimer;
  late int _eggLevel; // 今日已庆祝到的"百元档位"（彩蛋去重）

  // 彩蛋：今日收益跨过整百的瞬间，引爆 ×40 大爆发（每档只触发一次）
  int get _eggDiv => 100;

  @override
  void initState() {
    super.initState();
    _eggLevel = widget.eggLevel; // 从持久化档位起步
    // 补放：首帧后检查"已跨过但没庆祝过"的档位（此时 CoinField 已挂载，可引爆）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final level = widget.coins ~/ _eggDiv;
      if (level > _eggLevel && level >= 1) {
        _celebrate(level, missed: true);
      }
    });
  }

  /// 统一弹提示条，3 秒后自动消失
  void _showToast(String text) {
    _toastTimer?.cancel();
    setState(() => _toastText = text);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toastText = null);
    });
  }

  /// 整点大爆发：弹「又到 X 点啦」
  void _onHourlySurge(int hour) {
    _showToast('太棒了，又到 $hour 点！金币雨 ×20 🎉');
  }

  /// 庆祝一次彩蛋（实时跨百 missed=false / 补放 missed=true），每档只庆祝一次
  void _celebrate(int level, {required bool missed}) {
    _eggLevel = level;
    widget.onEggAdvanced(level); // 持久化，防同档重复
    _fieldKey.currentState?.triggerSurge(
        factor: 40, duration: 4, liveCap: 10); // 彩蛋在场金币封顶 10 颗防卡顿（v0.6.22 由 ×100/6s/20 下调）
    _showToast(
        missed ? '你错过的彩蛋：已入账 ¥${level * _eggDiv}' : '今日破百！彩蛋 ×40');
  }

  @override
  void didUpdateWidget(covariant RainPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 实时彩蛋：开着 App 时今日收益跨过整百的瞬间引爆（每档只触发一次）
    final level = widget.coins ~/ _eggDiv;
    if (level > _eggLevel && level >= 1) {
      _celebrate(level, missed: false);
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
              Text('努力搬砖中…收益实时到账 ✨',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
              const Spacer(),
              _BigAmount(coins: widget.coins),
              const SizedBox(height: 10),
              Text(
                '时薪 ${engine.hourlyRate.toStringAsFixed(2)} 元 ｜ '
                '${engine.purchasingPower(widget.coins)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                '已搬砖 ${formatDuration(widget.elapsed)} ｜ '
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
                    onPressed: widget.onOpenFinance,
                    icon: const Icon(Icons.savings, size: 18, color: kGold),
                    label: const Text('理财', style: TextStyle(color: kGold)),
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
        builder: (_, v, __) => Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // 左侧「元」透明占位：与右侧「元」等宽 → 数字正好落在屏幕正中，
            // 金额位数少时也不会偏右（右侧「元」固定在最右，不随位数移动）
            const Text(
              ' 元',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Colors.transparent,
              ),
            ),
            // 金额区自适应占满中间（原来固定 280dp + 右对齐：窄屏会整组溢出、
            // 且金额小的时候数字被挤到右边）。数字恒定居中；超长自动缩小不溢出。
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  formatCoins(v),
                  style: const TextStyle(
                    fontSize: 58,
                    fontWeight: FontWeight.w900,
                    color: kGold,
                    shadows: [Shadow(color: kGoldDark, blurRadius: 30)],
                  ),
                ),
              ),
            ),
            const Text(
              ' 元',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: kGold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 搬砖中页面（PRD v1.3 + M2）：金币实时爆屏 + 金额 3 位小数连续跳动。
// 不需要「下班打卡」——过了下班时间会自动收工、自动入库。
// M2：叠上 CoinField 金币粒子动画（灵魂功能）。
import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../render/coin_field.dart';
import '../theme.dart';

class RainPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final engine = settings.toEngine();
    final total = settings.toShift().total;
    var remaining = total - elapsed;
    if (remaining.isNegative) remaining = Duration.zero;

    return Stack(
      children: [
        // 金币粒子层（注意：传「屏幕出币速率」= 账本速率 × 视觉倍率，不是账本速率）
        Positioned.fill(
          child: CoinField(spawnPerSecond: engine.spawnPerSecond),
        ),
        // 信息层（半透明底，金币穿过也看得清）
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 28),
              Text('搬砖中…血汗钱实时到账',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
              const Spacer(),
              _BigAmount(coins: coins),
              const SizedBox(height: 10),
              Text(
                '时薪 ${engine.hourlyRate.toStringAsFixed(2)} 元 ｜ '
                '账本 ＋${engine.coinsPerSecond.toStringAsFixed(4)} 枚/秒'
                '（屏幕 ×${settings.visualMultiplier}）',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                '已搬 ${formatDuration(elapsed)} ｜ '
                '距 ${settings.workEndLabel} 下班还有 ${formatDuration(remaining)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: onOpenVault,
                    icon:
                        const Icon(Icons.account_balance, size: 18, color: kGold),
                    label: const Text('金库', style: TextStyle(color: kGold)),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings, size: 18, color: kGold),
                    label: const Text('设置', style: TextStyle(color: kGold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
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

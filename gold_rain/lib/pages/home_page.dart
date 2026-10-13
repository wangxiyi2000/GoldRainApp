// 首页（PRD v1.3）：**不需要打卡**。
// 三种静态状态（金币不刷新）：
//   · 休息日   → 周末不算钱，今日 0.000
//   · 上班前   → 今日 0.000，提示几点开爆
//   · 已收工   → 定格全天工资 + 今日战报入口
// 另外把「最近收益」直接列出来，不用点进金库就能看到过往每天赚了多少。
import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/daily_report.dart';
import '../models/shift.dart';
import '../theme.dart';

const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.settings,
    required this.status,
    required this.now,
    required this.todayCoins,
    required this.vaultCoins,
    required this.recent,
    required this.onOpenReport,
    required this.onOpenVault,
    required this.onOpenSettings,
  });

  final AppSettings settings;
  final ShiftStatus status;
  final DateTime now;
  final double todayCoins; // 今日已赚（元）
  final double vaultCoins; // 金库累计
  final List<DailyReport> recent; // 最近几天（新的在前）
  final VoidCallback? onOpenReport; // 已收工才有
  final VoidCallback onOpenVault;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final isRest = status.phase == ShiftPhase.rest;
    final isBefore = status.phase == ShiftPhase.before;

    // 休息日（周末）文案：周六说"周一"，周日说"明天"
    final nextWorkday =
        now.weekday == DateTime.saturday ? '周一' : '明天';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Text('💰',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 60)),
          const Text('搬砖爆金币',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w900, color: kGold)),
          const SizedBox(height: 6),
          Text('努力可视化 · 每 1 元 = 1 枚金币 ✨',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            '时薪 ${settings.hourlyRate.toStringAsFixed(2)} 元 ｜ '
            '${settings.workStartLabel}-${settings.workEndLabel} ｜ '
            '月薪 ${settings.monthlySalary.toStringAsFixed(0)} 元',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // ── 状态卡 ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(
                  color: (isRest || isBefore) ? Colors.white12 : kGoldDark),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text(
                  isRest
                      ? '今天休息 🛌'
                      : (isBefore ? '还没到点 ⏰' : '今日已收工 ✅'),
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                          text: formatCoins(todayCoins),
                          style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: kGold)),
                      const TextSpan(
                          text: ' 元',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: kGold)),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const Text('今日已赚',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 10),
                Text(
                  isRest
                      ? '周末好好休息，养精蓄锐 · $nextWorkday ${settings.workStartLabel} 开爆'
                      : isBefore
                          ? '${settings.workStartLabel} 开爆 · '
                              '还有 ${formatDuration(settings.toShift().startAt(now).difference(now))}'
                          : '今日收获已入账，明天 ${settings.workStartLabel} 继续加油 💪',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
                if (onOpenReport != null) ...[
                  const SizedBox(height: 16),
                  GoldButton(
                      label: '查看今日战报',
                      outlined: true,
                      height: 52,
                      onTap: onOpenReport!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 最近收益 ──
          const SectionLabel('最近收益'),
          const SizedBox(height: 8),
          if (recent.isEmpty)
            Text('还没有收益记录，到了上班时间就会自动开始 🌱',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13))
          else
            ...recent.map((r) => _ReportTile(r)),
          const SizedBox(height: 12),

          // ── 入口 ──
          Row(
            children: [
              Expanded(
                child: _MiniCard(
                  icon: '🏦',
                  label: '金库',
                  value: '${formatCoins(vaultCoins)} 元',
                  onTap: onOpenVault,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniCard(
                  icon: '⚙️',
                  label: '设置',
                  value: '月薪 / 时间',
                  onTap: onOpenSettings,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 一天的战报小条目
class _ReportTile extends StatelessWidget {
  const _ReportTile(this.r);

  final DailyReport r;

  String get _dateLabel =>
      '${r.day.month.toString().padLeft(2, '0')}-${r.day.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(_dateLabel, style: const TextStyle(color: Colors.white70)),
          const SizedBox(width: 8),
          Text(_weekdays[r.day.weekday - 1],
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          if (r.autoSettled)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text('自动补齐',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
            ),
          const Spacer(),
          Text('${formatCoins(r.coins)} 元',
              style: const TextStyle(color: kGold, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text('$icon $label', style: const TextStyle(color: kGold)),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

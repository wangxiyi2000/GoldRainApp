// 今日战报：情绪价值最高点（PRD §4.3）。
// v1.3 起战报是**自动入库**的，这里只负责展示。
import 'package:flutter/material.dart';

import '../engine/coin_engine.dart';
import '../engine/report_generator.dart';
import '../models/daily_report.dart';
import '../theme.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({
    super.key,
    required this.report,
    required this.engine,
    required this.onBackHome,
  });

  final DailyReport report;
  final CoinEngine engine;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('今日战报',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 24, color: kGold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(ReportGenerator.opener(report.day),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        const SizedBox(height: 24),
        TweenAnimationBuilder<double>(
          // 数字滚动：0 → 今日收入，1.5 秒缓动
          tween: Tween(begin: 0, end: report.coins),
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Text(
            formatCoins(v),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 52, fontWeight: FontWeight.w900, color: kGold),
          ),
        ),
        const SizedBox(height: 4),
        Text('元（${report.coins.floor()} 枚金币）',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 16),
        Text(engine.purchasingPower(report.coins),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, color: Colors.white70)),
        const SizedBox(height: 8),
        Text('投入时长 ${formatDuration(report.worked)}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        const SizedBox(height: 8),
        Text('已自动收进金库 ✅',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.green.shade300, fontSize: 13)),
        const SizedBox(height: 40),
        GoldButton(label: '回首页', outlined: true, onTap: onBackHome),
        const SizedBox(height: 16),
        Text(ReportGenerator.closer(report.day),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      ],
    );
  }
}

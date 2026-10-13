// 金库页：累计总额 + 历史战报。总额由所有战报金额汇总而来。
import 'package:flutter/material.dart';

import '../engine/coin_engine.dart';
import '../models/daily_report.dart';
import '../theme.dart';

class VaultPage extends StatelessWidget {
  const VaultPage({
    super.key,
    required this.total,
    required this.reports,
    required this.engine,
  });

  final double total;
  final List<DailyReport> reports; // 新的在前
  final CoinEngine engine;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('金库'),
        backgroundColor: kBg,
        foregroundColor: kGold,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(
              child: Text('🏦', style: TextStyle(fontSize: 56))),
          const SizedBox(height: 8),
          Text(formatCoins(total),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 46, fontWeight: FontWeight.w900, color: kGold)),
          const Center(
              child: Text('累计金币（元）',
                  style: TextStyle(color: Colors.grey, fontSize: 13))),
          const SizedBox(height: 12),
          Text(engine.purchasingPower(total),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 32),
          Text('历史战报（${reports.length} 天）',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          const SizedBox(height: 12),
          if (reports.isEmpty)
            Text('还没有记录，到了上班时间就会自动开始 🌱',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13))
          else
            ...reports.map((r) => _ReportTile(r)),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile(this.r);

  final DailyReport r;

  String get _dayLabel =>
      '${r.day.year}-${r.day.month.toString().padLeft(2, '0')}-${r.day.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_dayLabel,
                        style: const TextStyle(color: Colors.white70)),
                    if (r.autoSettled)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text('自动补齐',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('投入 ${formatDuration(r.worked)}',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          Text('${formatCoins(r.coins)} 元',
              style: const TextStyle(color: kGold, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

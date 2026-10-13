// 理财页（P2）：按「到手工资」用 50/30/20 法则给出月度 / 日均预算，帮用户防月光。
//
// 方案出处见 engine/finance_plan.dart。本页只负责展示与「到手工资」的录入，
// 用户改了到手工资后点保存 → pop 回新的 takeHomePay，由上层写进本地存储。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/finance_plan.dart';
import '../models/app_settings.dart';
import '../theme.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  late final TextEditingController _ctrl;

  /// 当前用的到手工资：输入框有值就用输入框，否则回退到「已设置值 / 月薪 ×0.8」
  double get _takeHome =>
      double.tryParse(_ctrl.text.trim()) ?? widget.settings.effectiveTakeHome;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.settings.effectiveTakeHome.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _useEstimate() {
    setState(() => _ctrl.text =
        (widget.settings.monthlySalary * 0.8).toStringAsFixed(0));
  }

  void _save() {
    if (_takeHome <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('到手工资要大于 0 哦')));
      return;
    }
    Navigator.of(context).pop(_takeHome);
  }

  /// ¥ 金额（千分位、取整）
  static String _y(double v) {
    final s = v.round().toString();
    return '¥${s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    final th = _takeHome;
    final monthlySalary = widget.settings.monthlySalary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('理财'),
        backgroundColor: kBg,
        foregroundColor: kGold,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── 到手工资 ──
          const SectionLabel('到手工资（元）'),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: const TextStyle(color: Colors.white, fontSize: 22),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              prefixText: '¥ ',
              prefixStyle: TextStyle(color: kGold, fontSize: 20),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            '理财按「到手工资」算，不是月薪。月薪 $monthlySalary 元 → '
            '到手约 ${(monthlySalary * 0.8).toStringAsFixed(0)} 元（五险一金 + 个税后）',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _useEstimate,
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('不会算？按月薪 ×0.8 估算一下',
                  style: TextStyle(color: kGold, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 24),

          // ── 方案说明 ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: kGoldDark),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('50 / 30 / 20 法则',
                    style: TextStyle(
                        color: kGold, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  '把到手工资分成三块：50% 必要开销、30% 生活享受、20% 储蓄投资。'
                  '出自哈佛教授伊丽莎白·沃伦《All Your Worth》',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 每日建议 ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kGold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今天建议花',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(_y(dailySpendCap(th)),
                        style: const TextStyle(
                            color: kGold,
                            fontSize: 32,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(width: 6),
                    Text('以内（必要 + 享受）',
                        style:
                            TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionLabel('每月怎么分（按到手工资）'),
          const SizedBox(height: 10),

          // ── 三大类 ──
          ...kFinanceBuckets.map((b) => _BucketCard(bucket: b, takeHome: th)),

          const SizedBox(height: 8),

          // ── 应急金目标 ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🧯 先攒一笔应急金',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  '建议攒够 3~6 个月的必要开销，失业 / 生病时不至于慌。'
                  '按 3 个月算，目标是',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(_y(emergencyFundTarget(th)),
                    style: const TextStyle(
                        color: kGold,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 小贴士 ──
          const SectionLabel('防月光小贴士'),
          const SizedBox(height: 8),
          ...kFinanceTips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(Icons.check_circle_outline,
                          size: 15, color: kGold),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t,
                          style: TextStyle(
                              color: Colors.grey.shade300, fontSize: 13)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          GoldButton(label: '保存', onTap: _save),
          const SizedBox(height: 16),
          Text(
            '本方案是通用参考，请结合所在城市、房租与家庭情况灵活调整。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 单个预算大类卡片：名称 + 比例 + 月额 + 日均 + 子项明细
class _BucketCard extends StatelessWidget {
  const _BucketCard({required this.bucket, required this.takeHome});

  final FinanceBucket bucket;
  final double takeHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: kGoldDark.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${bucket.emoji} ${bucket.name}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: kGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${(bucket.ratio * 100).round()}%',
                    style: const TextStyle(color: kGold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_FinancePageState._y(bucket.monthly(takeHome)),
                  style: const TextStyle(
                      color: kGold,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              const SizedBox(width: 4),
              Text('/ 月',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              const SizedBox(width: 12),
              Text('日均 ${_FinancePageState._y(bucket.daily(takeHome))}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Text(bucket.tagline,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const Divider(height: 20),
          ...bucket.items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text('${it.emoji}  ${it.name}',
                        style: TextStyle(
                            color: Colors.grey.shade300, fontSize: 13)),
                    const Spacer(),
                    Text(_FinancePageState._y(it.monthly(takeHome)),
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

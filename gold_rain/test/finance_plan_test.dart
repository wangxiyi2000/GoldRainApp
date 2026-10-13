// 理财规划引擎测试（P2）：50/30/20 法则的比例、金额与到手工资字段兼容性。
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_rain/engine/finance_plan.dart';
import 'package:gold_rain/models/app_settings.dart';

void main() {
  test('三大类比例之和 = 100%（50/30/20）', () {
    final sum = kFinanceBuckets.fold<double>(0, (s, b) => s + b.ratio);
    expect(sum, closeTo(1.0, 1e-9));
    expect(kFinanceBuckets.map((b) => b.id).toList(), ['needs', 'wants', 'savings']);
    expect(kFinanceBuckets[0].ratio, 0.50);
    expect(kFinanceBuckets[1].ratio, 0.30);
    expect(kFinanceBuckets[2].ratio, 0.20);
  });

  test('每个大类的子项百分比之和 = 该类比例（50/30/20）', () {
    for (final b in kFinanceBuckets) {
      final sum = b.items.fold<double>(0, (s, it) => s + it.percent);
      expect(sum, closeTo(b.ratio * 100, 1e-9), reason: b.name);
    }
  });

  test('月额 = 到手工资 × 比例；日均 = 月额 / 30', () {
    const th = 6000.0;
    expect(kFinanceBuckets[0].monthly(th), 3000); // 必要 50%
    expect(kFinanceBuckets[1].monthly(th), 1800); // 享受 30%
    expect(kFinanceBuckets[2].monthly(th), 1200); // 储蓄 20%
    expect(kFinanceBuckets[0].daily(th), 100); // 3000 / 30
    expect(kFinanceBuckets[1].daily(th), 60);
    expect(kFinanceBuckets[2].daily(th), 40);
  });

  test('子项月额按百分比算（房租 22% / 到手 6000 = 1320）', () {
    const th = 6000.0;
    final rent = kFinanceBuckets[0].items.first; // 房租 / 房贷
    expect(rent.percent, 22);
    expect(rent.monthly(th), closeTo(1320, 1e-9));
  });

  test('每日可花（必要+享受）= 到手 × 80% / 30', () {
    expect(dailySpendCap(6000), closeTo(160, 1e-9));
    expect(dailySpendCap(9000), closeTo(240, 1e-9));
  });

  test('应急金目标 = 3 个月必要开销', () {
    expect(emergencyFundTarget(6000), closeTo(9000, 1e-9));
    expect(emergencyFundTarget(6000, months: 6), closeTo(18000, 1e-9));
  });

  test('到手工资字段：填了就用，没填按月薪 ×0.8 估算', () {
    const unset = AppSettings(monthlySalary: 10000); // takeHomePay 默认 0
    expect(unset.takeHomePay, 0);
    expect(unset.effectiveTakeHome, closeTo(8000, 1e-9));

    const set = AppSettings(monthlySalary: 10000, takeHomePay: 7200);
    expect(set.effectiveTakeHome, 7200);
  });

  test('到手工资持久化往返 + 旧存档兼容', () {
    const s = AppSettings(monthlySalary: 10000, takeHomePay: 7300);
    final back = AppSettings.fromJson(
        Map<String, dynamic>.from(s.toJson().map((k, v) => MapEntry(k, v))));
    expect(back.takeHomePay, 7300);

    // 旧存档没有 takeHomePay 字段 → 0（未设置）
    final old = AppSettings.fromJson({
      'monthlySalary': 10000,
      'workStartMinutes': 540,
      'workEndMinutes': 1080,
      'workDaysPerMonth': 22,
      'visualMultiplier': 100,
    });
    expect(old.takeHomePay, 0);
    expect(old.effectiveTakeHome, closeTo(8000, 1e-9));
  });
}

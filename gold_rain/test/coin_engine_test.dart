// CoinEngine 单元测试：数值引擎是全 App 最核心逻辑，先测后放心。
// 运行：flutter test
//
// 口径（PRD v1.2）：账本 1 元 = 1 枚金币；屏幕出币密度 = 账本 × 视觉倍率。
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_rain/engine/coin_engine.dart';

void main() {
  test('时薪计算：月薪 10000，22 天 × 8 小时', () {
    final e = CoinEngine(monthlySalary: 10000);
    expect(e.hourlyRate, closeTo(56.8, 0.1));
  });

  test('每秒金币速率：1 元 = 1 枚（账本口径）', () {
    final e = CoinEngine(monthlySalary: 10000);
    expect(e.coinsPerSecond, closeTo(0.0158, 0.0001));
  });

  test('干满 1 小时 ≈ 56 枚（1 元 = 1 枚）', () {
    final e = CoinEngine(monthlySalary: 10000);
    expect(e.coinsFor(const Duration(hours: 1)), closeTo(56, 1));
  });

  test('金额按 0.001 精度计算，不提前取整', () {
    final e = CoinEngine(monthlySalary: 10000);
    // 60 秒 ≈ 0.947 枚（界面就显示这个小数）
    expect(e.coinsEarned(const Duration(seconds: 60)), closeTo(0.947, 0.001));
    // 需要整数时才 floor
    expect(e.coinsFor(const Duration(seconds: 60)), 0);
  });

  test('零时长 → 0 金币（不出负数）', () {
    final e = CoinEngine(monthlySalary: 10000);
    expect(e.coinsFor(Duration.zero), 0);
  });

  test('视觉倍率只影响屏幕出币密度，不影响账本数字', () {
    final e = CoinEngine(monthlySalary: 10000, visualMultiplier: 100);
    expect(e.spawnPerSecond, closeTo(e.coinsPerSecond * 100, 1e-9));

    // 倍率改成 1（写实慢节奏），账本速率必须分毫不变
    final e1 = CoinEngine(monthlySalary: 10000, visualMultiplier: 1);
    expect(e1.coinsPerSecond, closeTo(e.coinsPerSecond, 1e-9));
    expect(e1.spawnPerSecond, closeTo(e.coinsPerSecond, 1e-9));
  });

  test('上班/下班时间 → 每日工时（含跨天夜班）', () {
    // 09:00 - 18:00 = 9 小时
    expect(
      CoinEngine.hoursFromClock(startMinutes: 9 * 60, endMinutes: 18 * 60),
      closeTo(9.0, 1e-9),
    );
    // 09:30 - 18:00 = 8.5 小时
    expect(
      CoinEngine.hoursFromClock(startMinutes: 9 * 60 + 30, endMinutes: 18 * 60),
      closeTo(8.5, 1e-9),
    );
    // 22:00 - 次日 06:00 = 8 小时（跨天）
    expect(
      CoinEngine.hoursFromClock(startMinutes: 22 * 60, endMinutes: 6 * 60),
      closeTo(8.0, 1e-9),
    );
  });

  test('购买力换算文案分档正确（1 枚 = 1 元）', () {
    final e = CoinEngine(monthlySalary: 10000);
    expect(e.purchasingPower(0), contains('辣条')); // 0 元 → 辣条百分比档
    expect(e.purchasingPower(12), contains('螺蛳粉')); // 12 元 → 螺蛳粉档
    expect(e.purchasingPower(20), contains('奶茶')); // 20 元 → 奶茶档
    expect(e.purchasingPower(50), contains('烧烤')); // 50 元 → 烧烤档
    expect(e.purchasingPower(300), contains('海底捞')); // 300 元 → 海底捞档
  });
}

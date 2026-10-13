// 金币数值引擎——《搬砖爆金币》最重要的纯逻辑模块。
// 只算数字、不碰 UI，方便单元测试。
//
// 口径（PRD v1.2）：
//   1. 账本严格真实：1 元 = 1 枚金币，不做任何放大。战报/金库的数字就是真金白银。
//   2. 屏幕上的出币密度另由 visualMultiplier（视觉倍率）决定，只影响画面，不影响账本。
//   3. 金额按 0.001（千分之一元）精度展示，所以金币用 double 计算，不提前取整。
class CoinEngine {
  CoinEngine({
    required this.monthlySalary,
    this.workDaysPerMonth = 22,
    this.hoursPerDay = 8,
    this.visualMultiplier = 100,
  });

  final double monthlySalary; // 月薪（元）
  final int workDaysPerMonth; // 每月工作日，默认 22
  final double hoursPerDay; // 每日工时（小时），由上班/下班时间算出
  final int visualMultiplier; // 显示层视觉倍率（只影响画面，不影响账本）

  /// 由「上班时间 / 下班时间」（自 0 点起的分钟数）算出每日工时（小时）。
  /// 例：09:00 → 540，18:00 → 1080，得 9.0 小时；跨天（夜班）自动 +24h。
  static double hoursFromClock({
    required int startMinutes,
    required int endMinutes,
  }) {
    var diff = endMinutes - startMinutes;
    if (diff <= 0) diff += 24 * 60;
    return diff / 60.0;
  }

  /// 时薪（元/小时）
  double get hourlyRate => monthlySalary / (workDaysPerMonth * hoursPerDay);

  /// 每秒入账金币数（账本口径：1 元 = 1 枚）
  double get coinsPerSecond => hourlyRate / 3600;

  /// 屏幕每秒应该爆多少枚金币（= 账本速率 × 视觉倍率，只影响画面）
  double get spawnPerSecond => coinsPerSecond * visualMultiplier;

  /// 一段时长应得的金币（**精确值，保留小数**）。
  /// 界面按 0.001 精度展示，所以这里不做 floor。
  double coinsEarned(Duration d) => d.inMilliseconds / 1000 * coinsPerSecond;

  /// 一段时长应得金币（向下取整，需要整数时用）
  int coinsFor(Duration d) => coinsEarned(d).floor();

  /// 换算文案：金币 → 生活购买力（纯玩梗）。1 枚 = 1 元
  /// v0.6.9 档位更新（贴近日常开销）：3 辣条 / 12 螺蛳粉 / 15 奶茶 / 50 烧烤 / 200 海底捞
  /// v0.6.10 增加高档热门商品（3C+文娱）：1280 演唱会 / 3999 PS5 / 7999 iPhone 17 Pro
  /// v0.6.11 补齐 300~1000 区间：300 双人自助 / 599 AJ 球鞋 / 999 AirPods 4
  String purchasingPower(double coins) {
    final yuan = coins;
    if (yuan >= 7999) return '≈ iPhone 17 Pro ${(yuan / 7999).toStringAsFixed(1)} 部 📱';
    if (yuan >= 3999) return '≈ PS5 游戏机 ${(yuan / 3999).toStringAsFixed(1)} 台 🎮';
    if (yuan >= 1280) return '≈ 演唱会内场票 ${(yuan / 1280).toStringAsFixed(1)} 张 🎤';
    if (yuan >= 999) return '≈ AirPods 4 ${(yuan / 999).toStringAsFixed(1)} 副 🎧';
    if (yuan >= 599) return '≈ AJ 球鞋 ${(yuan / 599).toStringAsFixed(1)} 双 👟';
    if (yuan >= 300) return '≈ 双人自助餐 ${(yuan / 300).toStringAsFixed(1)} 顿 🍽️';
    if (yuan >= 200) return '≈ 海底捞 ${(yuan / 200).toStringAsFixed(1)} 顿 🍲';
    if (yuan >= 50) return '≈ 烧烤 ${(yuan / 50).toStringAsFixed(1)} 顿 🍢';
    if (yuan >= 15) return '≈ 奶茶 ${(yuan / 15).toStringAsFixed(1)} 杯 🧋';
    if (yuan >= 12) return '≈ 螺蛳粉 ${(yuan / 12).toStringAsFixed(1)} 碗 🍜';
    if (yuan >= 3) return '≈ 辣条 ${(yuan / 3).toStringAsFixed(1)} 包 🌶️';
    return '≈ 一根辣条的 ${(yuan * 100 / 3).toStringAsFixed(1)}% 🌶️';
  }
}

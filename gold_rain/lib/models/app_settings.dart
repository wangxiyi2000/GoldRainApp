// 用户设置（PRD v1.2 + P1）：月薪、上班时间、下班时间由用户自己填，全部本地持久化。
// P1 新增：音效开关 soundEnabled、皮肤 skinId（皮肤解锁看金库总额，不存这里）。
// P2 新增：到手工资 takeHomePay（理财页按它做 50/30/20 规划；0 = 未设置，用月薪 ×0.8 估算）。
import '../engine/coin_engine.dart';
import '../render/skins.dart';
import 'shift.dart';

class AppSettings {
  const AppSettings({
    this.monthlySalary = 10000,
    this.workStartMinutes = 9 * 60, // 09:00（自 0 点起的分钟数）
    this.workEndMinutes = 18 * 60, // 18:00
    this.workDaysPerMonth = 22,
    this.visualMultiplier = 100, // 屏幕视觉倍率（只影响画面）
    this.soundEnabled = true, // P1：金币音效开关
    this.skinId = 'gold', // P1：当前皮肤（默认金币）
    this.takeHomePay = 0, // P2：到手工资（0 = 未设置，按 月薪 ×0.8 估算）
  });

  final double monthlySalary;
  final int workStartMinutes;
  final int workEndMinutes;
  final int workDaysPerMonth;
  final int visualMultiplier;
  final bool soundEnabled;
  final String skinId;
  final double takeHomePay;

  /// 当前皮肤（未知 id 自动回退默认金币）
  CoinSkin get skin => skinById(skinId);

  /// 理财用的「到手工资」：用户填了就用，没填按月薪 ×0.8 估算（五险一金 + 个税后）
  double get effectiveTakeHome =>
      takeHomePay > 0 ? takeHomePay : monthlySalary * 0.8;

  /// 每日工时（小时）= 下班 - 上班，跨天自动处理
  double get hoursPerDay => CoinEngine.hoursFromClock(
        startMinutes: workStartMinutes,
        endMinutes: workEndMinutes,
      );

  String get workStartLabel => minutesToHm(workStartMinutes);
  String get workEndLabel => minutesToHm(workEndMinutes);

  /// 当前班次（供"休息 / 上班前 / 搬砖中 / 已收工"四态判断）
  /// 默认 `workdaysOnly: true` —— 周末不算钱（PRD v1.3 用户口径）。
  Shift toShift() =>
      Shift(startMinutes: workStartMinutes, endMinutes: workEndMinutes);

  /// 540 → '09:00'
  static String minutesToHm(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// 时薪（元/小时）
  double get hourlyRate => toEngine().hourlyRate;

  CoinEngine toEngine() => CoinEngine(
        monthlySalary: monthlySalary,
        workDaysPerMonth: workDaysPerMonth,
        hoursPerDay: hoursPerDay,
        visualMultiplier: visualMultiplier,
      );

  AppSettings copyWith({
    double? monthlySalary,
    int? workStartMinutes,
    int? workEndMinutes,
    int? workDaysPerMonth,
    int? visualMultiplier,
    bool? soundEnabled,
    String? skinId,
    double? takeHomePay,
  }) =>
      AppSettings(
        monthlySalary: monthlySalary ?? this.monthlySalary,
        workStartMinutes: workStartMinutes ?? this.workStartMinutes,
        workEndMinutes: workEndMinutes ?? this.workEndMinutes,
        workDaysPerMonth: workDaysPerMonth ?? this.workDaysPerMonth,
        visualMultiplier: visualMultiplier ?? this.visualMultiplier,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        skinId: skinId ?? this.skinId,
        takeHomePay: takeHomePay ?? this.takeHomePay,
      );

  Map<String, Object> toJson() => {
        'monthlySalary': monthlySalary,
        'workStartMinutes': workStartMinutes,
        'workEndMinutes': workEndMinutes,
        'workDaysPerMonth': workDaysPerMonth,
        'visualMultiplier': visualMultiplier,
        'soundEnabled': soundEnabled,
        'skinId': skinId,
        'takeHomePay': takeHomePay,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        monthlySalary: (j['monthlySalary'] as num).toDouble(),
        workStartMinutes: j['workStartMinutes'] as int,
        workEndMinutes: j['workEndMinutes'] as int,
        workDaysPerMonth: j['workDaysPerMonth'] as int,
        visualMultiplier: j['visualMultiplier'] as int,
        // P1 新增字段：旧存档没有时用默认值，向后兼容
        soundEnabled: j['soundEnabled'] as bool? ?? true,
        skinId: j['skinId'] as String? ?? 'gold',
        // P2 新增字段：旧存档没有时 0 = 未设置（按 月薪 ×0.8 估算）
        takeHomePay: (j['takeHomePay'] as num?)?.toDouble() ?? 0,
      );
}

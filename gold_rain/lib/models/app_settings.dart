// 用户设置（PRD v1.2）：月薪、上班时间、下班时间由用户自己填，全部本地持久化。
import '../engine/coin_engine.dart';
import 'shift.dart';

class AppSettings {
  const AppSettings({
    this.monthlySalary = 10000,
    this.workStartMinutes = 9 * 60, // 09:00（自 0 点起的分钟数）
    this.workEndMinutes = 18 * 60, // 18:00
    this.workDaysPerMonth = 22,
    this.visualMultiplier = 100, // 屏幕视觉倍率（只影响画面）
  });

  final double monthlySalary;
  final int workStartMinutes;
  final int workEndMinutes;
  final int workDaysPerMonth;
  final int visualMultiplier;

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
  }) =>
      AppSettings(
        monthlySalary: monthlySalary ?? this.monthlySalary,
        workStartMinutes: workStartMinutes ?? this.workStartMinutes,
        workEndMinutes: workEndMinutes ?? this.workEndMinutes,
        workDaysPerMonth: workDaysPerMonth ?? this.workDaysPerMonth,
        visualMultiplier: visualMultiplier ?? this.visualMultiplier,
      );

  Map<String, Object> toJson() => {
        'monthlySalary': monthlySalary,
        'workStartMinutes': workStartMinutes,
        'workEndMinutes': workEndMinutes,
        'workDaysPerMonth': workDaysPerMonth,
        'visualMultiplier': visualMultiplier,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        monthlySalary: (j['monthlySalary'] as num).toDouble(),
        workStartMinutes: j['workStartMinutes'] as int,
        workEndMinutes: j['workEndMinutes'] as int,
        workDaysPerMonth: j['workDaysPerMonth'] as int,
        visualMultiplier: j['visualMultiplier'] as int,
      );
}

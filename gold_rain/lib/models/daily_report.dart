// 一天的战报（也是金库的账目来源：金库总额 = 所有战报金额之和）
class DailyReport {
  const DailyReport({
    required this.day,
    required this.coins,
    required this.worked,
    this.autoSettled = false,
  });

  final DateTime day; // 归属日
  final double coins; // 当日收入（元 = 枚，1 元 = 1 枚）
  final Duration worked; // 工作时长
  final bool autoSettled; // 是否"忘打卡"自动补结算

  Map<String, Object> toJson() => {
        'day': day.toIso8601String(),
        'coins': coins,
        'workedSeconds': worked.inSeconds,
        'autoSettled': autoSettled,
      };

  factory DailyReport.fromJson(Map<String, dynamic> j) => DailyReport(
        day: DateTime.parse(j['day'] as String),
        coins: (j['coins'] as num).toDouble(),
        worked: Duration(seconds: j['workedSeconds'] as int),
        autoSettled: (j['autoSettled'] as bool?) ?? false,
      );
}

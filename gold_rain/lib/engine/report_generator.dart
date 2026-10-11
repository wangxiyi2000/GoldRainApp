// 战报文案引擎（PRD §4.3）：同一天永远看到同一句（用日期当种子）。
class ReportGenerator {
  const ReportGenerator._();

  static const _openers = [
    '今日血汗钱已可视化 ✅',
    '恭喜存活一天，收益到账 🎉',
    '搬砖结束，金币入库 💰',
    '今日份搬砖，已打包入账 📥',
  ];

  static const _closers = [
    '明天继续爆，打工人！',
    '离财富自由还差亿点点。',
    '老板的库里南，有你一枚螺丝钉的贡献。',
    '砖还没搬完，人不能倒下。',
  ];

  /// 日期种子：同一天恒定
  static int seedOf(DateTime day) =>
      day.year * 10000 + day.month * 100 + day.day;

  static String opener(DateTime day) => _openers[seedOf(day) % _openers.length];

  static String closer(DateTime day) =>
      _closers[(seedOf(day) ~/ 7) % _closers.length];
}

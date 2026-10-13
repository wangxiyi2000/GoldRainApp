// 战报文案引擎（PRD §4.3）：同一天永远看到同一句（用日期当种子）。
class ReportGenerator {
  const ReportGenerator._();

  static const _openers = [
    '今天的努力，已经变成金币啦 ✨',
    '又是充实的一天，收益稳稳入账 💰',
    '每一分付出，都在悄悄回报你 🎉',
    '今日份成果，已打包入账 📥',
  ];

  static const _closers = [
    '你的努力，值得被看见 💪',
    '今天辛苦了，明天继续发光 🌟',
    '积少成多，你正一步步靠近目标 🎯',
    '好好休息，明天会更好 ☀️',
  ];

  /// 日期种子：同一天恒定
  static int seedOf(DateTime day) =>
      day.year * 10000 + day.month * 100 + day.day;

  static String opener(DateTime day) => _openers[seedOf(day) % _openers.length];

  static String closer(DateTime day) =>
      _closers[(seedOf(day) ~/ 7) % _closers.length];
}

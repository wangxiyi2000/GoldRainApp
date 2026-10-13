// 理财规划引擎（P2）：按「到手工资」用 50/30/20 法则拆分月度预算（纯逻辑，可单测）。
//
// 方案出处：Elizabeth Warren & Amelia Warren Tyagi《All Your Worth》(2005) 提出的
// 50/30/20 法则——把「税后到手收入」分成三块：
//   · 50% 必要开销（Needs）  · 30% 生活享受（Wants）  · 20% 储蓄投资（Savings）
// 结合中国国情补充「应急金 3~6 个月必要开销」与「先存后花」原则
// （参考：建设银行 / 证监会投教「4321 定律」、标准普尔家庭资产配置四账户）。

/// 一个花钱子项（占「到手工资」的百分比，同一大类内子项之和 = 该大类比例）
class FinanceItem {
  const FinanceItem(this.name, this.percent, {this.emoji = ''});

  final String name;
  final double percent; // 占到手工资的百分比，如 22 表示 22%
  final String emoji;

  /// 每月金额
  double monthly(double takeHome) => takeHome * percent / 100;
}

/// 一个预算大类（必要开销 / 生活享受 / 储蓄投资）
class FinanceBucket {
  const FinanceBucket({
    required this.id,
    required this.name,
    required this.emoji,
    required this.ratio, // 0.50 / 0.30 / 0.20
    required this.tagline,
    required this.items,
  });

  final String id;
  final String name;
  final String emoji;
  final double ratio; // 占到手工资比例（0~1）
  final String tagline;
  final List<FinanceItem> items;

  /// 该类每月金额
  double monthly(double takeHome) => takeHome * ratio;

  /// 该类日均金额（默认按 30 天摊）
  double daily(double takeHome, {int days = kDaysPerMonth}) =>
      monthly(takeHome) / days;
}

/// 日均口径：按 30 天摊（生活开销每天都发生）
const int kDaysPerMonth = 30;

/// 50/30/20 三大类 + 国情化子项拆分（子项百分比之和 = 50 / 30 / 20）
const List<FinanceBucket> kFinanceBuckets = [
  FinanceBucket(
    id: 'needs',
    name: '必要开销',
    emoji: '🏠',
    ratio: 0.50,
    tagline: '刚需，生活的底座，先保这块',
    items: [
      FinanceItem('房租 / 房贷', 22, emoji: '🏠'),
      FinanceItem('吃饭（工作餐 / 买菜）', 16, emoji: '🍚'),
      FinanceItem('交通通勤', 4, emoji: '🚇'),
      FinanceItem('水电通讯', 4, emoji: '💡'),
      FinanceItem('保险', 4, emoji: '🛡️'),
    ],
  ),
  FinanceBucket(
    id: 'wants',
    name: '生活享受',
    emoji: '🎉',
    ratio: 0.30,
    tagline: '让生活更体面、更开心的钱',
    items: [
      FinanceItem('聚餐娱乐', 10, emoji: '🍽️'),
      FinanceItem('衣饰购物', 8, emoji: '👕'),
      FinanceItem('旅行', 6, emoji: '✈️'),
      FinanceItem('爱好 / 自我提升', 6, emoji: '📚'),
    ],
  ),
  FinanceBucket(
    id: 'savings',
    name: '储蓄投资',
    emoji: '💰',
    ratio: 0.20,
    tagline: '先存后花，越存越有底气',
    items: [
      FinanceItem('应急金（先攒 3~6 个月开销）', 8, emoji: '🧯'),
      FinanceItem('稳健储蓄 / 货币基金', 7, emoji: '🏦'),
      FinanceItem('基金定投', 5, emoji: '📈'),
    ],
  ),
];

/// 应急金目标 = N 个月「必要开销」（默认 3 个月，权威建议 3~6 个月）
double emergencyFundTarget(double takeHome, {int months = 3}) =>
    takeHome * 0.50 * months;

/// 剔除储蓄后、每天可以花的钱（必要 + 享受，按 30 天摊）
double dailySpendCap(double takeHome, {int days = kDaysPerMonth}) =>
    takeHome * 0.80 / days;

/// 理财小贴士（防月光）
const List<String> kFinanceTips = [
  '发工资当天，先把 20% 转进储蓄，剩下的再花（先存后花）',
  '先攒够 3~6 个月「必要开销」的应急金，再谈投资',
  '分清「需要」和「想要」：同样功能里最便宜的那个，才叫必要',
  '大额消费先放 3 天冷静期，多数冲动会自己消失',
];

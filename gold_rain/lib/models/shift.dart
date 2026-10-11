// 固定班次模型（PRD v1.3）——《搬砖爆金币》的核心时间逻辑。
//
// 设计要点：**彻底去掉"打卡"这个概念**。
//   上班时间 / 下班时间来自用户设置，金币永远按「今天的上班时间 → 现在」推算，
//   跟用户什么时候打开 App、有没有点过按钮完全无关。
//   所以：没有忘打卡、没有补结算上限、没有防重复打卡 —— 代码反而更简单。
//
// 一天有四种状态：
//   rest    休息日（周六 / 周日）→ **不算钱**，金币恒为 0，也不入库
//   before  还没到上班时间        → 今日收益 0，金币不刷新
//   working 搬砖中               → 金币按秒实时涨
//   after   已过下班时间          → 金币定格在全天工资，自动入库
enum ShiftPhase { rest, before, working, after }

/// 某个时刻的班次状态快照
class ShiftStatus {
  const ShiftStatus({
    required this.phase,
    required this.day,
    required this.worked,
  });

  final ShiftPhase phase;

  /// 班次归属日（当天 00:00）。跨天夜班时，凌晨那段算前一天。
  final DateTime day;

  /// 已搬砖时长：休息/未开始 = 0；搬砖中 = 上班到现在；已收工 = 全天工时
  final Duration worked;

  bool get isRest => phase == ShiftPhase.rest;
  bool get isWorking => phase == ShiftPhase.working;
  bool get isDone => phase == ShiftPhase.after;
}

/// 一个固定班次（如 09:00 - 18:00）
class Shift {
  const Shift({
    required this.startMinutes,
    required this.endMinutes,
    this.workdaysOnly = true,
  });

  final int startMinutes; // 自 0 点起的分钟数，09:00 → 540
  final int endMinutes; // 18:00 → 1080

  /// 只在工作日上班（用户口径：**周末不算钱**）。false 则一周七天都算。
  final bool workdaysOnly;

  /// 是否工作日（周一~周五）
  static bool isWorkday(DateTime d) =>
      d.weekday >= DateTime.monday && d.weekday <= DateTime.friday;

  /// 单班时长（分钟）。跨天（夜班）自动 +24h。
  int get durationMinutes {
    var d = endMinutes - startMinutes;
    if (d <= 0) d += 24 * 60;
    return d;
  }

  /// 单班时长
  Duration get total => Duration(minutes: durationMinutes);

  bool get isOvernight => endMinutes <= startMinutes;

  static DateTime _day0(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 以 [day] 为「班次开始日」，返回上班时刻
  DateTime startAt(DateTime day) =>
      DateTime(day.year, day.month, day.day)
          .add(Duration(minutes: startMinutes));

  /// 以 [day] 为「班次开始日」，返回下班时刻
  DateTime endAt(DateTime day) => startAt(day).add(total);

  /// 判断 [now] 处于班次的哪个阶段。
  ShiftStatus statusAt(DateTime now) {
    // ① 先看「昨天开始的班次」是否还没结束（跨天夜班，如周五 22:00 → 周六 06:00）
    //    注意：只有当"昨天"本身是工作日时，这个班次才成立
    final yesterday = now.subtract(const Duration(days: 1));
    if (!workdaysOnly || isWorkday(yesterday)) {
      final yStart = startAt(yesterday);
      final yEnd = endAt(yesterday);
      if (!yStart.isAfter(now) && now.isBefore(yEnd)) {
        return ShiftStatus(
          phase: ShiftPhase.working,
          day: _day0(yStart),
          worked: now.difference(yStart),
        );
      }
    }

    // ② 今天不上班（周末）→ 休息，不算钱、不刷新、不入库
    if (workdaysOnly && !isWorkday(now)) {
      return ShiftStatus(
        phase: ShiftPhase.rest,
        day: _day0(now),
        worked: Duration.zero,
      );
    }

    // ③ 再看「今天开始的班次」
    final s = startAt(now);
    final e = endAt(now);
    if (now.isBefore(s)) {
      return ShiftStatus(
        phase: ShiftPhase.before,
        day: _day0(s),
        worked: Duration.zero,
      );
    }
    if (now.isBefore(e)) {
      return ShiftStatus(
        phase: ShiftPhase.working,
        day: _day0(s),
        worked: now.difference(s),
      );
    }
    return ShiftStatus(phase: ShiftPhase.after, day: _day0(s), worked: total);
  }
}

// Shift 单元测试（PRD v1.3）：免打卡模型的核心——四态判断 + 时长推算 + 周末不算钱。
//
// 基准日期：2026-10-12 是周一，10-16 周五，10-17 周六，10-18 周日。
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_rain/models/shift.dart';

void main() {
  // 普通白班 09:00 - 18:00（默认只在工作日生效）
  const day = Shift(startMinutes: 9 * 60, endMinutes: 18 * 60);

  group('班次基础', () {
    test('单班时长：09:00-18:00 = 9 小时', () {
      expect(day.durationMinutes, 9 * 60);
      expect(day.total, const Duration(hours: 9));
      expect(day.isOvernight, isFalse);
    });

    test('工作日判断：周一~周五是，周六周日不是', () {
      expect(Shift.isWorkday(DateTime(2026, 10, 12)), isTrue); // 周一
      expect(Shift.isWorkday(DateTime(2026, 10, 16)), isTrue); // 周五
      expect(Shift.isWorkday(DateTime(2026, 10, 17)), isFalse); // 周六
      expect(Shift.isWorkday(DateTime(2026, 10, 18)), isFalse); // 周日
    });
  });

  group('工作日四态', () {
    test('上班前：今日 0，不刷新', () {
      final st = day.statusAt(DateTime(2026, 10, 12, 7, 30));
      expect(st.phase, ShiftPhase.before);
      expect(st.worked, Duration.zero);
      expect(st.day, DateTime(2026, 10, 12));
    });

    test('上班瞬间（正好 09:00）算搬砖中', () {
      final st = day.statusAt(DateTime(2026, 10, 12, 9, 0));
      expect(st.phase, ShiftPhase.working);
      expect(st.worked, Duration.zero);
    });

    test('搬砖中：10:30 已搬 1h30m（与几点打开 App 无关）', () {
      final st = day.statusAt(DateTime(2026, 10, 12, 10, 30));
      expect(st.phase, ShiftPhase.working);
      expect(st.worked, const Duration(hours: 1, minutes: 30));
    });

    test('下班瞬间（正好 18:00）算已收工，且定格全天 9 小时', () {
      final st = day.statusAt(DateTime(2026, 10, 12, 18, 0));
      expect(st.phase, ShiftPhase.after);
      expect(st.worked, const Duration(hours: 9));
    });

    test('下班后：20:00 仍然是全天 9 小时，不再增长', () {
      final st = day.statusAt(DateTime(2026, 10, 12, 20, 0));
      expect(st.phase, ShiftPhase.after);
      expect(st.worked, const Duration(hours: 9));
    });
  });

  group('周末不算钱', () {
    test('周六全天都是休息态，金币恒为 0', () {
      for (final h in [0, 9, 12, 18, 23]) {
        final st = day.statusAt(DateTime(2026, 10, 17, h, 0));
        expect(st.phase, ShiftPhase.rest, reason: '周六 $h 点应为休息');
        expect(st.worked, Duration.zero);
      }
    });

    test('周日全天都是休息态，不会变成"已收工"白拿钱', () {
      final st = day.statusAt(DateTime(2026, 10, 18, 20, 0));
      expect(st.phase, ShiftPhase.rest);
      expect(st.worked, Duration.zero);
    });

    test('workdaysOnly = false 时周末照常上班', () {
      const everyDay = Shift(
        startMinutes: 9 * 60,
        endMinutes: 18 * 60,
        workdaysOnly: false,
      );
      final st = everyDay.statusAt(DateTime(2026, 10, 17, 10, 0));
      expect(st.phase, ShiftPhase.working);
      expect(st.worked, const Duration(hours: 1));
    });
  });

  group('跨天夜班', () {
    const night = Shift(startMinutes: 22 * 60, endMinutes: 6 * 60);

    test('时长 8 小时，凌晨算前一天', () {
      expect(night.durationMinutes, 8 * 60);
      expect(night.isOvernight, isTrue);

      // 周二 02:00 → 班次是周一 22:00 开的
      final st = night.statusAt(DateTime(2026, 10, 13, 2, 0));
      expect(st.phase, ShiftPhase.working);
      expect(st.worked, const Duration(hours: 4));
      expect(st.day, DateTime(2026, 10, 12)); // 归属日 = 上班那天
    });

    test('周日夜班不算钱：前一天是周日（非工作日）→ 周一凌晨算"上班前"', () {
      final st = night.statusAt(DateTime(2026, 10, 12, 2, 0));
      expect(st.phase, ShiftPhase.before);
    });

    test('周五夜班跨到周六凌晨，仍然算搬砖中（周末规则不打断在班的班次）', () {
      final st = night.statusAt(DateTime(2026, 10, 17, 2, 0)); // 周六 02:00
      expect(st.phase, ShiftPhase.working);
      expect(st.worked, const Duration(hours: 4));
      expect(st.day, DateTime(2026, 10, 16)); // 周五
    });

    test('周六夜班不成立：前一天（周六）不是工作日 → 休息', () {
      final st = night.statusAt(DateTime(2026, 10, 18, 2, 0)); // 周日 02:00
      expect(st.phase, ShiftPhase.rest);
    });

    test('周六白天：休息（不会误判成"上班前"）', () {
      final st = night.statusAt(DateTime(2026, 10, 17, 12, 0));
      expect(st.phase, ShiftPhase.rest);
    });
  });
}

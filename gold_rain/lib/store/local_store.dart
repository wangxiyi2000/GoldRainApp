// 本地持久化（shared_preferences）——全部数据都在手机本地，卸载即清零。
//
// PRD v1.3 起不再有"打卡会话"，只存这几样东西：
//   1. app_settings   用户设置（月薪 / 上下班时间 / 视觉倍率）→ 重开 App 不用重新填
//   2. first_use_day  首次使用日 → 金库自动补造历史的起点
//   3. daily_reports  历史战报列表 → **金库总额 = 所有战报金额之和**（不单独存总额，避免重复计数）
//   4. egg_date/egg_level  v0.6.0：彩蛋已庆祝到的"百元档位"（按天记录，跨天重置）→ 错过跨百也能补放彩蛋
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/daily_report.dart';

class LocalStore {
  static const kSettings = 'app_settings';
  static const kFirstUseDay = 'first_use_day';
  static const kReports = 'daily_reports';
  static const kEggDate = 'egg_date'; // 最近一次彩蛋庆祝的日期（yyyy-MM-dd）
  static const kEggLevel = 'egg_level'; // 该日已庆祝到的百元档位

  // ── 用户设置 ──────────────────────────────────────────
  Future<AppSettings> loadSettings() async {
    final raw = (await SharedPreferences.getInstance()).getString(kSettings);
    if (raw == null) return const AppSettings(); // 首次打开用默认值
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSettings(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(kSettings, jsonEncode(s.toJson()));
  }

  // ── 首次使用日（补造起点）──────────────────────────────
  Future<DateTime?> loadFirstUseDay() async {
    final raw = (await SharedPreferences.getInstance()).getString(kFirstUseDay);
    if (raw == null) return null;
    return DateTime.parse(raw);
  }

  Future<void> saveFirstUseDay(DateTime d) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(kFirstUseDay, d.toIso8601String());
  }

  // ── 历史战报（金库账目）────────────────────────────────
  Future<List<DailyReport>> loadReports() async {
    final raw =
        (await SharedPreferences.getInstance()).getStringList(kReports) ?? [];
    return raw
        .map((e) => DailyReport.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.day.compareTo(a.day)); // 新的在前
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 入账一条战报。**同一天只记一次**（防重复计数），已存在则返回 false。
  Future<bool> addReport(DailyReport r) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(kReports) ?? [];
    final exists = list.any((e) {
      final d = DailyReport.fromJson(jsonDecode(e) as Map<String, dynamic>);
      return _sameDay(d.day, r.day);
    });
    if (exists) return false;
    list.add(jsonEncode(r.toJson()));
    await p.setStringList(kReports, list);
    return true;
  }

  /// 批量入账（自动补齐历史时用，一次读写更省事）。返回真正新增的条数。
  Future<int> addReports(List<DailyReport> items) async {
    if (items.isEmpty) return 0;
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(kReports) ?? [];
    final have = <String>{
      for (final e in list)
        _dayKey(DailyReport.fromJson(jsonDecode(e) as Map<String, dynamic>).day),
    };
    var added = 0;
    for (final r in items) {
      final k = _dayKey(r.day);
      if (have.contains(k)) continue;
      have.add(k);
      list.add(jsonEncode(r.toJson()));
      added++;
    }
    if (added > 0) await p.setStringList(kReports, list);
    return added;
  }

  /// 删掉某一天的战报（改了设置后重算今天用）
  Future<void> removeReport(DateTime day) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(kReports) ?? [];
    final before = list.length;
    list.removeWhere((e) {
      final d = DailyReport.fromJson(jsonDecode(e) as Map<String, dynamic>);
      return _sameDay(d.day, day);
    });
    if (list.length != before) await p.setStringList(kReports, list);
  }

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  // ── 彩蛋档位（v0.6.0：错过跨百也能补放）─────────────────
  /// 读取最近一次彩蛋庆祝的（日期, 档位）。从未庆祝过 → (null, 0)。
  Future<(String?, int)> loadEggState() async {
    final p = await SharedPreferences.getInstance();
    return (p.getString(kEggDate), p.getInt(kEggLevel) ?? 0);
  }

  /// 记录今天已庆祝到的百元档位（跨天由调用方判断重置）
  Future<void> saveEggState(String date, int level) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(kEggDate, date);
    await p.setInt(kEggLevel, level);
  }
}

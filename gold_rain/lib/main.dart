// 搬砖爆金币 · 入口 + 全局状态（M1.5 / PRD v1.3）
//
// 免打卡模型：上班时间 / 下班时间来自设置，金币永远按「今天的上班时间 → 现在」推算。
//   · 上班前  → 今日 0，金币不刷新
//   · 搬砖中  → 每秒实时刷新
//   · 已收工  → 定格全天工资，自动收进金库（不需要点任何按钮）
//
// 另外（用户口径）：从首次使用日到昨天，每个工作日自动补一条全勤战报。
// 不管迟到早退 —— 只要没改设置，每天都是满勤日薪。
import 'dart:async';

import 'package:flutter/material.dart';

import 'engine/coin_engine.dart';
import 'models/app_settings.dart';
import 'models/daily_report.dart';
import 'models/shift.dart';
import 'pages/home_page.dart';
import 'pages/rain_page.dart';
import 'pages/report_page.dart';
import 'pages/settings_page.dart';
import 'pages/vault_page.dart';
import 'store/local_store.dart';
import 'theme.dart';

void main() {
  runApp(const GoldRainApp());
}

class GoldRainApp extends StatelessWidget {
  const GoldRainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '搬砖爆金币',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(primary: kGold),
      ),
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  final LocalStore _store = LocalStore();

  AppSettings _settings = const AppSettings();
  List<DailyReport> _reports = []; // 历史战报 = 金库账目
  DateTime _now = DateTime.now();
  ShiftPhase _phase = ShiftPhase.before;
  String? _banner;

  bool _ready = false;
  bool _viewingReport = false;
  Timer? _timer;
  Duration _tickPeriod = Duration.zero;

  // v0.6.0 彩蛋补放：记录"最近一次庆祝彩蛋的日期与档位"（跨天重置）
  String? _eggDate;
  int _eggLevelStored = 0;

  /// 今日有效的彩蛋档位（跨天或首次使用 → 0，即从第一档开始补放）
  int get _eggLevel => _eggDate == _dayKey(_today) ? _eggLevelStored : 0;

  // ── 派生数据 ──────────────────────────────────────────
  Shift get _shift => _settings.toShift();
  CoinEngine get _engine => _settings.toEngine();

  /// 金库总额 = 所有战报金额之和（不单独存总额，天然不会重复计数）
  double get _vaultCoins => _reports.fold(0.0, (sum, r) => sum + r.coins);

  ShiftStatus get _status => _shift.statusAt(_now);

  DateTime get _today => _day0(_now);

  /// 今日已赚（元）——由「上班时间 → 现在」推算，不做累加
  double get _todayCoins => _engine.coinsEarned(_status.worked);

  /// 今天的战报（只有已收工 / 已入库才有）
  DailyReport? get _todayReport {
    for (final r in _reports) {
      if (_sameDay(r.day, _today)) return r;
    }
    return null;
  }

  /// v0.6.0：彩蛋档位前进（实时跨百 / 补放共用），持久化防止同档重复庆祝
  Future<void> _saveEggLevel(int level) async {
    final key = _dayKey(_today);
    _eggDate = key;
    _eggLevelStored = level;
    await _store.saveEggState(key, level);
  }

  static DateTime _day0(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  // ── 生命周期 ──────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  /// 回到前台立刻重算一次（后台期间 Timer 会被系统挂起）
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  // ── 启动 ─────────────────────────────────────────────
  Future<void> _boot() async {
    _settings = await _store.loadSettings();

    // v0.6.0：读取彩蛋档位（错过跨百时补放彩蛋用）
    final (eggDate, eggLevel) = await _store.loadEggState();
    _eggDate = eggDate;
    _eggLevelStored = eggLevel;

    // 首次使用日 = 金库补造起点
    var firstDay = await _store.loadFirstUseDay();
    if (firstDay == null) {
      firstDay = _today;
      await _store.saveFirstUseDay(firstDay);
    }

    var reports = await _store.loadReports();
    final have = {for (final r in reports) _dayKey(r.day)};

    final full = _shift.total; // 全勤时长
    final fullCoins = _engine.coinsEarned(full);
    final toAdd = <DailyReport>[];

    // ① 补齐历史：首次使用日 → 昨天，每个工作日一条全勤（周末不算钱）
    for (var d = _day0(firstDay);
        d.isBefore(_today);
        d = DateTime(d.year, d.month, d.day + 1)) {
      if (!Shift.isWorkday(d)) continue;
      if (have.contains(_dayKey(d))) continue;
      toAdd.add(DailyReport(
        day: d,
        coins: fullCoins,
        worked: full,
        autoSettled: true,
      ));
    }
    final backfilled = toAdd.length;

    // ② 今天已经过了下班时间 → 自动收工入库
    final st = _shift.statusAt(DateTime.now());
    var bankedToday = false;
    if (st.phase == ShiftPhase.after && !have.contains(_dayKey(_today))) {
      toAdd.add(DailyReport(day: _today, coins: fullCoins, worked: full));
      bankedToday = true;
    }

    if (toAdd.isNotEmpty) {
      await _store.addReports(toAdd);
      reports = await _store.loadReports();
    }

    String? banner;
    if (backfilled > 0) {
      banner = '已自动补齐 $backfilled 天搬砖记录 🧱';
    } else if (bankedToday) {
      banner = '今日已收工，工资已自动入库 ✅';
    }

    if (!mounted) return;
    setState(() {
      _now = DateTime.now();
      _phase = _shift.statusAt(_now).phase;
      _reports = reports;
      _banner = banner;
      _ready = true;
    });
    _syncTimer();
  }

  // ── 心跳：搬砖中每秒刷新，其余时间低频检查状态切换 ──────
  void _syncTimer() {
    final period = _phase == ShiftPhase.working
        ? const Duration(seconds: 1)
        : const Duration(seconds: 15);
    if (_timer != null && _tickPeriod == period) return;
    _tickPeriod = period;
    _timer?.cancel();
    _timer = Timer.periodic(period, (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now();
    final st = _shift.statusAt(now);
    final changed = st.phase != _phase;
    setState(() {
      _now = now;
      _phase = st.phase;
    });
    if (!changed) return;
    _syncTimer();
    if (st.phase == ShiftPhase.after) _bankDay(st.day); // 到点自动收工
  }

  /// 把某一天按「全勤」收进金库（同一天只记一次；**周末不算钱**）
  Future<void> _bankDay(DateTime day) async {
    if (!Shift.isWorkday(day)) return; // 休息日不入库（双保险）
    if (_reports.any((r) => _sameDay(r.day, day))) return;
    final full = _shift.total;
    final ok = await _store.addReport(DailyReport(
      day: day,
      coins: _engine.coinsEarned(full),
      worked: full,
    ));
    if (!ok || !mounted) return;
    final reports = await _store.loadReports();
    if (!mounted) return;
    setState(() {
      _reports = reports;
      _banner = '今日已收工，工资已自动入库 ✅';
    });
  }

  // ── 动作 ─────────────────────────────────────────────
  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<AppSettings>(
      MaterialPageRoute(
          builder: (_) =>
              SettingsPage(initial: _settings, vaultCoins: _vaultCoins)),
    );
    if (result == null) return;
    await _store.saveSettings(result);
    if (!mounted) return;
    setState(() => _settings = result);
    await _refreshToday();
  }

  /// 设置变了：今天的状态与金额都要重算（历史记录保持不动）
  Future<void> _refreshToday() async {
    final now = DateTime.now();
    final st = _shift.statusAt(now);
    if (st.phase == ShiftPhase.after) {
      // 先删掉今天旧的记录，再按新设置重算一条
      final full = _shift.total;
      await _store.removeReport(_day0(now));
      await _store.addReport(DailyReport(
        day: _day0(now),
        coins: _engine.coinsEarned(full),
        worked: full,
      ));
    }
    final reports = await _store.loadReports();
    if (!mounted) return;
    setState(() {
      _now = now;
      _phase = st.phase;
      _reports = reports;
    });
    _syncTimer();
  }

  void _openVault() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VaultPage(
        total: _vaultCoins,
        reports: _reports,
        engine: _engine,
      ),
    ));
  }

  // ── 渲染 ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: !_ready
              ? const Center(child: CircularProgressIndicator(color: kGold))
              : Column(
                  children: [
                    if (_banner != null)
                      _Banner(
                        text: _banner!,
                        onClose: () => setState(() => _banner = null),
                      ),
                    Expanded(child: _buildBody()),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final st = _status;

    // 搬砖中：金币实时爆
    if (st.phase == ShiftPhase.working) {
      return RainPage(
        settings: _settings,
        coins: _todayCoins,
        elapsed: st.worked,
        eggLevel: _eggLevel,
        onEggAdvanced: _saveEggLevel,
        onOpenVault: _openVault,
        onOpenSettings: _openSettings,
      );
    }

    // 已收工且正在看战报
    final report = _todayReport;
    if (_viewingReport && report != null) {
      return ReportPage(
        report: report,
        engine: _engine,
        onBackHome: () => setState(() => _viewingReport = false),
      );
    }

    // 上班前 / 已收工 → 首页（静态，不刷新金币）
    return HomePage(
      settings: _settings,
      status: st,
      now: _now,
      todayCoins: _todayCoins,
      vaultCoins: _vaultCoins,
      recent: _reports.take(7).toList(),
      onOpenReport:
          report == null ? null : () => setState(() => _viewingReport = true),
      onOpenVault: _openVault,
      onOpenSettings: _openSettings,
    );
  }
}

/// 顶部提示条
class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.onClose});

  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: Colors.orange.shade200, fontSize: 13)),
          ),
          GestureDetector(
            onTap: onClose,
            child: Icon(Icons.close, size: 18, color: Colors.orange.shade200),
          ),
        ],
      ),
    );
  }
}

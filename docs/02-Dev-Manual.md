# 《搬砖爆金币》开发手册

> 配套文档：《01-产品定义文档-PRD.md》
> 适用对象：编程新手/业余开发者 ｜ 技术栈：Flutter ｜ 目标：约 5~6 周业余时间做出能装进自己安卓手机的 MVP

---

## 目录

1. [开发前的认知准备](#1-开发前的认知准备)
2. [M0：环境搭建（1 个周末）](#2-m0环境搭建)
3. [项目结构与全局设计](#3-项目结构与全局设计)
4. [M1：免打卡模型与金币引擎（1 周）](#4-m1免打卡模型与金币引擎)
5. [M2：金币爆屏动画——核心爽感（1~2 周）](#5-m2金币爆屏动画)
6. [M3：战报与金库（1 周）](#6-m3战报与金库)
7. [M4：打磨与打包安装（1 周）](#7-m4打磨与打包安装)
8. [测试清单](#8-测试清单)
9. [常见坑速查表](#9-常见坑速查表)
10. [P1 功能实现指引](#10-p1-功能实现指引)

---

## 1. 开发前的认知准备

### 1.1 为什么选 Flutter

| 候选 | 结论 |
|---|---|
| **Flutter** ✅ | 一套代码出安卓+iOS；自带高性能 2D 渲染，做粒子金币雨正合适；Dart 语法对新手友好 |
| 原生 Android（Kotlin） | 只能安卓，且动效开发量大 |
| uni-app/H5 套壳 | 粒子性能弱，华丽场面打折扣 |
| 游戏引擎（Unity） | 杀鸡用牛刀，包体 100MB+ |

### 1.2 你需要具备/接受的东西

- 一台能装的电脑（Windows 即可，8GB 内存起步，16GB 舒服）
- 一个安卓手机（数据线一根）
- 每周能挤出 5~10 小时
- **心态**：报错是常态。90% 的初学障碍是"环境问题"，卡住超过 1 小时就照第 9 章速查表排查

### 1.3 本 App 的技术全景图

```
┌────────────────────────────────────────────┐
│              UI 层（Flutter Widget）          │
│ 首页(上班前/已收工) │ 搬砖页 │ 战报页 │ 金库页 │ 设置页 │
├────────────────────────────────────────────┤
│              逻辑层（纯 Dart）                │
│  Shift 班次三态判断 │ CoinEngine 金币引擎      │
│  ReportGenerator 战报文案 │ Store 本地存储      │
├────────────────────────────────────────────┤
│              渲染层（爽感核心）                │
│  CoinField（CustomPainter 粒子系统）           │
│  金币精灵动画 × 重力/弹跳物理 × 粒子上限管理      │
├────────────────────────────────────────────┤
│              平台层                           │
│  振动 HapticFeedback │ APK 打包侧载             │
└────────────────────────────────────────────┘
```

**关键设计决策**：逻辑与渲染分离。`CoinEngine` 只产出"每秒该爆多少枚"的数字；`CoinField` 只负责把这些数字画得华丽。以后换皮肤、加特效互不干扰。

---

## 2. M0：环境搭建

> 目标：电脑上跑通 Flutter，手机上装出第一个 demo。

### 2.1 安装 Flutter SDK（Windows）

1. 下载：https://docs.flutter.dev/get-started/install/windows 下载最新 stable zip
2. 解压到**没有中文和空格的路径**，例如 `D:\flutter`（⚠️ 不要放 `C:\Program Files`）
3. 加环境变量：`此电脑 → 属性 → 高级系统设置 → 环境变量 → Path → 新建 → D:\flutter\bin`
4. 打开新 PowerShell 验证：

```powershell
flutter --version
```

### 2.2 安装 Android Studio（主要是要它的 SDK 和模拟器）

1. https://developer.android.com/studio 下载安装（一路默认）
2. 打开后进 `More Actions → SDK Manager`，确认装了最新 Android SDK Platform + SDK Tools 里的 **Android SDK Command-line Tools**
3. `More Actions → Virtual Device Manager` 建一个模拟器（Pixel 系列，系统镜像选 API 34+）

### 2.3 接受协议 + 体检

```powershell
flutter doctor --android-licenses
flutter doctor
```

全部打 ✅ 即可（`[!]` 一般是警告，Chrome/VS Code 项可忽略）。

### 2.4 装 VS Code + 插件（写代码用它，比 Android Studio 轻快）

- 装 VS Code：https://code.visualstudio.com
- 扩展市场搜 **Flutter**（作者 Dart Code）安装，会连带装 Dart 插件
- VS Code 里 `Ctrl+Shift+P → Dart: New Flutter Project → Application`，随便建一个 hello world
- 插上手机：**手机开开发者模式（连点 7 次"版本号"）→ 打开 USB 调试 → 数据线连电脑 → 弹窗允许调试**
- VS Code 右下角选中你的手机 → F5 运行 → 手机上出现计数器 demo = **M0 完成** 🎉

---

## 3. 项目结构与全局设计

### 3.1 建项目

```powershell
cd D:\code
flutter create gold_rain
cd gold_rain
flutter pub add shared_preferences
code .
```

### 3.2 目录结构（手动建文件夹，文件随里程碑逐步添加）

```
gold_rain/
├── assets/
│   ├── icon/            # app_icon.png 主图 + make_icons.py（生成 5 档 mipmap 图标）
│   ├── images/          # ← M2 才需要：coin_0.png ~ coin_3.png 金币4帧精灵图
│   └── sounds/          # ← P1 再加：coin.wav 等
├── lib/
│   ├── main.dart                 # 入口 + 全局状态机（AppRoot，含三态/自动收工/自动补齐）
│   ├── theme.dart                # 主色 / 金额格式化 / 公共按钮
│   ├── models/
│   │   ├── app_settings.dart     # 用户设置（月薪/上下班时间/工作日/视觉倍率）+ isWorkday
│   │   ├── shift.dart            # 【核心】固定班次：上班前/搬砖中/已收工 三态判断
│   │   └── daily_report.dart     # 一天的战报（金库账目）
│   ├── engine/
│   │   ├── coin_engine.dart      # 金币数值引擎（纯逻辑，可单测）
│   │   └── report_generator.dart # 战报文案生成
│   ├── render/                   # ← M2 才需要
│   │   ├── coin_field.dart       # 粒子渲染器（核心爽感）
│   │   └── coin_sprite.dart      # 金币精灵帧管理
│   ├── pages/
│   │   ├── home_page.dart        # 首页：上班前/已收工两态 + 最近收益 + 金库/设置入口
│   │   ├── rain_page.dart        # 搬砖中：金额实时跳动
│   │   ├── report_page.dart      # 今日战报
│   │   ├── vault_page.dart       # 金库（累计 + 历史战报）
│   │   └── settings_page.dart    # 设置（月薪/上下班时间/视觉倍率）
│   └── store/
│       └── local_store.dart      # 本地持久化（设置 / 首次使用日 / 历史战报）
└── pubspec.yaml
```

### 3.3 pubspec.yaml 需要声明资源

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/sounds/
```

改完记得跑 `flutter pub get`。

### 3.4 核心数据模型

```dart
// lib/models/shift.dart —— PRD v1.3 核心：没有"打卡"，只有"固定班次"
enum ShiftPhase { rest, before, working, after } // 休息日 / 上班前 / 搬砖中 / 已收工

class Shift {
  const Shift({
    required this.startMinutes,
    required this.endMinutes,
    this.workdaysOnly = true, // 周末不算钱
  });
  final int startMinutes; // 09:00 → 540
  final int endMinutes;   // 18:00 → 1080
  final bool workdaysOnly;

  /// 是否工作日（周一~周五）
  static bool isWorkday(DateTime d) =>
      d.weekday >= DateTime.monday && d.weekday <= DateTime.friday;

  /// 单班时长（跨天夜班自动 +24h）
  int get durationMinutes {
    var d = endMinutes - startMinutes;
    if (d <= 0) d += 24 * 60;
    return d;
  }
  Duration get total => Duration(minutes: durationMinutes);

  /// 判断"现在"处于哪个阶段（这就是取代打卡的全部逻辑）
  ShiftStatus statusAt(DateTime now) {
    // ① 昨天开的班还没结束？（跨天夜班，前提是"昨天"本身是工作日）
    // ② 今天不是工作日 → rest（不算钱、不刷新、不入库）
    // ③ 今天的 before / working / after
    ...
  }
}
```

> 旧版的 `WorkSession`（记录点击打卡时刻 + 12h 补结算封顶）已在 v1.3 **删除**。因为上班时间来自设置，金币永远按「今天的上班时间 → 现在」算，不需要记住"你什么时候点的按钮"。

```dart
// lib/models/app_settings.dart —— 用户设置，全部本地持久化，重开 App 自动恢复
import 'package:gold_rain/engine/coin_engine.dart';

class AppSettings {
  const AppSettings({
    this.monthlySalary = 10000,
    this.workStartMinutes = 9 * 60, // 上班 09:00（自 0 点起的分钟数）
    this.workEndMinutes = 18 * 60, // 下班 18:00
    this.workDaysPerMonth = 22,
    this.visualMultiplier = 100, // 屏幕视觉倍率（只影响画面，不影响账本）
  });

  final double monthlySalary;
  final int workStartMinutes;
  final int workEndMinutes;
  final int workDaysPerMonth;
  final int visualMultiplier;

  /// 每日工时（小时）= 下班 - 上班，跨天（夜班）自动处理
  double get hoursPerDay => CoinEngine.hoursFromClock(
        startMinutes: workStartMinutes,
        endMinutes: workEndMinutes,
      );

  /// 用设置构造金币引擎
  CoinEngine toEngine() => CoinEngine(
        monthlySalary: monthlySalary,
        workDaysPerMonth: workDaysPerMonth,
        hoursPerDay: hoursPerDay,
        visualMultiplier: visualMultiplier,
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
```

---

## 4. M1：免打卡模型与金币引擎

> 目标：**数字层面**全部跑通——能打卡、能看到金币数在涨、能结算。还没有华丽动画，但逻辑闭环了。

### 4.1 金币引擎（本 App 最重要的一段纯逻辑）

```dart
// lib/engine/coin_engine.dart
// 口径（PRD v1.2）：
//   1. 账本严格真实：1 元 = 1 枚金币，不做任何放大。战报/金库的数字就是真金白银。
//   2. 屏幕出币密度另由 visualMultiplier（视觉倍率）决定，只影响画面。
class CoinEngine {
  CoinEngine({
    required this.monthlySalary,
    this.workDaysPerMonth = 22,
    this.hoursPerDay = 8,
    this.visualMultiplier = 100,
  });

  final double monthlySalary; // 月薪
  final int workDaysPerMonth; // 每月工作日，默认 22
  final double hoursPerDay; // 每日工时，由上班/下班时间算出
  final int visualMultiplier; // 显示层视觉倍率（只影响画面，不影响账本）

  /// 由「上班时间 / 下班时间」（自 0 点起的分钟数）算出每日工时（小时）
  static double hoursFromClock({
    required int startMinutes,
    required int endMinutes,
  }) {
    var diff = endMinutes - startMinutes;
    if (diff <= 0) diff += 24 * 60; // 跨天（夜班）
    return diff / 60.0;
  }

  /// 时薪（元/小时）
  double get hourlyRate => monthlySalary / (workDaysPerMonth * hoursPerDay);

  /// 每秒入账金币数（账本口径：1 元 = 1 枚）
  double get coinsPerSecond => hourlyRate / 3600;

  /// 屏幕每秒应该爆多少枚金币（= 账本速率 × 视觉倍率，只影响画面）
  double get spawnPerSecond => coinsPerSecond * visualMultiplier;

  /// 一段时长应得的金币（**精确值，保留小数**）。界面按 0.001 精度展示，不提前取整
  double coinsEarned(Duration d) => d.inMilliseconds / 1000 * coinsPerSecond;

  /// 一段时长应得金币（向下取整，需要整数时用）
  int coinsFor(Duration d) => coinsEarned(d).floor();

  /// 换算文案：金币 → 生活购买力（1 枚 = 1 元）
  String purchasingPower(double coins) {
    final yuan = coins;
    if (yuan >= 200) return '≈ 海底捞一顿 🍲';
    if (yuan >= 100) return '≈ 高档日料放题 🍣';
    if (yuan >= 15) return '≈ 奶茶 ${(yuan / 15).toStringAsFixed(1)} 杯 🧋';
    if (yuan >= 5) return '≈ 早餐 ${(yuan / 5).toStringAsFixed(1)} 份 🥟';
    return '≈ 一根辣条的 ${yuan.toStringAsFixed(1)}% 🌶️';
  }
}
```

**先给它写个单元测试**（新手也能写，就是"预期输入→预期输出"）：

```dart
// test/coin_engine_test.dart（节选，完整 7 个用例见仓库里的实际文件）
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_rain/engine/coin_engine.dart';

void main() {
  test('时薪与金币速率计算', () {
    final e = CoinEngine(monthlySalary: 10000, workDaysPerMonth: 22, hoursPerDay: 8);
    expect(e.hourlyRate, closeTo(56.8, 0.1));
    // 账本口径 1 元 = 1 枚 → 干满 1 小时 ≈ 56 枚
    expect(e.coinsFor(const Duration(hours: 1)), closeTo(56, 1));
  });

  test('视觉倍率只改画面，不改账本', () {
    final e = CoinEngine(monthlySalary: 10000, visualMultiplier: 100);
    expect(e.spawnPerSecond, closeTo(e.coinsPerSecond * 100, 1e-9));
  });
}
```

命令行跑：`flutter test`。全绿再往下走。

### 4.2 主页面状态（免打卡四态状态机）

**没有"打卡"按钮**。状态完全由 `Shift.statusAt(now)` 算出：

```dart
enum ShiftPhase { rest, before, working, after } // 休息日 / 上班前 / 搬砖中 / 已收工
```

| 状态 | 界面 | 金币 |
|---|---|---|
| `rest` | 静态首页："今天休息 🛌 / 周末不算钱，好好休息 · 周一 09:00 开爆" + 最近收益列表 | **恒为 0，不入库** |
| `before` | 静态首页："还没到点 ⏰ / 今日 0.000 / 09:00 开爆 · 还有 1h23m" + 最近收益列表 | 不刷新 |
| `working` | 搬砖页：大数字 3 位小数连续跳动 + 距下班倒计时 | 每秒刷新 |
| `after` | 静态首页："今日已收工 ✅ / 今日全天工资" + 「查看今日战报」 | 定格 |

**周末不算钱（v1.3.1 补强）**——判断顺序在 `statusAt()` 里很关键：

```dart
ShiftStatus statusAt(DateTime now) {
  // ① 先看昨天开的班是否还没结束（跨天夜班：周五 22:00 → 周六 06:00 仍算在班）
  //    前提是"昨天"本身是工作日，否则周六开的夜班不算
  // ② 今天不是工作日（周六/周日）→ ShiftPhase.rest，不算钱、不刷新、不入库
  // ③ 再判断今天的 before / working / after
}
```

⚠️ **踩过的坑**：一开始只在"补齐历史"里做了工作日判断，"当天"漏了 —— 结果周六下午打开 App 会显示"搬砖中"金币狂涨，过了 18:00 还会**自动入库一笔周六的全勤工资**。修法是让 `statusAt()` 在源头就返回 `rest`（`_bankDay()` 里另加一道 `isWorkday` 双保险）。

心跳策略（省电 + 即时响应兼顾）：

```dart
void _syncTimer() {
  final period = _phase == ShiftPhase.working
      ? const Duration(seconds: 1)   // 搬砖中：每秒刷新
      : const Duration(seconds: 15); // 其余：低频检查状态切换（到点自动开始/收工）
  ...
}
// 另外用 WidgetsBindingObserver：回前台时立刻 _tick() 重算一次
// （后台期间系统会挂起 Timer，不能只依赖周期任务）
```

**关键规则（PRD v1.3）**：金币数**不要**用"前台累计了多少秒"来算，而是**始终由 `今天的上班时间 → 现在` 推算**——切后台、被杀掉、重启、隔几天再打开，数字都自动对得上。摸鱼期间照算，回前台只弹一条"你摸鱼了 X 分钟"的调侃提示（**不扣金币**）。

**展示精度**：金额用 `double` 算、按 **0.001（3 位小数）** 展示（如 `0.126`）。账本速率虽然只有 ≈0.016 枚/秒，但 3 位小数能让数字**每秒连续跳动**，不会像整数那样几十秒才 +1、看起来像卡死。

**自动收工入库**：状态从 `working` 切到 `after` 时，自动把当天战报写进金库（`_bankDay()`），不需要点任何按钮。

**自动补齐历史**：启动时从「首次使用日」遍历到昨天，**每个工作日（周一~周五）**补一条全勤战报（`autoSettled: true`）。周末不补。这样金库里"过往每天赚了多少"永远完整，而用户不需要记得打开 App。

**改设置后重算今天**：若今天已入库，改完设置先 `removeReport(今天)` 再按新设置重新入库；历史记录保持不动。

### 4.3 本地存储

```dart
// lib/store/local_store.dart —— 实际代码见仓库（M1.5 已落地）
// 存三样东西：
//   1. app_settings    用户设置（月薪 / 上下班时间 / 工作日 / 视觉倍率）→ 重开 App 不用重新填
//   2. first_use_day   首次使用日 → 金库"自动补齐历史"的起点
//   3. daily_reports   历史战报列表 → **金库总额 = 所有战报金额之和**（不单独存总额，天然防重复计数）
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static const kSettings = 'app_settings';
  static const kFirstUseDay = 'first_use_day';
  static const kReports = 'daily_reports';

  Future<AppSettings> loadSettings() async { /* ... */ }
  Future<void> saveSettings(AppSettings s) async { /* ... */ }

  // ── 首次使用日（补造起点）──────────────────────────────
  Future<DateTime?> loadFirstUseDay() async { /* ... */ }
  Future<void> saveFirstUseDay(DateTime d) async { /* ... */ }

  // ── 历史战报（金库账目）────────────────────────────────
  Future<List<DailyReport>> loadReports() async { /* 新的在前 */ }

  /// 入账一条战报。**同一天只记一次**，已存在则返回 false。
  Future<bool> addReport(DailyReport r) async { /* ... */ }

  /// 批量入账（自动补齐历史时用，一次读写）。返回真正新增的条数。
  Future<int> addReports(List<DailyReport> items) async { /* ... */ }

  /// 删掉某一天的战报（改了设置后重算今天用）
  Future<void> removeReport(DateTime day) async { /* ... */ }
}
```

**M1.5 验收标准**（已在 Redmi K30 5G / Android 12 真机逐条验证）：
1. 早上 7:30 打开（工作日）→ 首页显示"还没到点 ⏰ / 今日 0.000 / 09:00 开爆 · 还有 1h30m"，**本地存储里没有当天战报**（不该入账）
2. 上班时间段内打开（工作日）→ 直接进搬砖页，大数字每秒跳动（隔 3 秒截两张图，只有数字区域像素在变）
3. 晚上 21:20 打开（工作日、已过 18:00）→ 首页"今日已收工 ✅ / 454.545 元"，**本地存储自动写入当天战报**（`workedSeconds=32400`、`autoSettled=false`）
4. **周日 21:40 打开 → 首页"今天休息 🛌 / 今日 0.000"，本地存储只有 `first_use_day`、没有任何战报**（周末不算钱）
5. 全程日志无 `RenderFlex overflowed` 等布局错误

> 注（2026-10-11 实测修正）：**`adb install` 不需要操作手机**——锁屏/亮屏、覆盖装/全新装四种组合全部直接成功。偶发失败（`INSTALL_FAILED_USER_RESTRICTED: Install canceled by user`）才走兜底：`adb shell input keyevent KEYCODE_WAKEUP` + `input keyevent 82` + `input swipe 540 1800 540 600` 解锁后重试。相关开关 `adb_install_need_confirm=0`、`verifier_verify_adb_installs=0`、`install_non_market_apps=1` 均已是"不打扰"状态。

---

## 5. M2：金币爆屏动画

> 目标：把"数字在涨"变成"金币哗哗爆满屏"。这是整个 App 的灵魂，值得花最多时间。

### 5.1 渲染方案选型

| 方案 | 说明 | 结论 |
|---|---|---|
| Flutter 内置动画 Widget | TweenAnimationBuilder 等 | 做几个金币行，做不了几百粒子 |
| **CustomPainter + AnimationController** | 每帧自绘所有粒子 | ✅ 性能好、完全可控，本手册采用 |
| flame 游戏引擎 | 完整 2D 引擎 | P1 想加复杂物理再迁移 |

### 5.2 金币素材

- 先用免费素材：https://opengameart.org / https://kenney.nl 搜 "coin"
- 需要**同一枚金币的 3~4 个旋转角度帧**（正面→侧面→背面→侧面），命名 `coin_0.png ... coin_3.png`，放入 `assets/images/`
- 想更华丽：用 AI 生图工具生成一套透明背景金币旋转序列（4~8 帧更顺滑）

### 5.3 粒子系统核心代码（可直接使用的骨架）

```dart
// lib/render/coin_field.dart
import 'dart:math';
import 'package:flutter/material.dart';

class Coin {
  Coin(this.x, this.y, this.vx, this.vy, this.size, this.frame);
  double x, y, vx, vy, size;
  int frame;      // 当前精灵帧
  double spin = 0; // 帧推进计时
  bool landed = false;
}

class CoinField extends StatefulWidget {
  const CoinField({super.key, required this.spawnPerSecond});
  final double spawnPerSecond; // 由 CoinEngine 提供
  @override
  State<CoinField> createState() => _CoinFieldState();
}

class _CoinFieldState extends State<CoinField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  final List<Coin> _coins = [];
  final Random _rng = Random();
  final List<ui.Image> _frames = [];

  static const maxCoins = 300; // 粒子硬上限：保命，防止越爆越卡

  @override
  void initState() {
    super.initState();
    _loadSprites();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_update)   // 每帧回调
     ..repeat();              // 60fps 持续跑
  }

  Future<void> _loadSprites() async {
    for (var i = 0; i < 4; i++) {
      final data = await rootBundle.load('assets/images/coin_$i.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      _frames.add((await codec.getNextFrame()).image);
    }
    setState(() {});
  }

  double _spawnAcc = 0;
  void _update() {
    final dt = 1 / 60;
    // 1. 按速率生成新金币
    _spawnAcc += widget.spawnPerSecond * dt;
    while (_spawnAcc >= 1 && _coins.length < maxCoins) {
      _spawnAcc -= 1;
      _coins.add(Coin(
        _rng.nextDouble() * 400,           // x：后期改为屏幕实际宽度
        -40,                               // 从屏幕顶外掉入
        (_rng.nextDouble() - 0.5) * 60,    // vx：随机水平漂移
        150 + _rng.nextDouble() * 120,     // vy：下落初速 px/s
        28 + _rng.nextDouble() * 14,       // 尺寸随机
        _rng.nextInt(4),
      ));
    }
    // 2. 物理推进：重力 + 落地堆积
    for (final c in _coins) {
      if (c.landed) continue;
      c.vy += 900 * dt;                    // 重力
      c.x += c.vx * dt;
      c.y += c.vy * dt;
      c.spin += dt * 12;
      if (c.spin > 1) { c.spin = 0; c.frame = (c.frame + 1) % 4; }
      final floor = 600 - 20;              // 后期改为屏幕高度 - 金堆高度
      if (c.y >= floor) {                  // 落地：弹跳两次后堆积
        c.y = floor;
        if (c.vy > 200) { c.vy = -c.vy * 0.4; }  // 弹跳衰减
        else { c.landed = true; }
      }
    }
    // 3. 堆满了就移除最老的（金山不无限涨）
    while (_coins.length > maxCoins) {
      _coins.removeAt(0);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CoinPainter(_coins, _frames),
        size: Size.infinite,
      ),
    );
  }

  @override
  void dispose() { _ctl.dispose(); super.dispose(); }
}

class _CoinPainter extends CustomPainter {
  _CoinPainter(this.coins, this.frames);
  final List<Coin> coins;
  final List<ui.Image> frames;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (final c in coins) {
      if (frames.isEmpty) { // 素材没加载完时的占位画法
        canvas.drawCircle(Offset(c.x, c.y), c.size / 2, Paint()..color = const Color(0xFFFFD700));
        continue;
      }
      final img = frames[c.frame];
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromCenter(center: Offset(c.x, c.y), width: c.size, height: c.size),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CoinPainter old) => true;
}
```

上面是**能跑的骨架**，接进 RainPage：

```dart
// lib/pages/rain_page.dart 核心结构
Scaffold(
  backgroundColor: Colors.black87,
  body: Stack(
    children: [
      // 注意：这里传的是引擎的「屏幕出币速率」（账本速率 × 视觉倍率），不是账本速率
      Positioned.fill(child: CoinField(spawnPerSecond: engine.spawnPerSecond)),
      // 顶部悬浮：今日金币大数字 + "+1"飘字
      // 底部悬浮：金堆渐显 + "摸鱼中..."状态条
    ],
  ),
)
```

### 5.4 从"能跑"到"华丽"的增强清单（按性价比排序）

1. **+1 飘字**：金币爆出瞬间在爆点冒一个金色 "+1" 上浮淡出（5 行代码，爽感 ×2）
2. **屏幕底部金堆**：金币落地后不完全消失，`landed` 的留在底部，视觉上"越干越富"
3. **闪光**：新金币爆出瞬间画一个白色径向渐变光晕，一帧即逝
4. **触觉反馈**：每枚金币爆出 `HapticFeedback.lightImpact()`（限频：最多 5 次/秒，否则手麻）
5. **金币瀑布**：每 60 秒或整点，`spawnPerSecond` 临时 ×20 持续 3 秒
6. **音效**（可选）：`audioplayers` 包播放 coin.wav，注意加静音开关
7. **帧率保护**：真机开 DevTools 性能面板，掉帧就降 `maxCoins`；提供"省电模式"（30fps + maxCoins=150）

### 5.5 M2 验收标准

真机连续爆金币 10 分钟：帧率 ≥ 50fps、手机不发烫得离谱、返回打卡页不崩溃、切后台再回来金币数没乱。

---

## 6. M3：战报与金库

### 6.1 战报页（情绪价值最高点）

```
过了下班时间（自动触发，无需操作）
  └► 全屏黑金结算页，依次动画：
     1. 数字滚动（0 → 454.545，1.5 秒，缓动 easeOut）
     2. 金币瀑布庆祝 3 秒
     3. 换算文案淡入："≈ 奶茶 30.3 杯 🧋"
     4. 统计行：搬砖时长 9h00m
     5. 战报**已自动入库**（v1.3 起不需要"收进金库"按钮）
```

数字滚动用 `TweenAnimationBuilder<double>`：

```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0, end: report.coins.toDouble()),
  duration: const Duration(milliseconds: 1500),
  curve: Curves.easeOutCubic,
  builder: (_, v, __) => Text(
    _fmt.format(v.round()),
    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900,
        color: Color(0xFFFFD700)),
  ),
)
```

### 6.2 战报文案引擎

```dart
// lib/engine/report_generator.dart
class ReportGenerator {
  static const _openers = [
    '今日血汗钱已可视化 ✅',
    '恭喜存活一天，收益到账 🎉',
    '搬砖结束，金币入库 💰',
  ];
  static const _closers = [
    '明天继续爆，打工人！',
    '离财富自由还差亿点点。',
    '老板的库里南，有你一枚螺丝钉的贡献。',
  ];
  // 传种子随机，保证同一天看到同一句
}
```

### 6.3 金库页

- 大字：累计总额（**= 所有历史战报金额之和**，不单独存总额，天然防重复计数）
- 换算：`CoinEngine.purchasingPower(total)`
- 历史战报列表：日期 / 时长 / 金额（补结算的日子打「补结算」标记）
- P1 预留：皮肤解锁入口（现在放个"敬请期待"）

---

## 7. M4：打磨与打包安装

### 7.1 打 Release APK

```powershell
# 环境变量（本机路径，见 04-M0-Env-Setup.md）
$env:JAVA_HOME='D:\Android\jdk-21'; $env:ANDROID_HOME='D:\Android\Sdk'; $env:ANDROID_SDK_ROOT='D:\Android\Sdk'
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'; $env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'

flutter build apk --release                 # 通用包（含三种 ABI）
flutter build apk --release --split-per-abi # 按 CPU 架构分包
```

**实测结果**：通用包 47.9MB；分包 armeabi-v7a 14.4MB / **arm64-v8a 16.9MB** / x86_64 18.3MB。发朋友首选 **arm64** 包（近 5 年手机都是 arm64），微信传得快。

产物在 `build\app\outputs\flutter-apk\`；分发副本统一放工作区 `1_apk_files\`。

> **签名**：release 用的是 Flutter 测试签名（`build.gradle.kts` 里 `signingConfig = signingConfigs.getByName("debug")`），侧载自用足够；对方装的时候要允许"未知来源"。微信有时把 `.apk` 改名成 `.apk.1`，让对方删掉尾部 `.1` 再装。

### 7.2 App 名称与图标

- 名称：`android/app/src/main/AndroidManifest.xml` 里 `android:label="搬砖爆金币"`（UTF-8 直写中文没问题）
- 图标：**没用 flutter_launcher_icons**，改为脚本方案（可复用）：
  - 主图 `assets/icon/app_icon.png`（1024×1024）
  - `assets/icon/make_icons.py` 用 Pillow 生成 5 档并覆盖 `android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`（48/72/96/144/192）
  - 脚本还会**去掉 AI 生图右下角的「AI生成」水印**（把左下干净区块水平镜像贴过去）
  - 依赖托管 venv 里的 Pillow：`C:\Users\MECHREVO\.workbuddy\binaries\python\envs\default\Scripts\python.exe`
  - 换图标流程：替换 `app_icon.png` → 跑脚本 → 重新 build

### 7.3 上架与 iOS（暂缓，先自用）

| 事项 | 说明 |
|---|---|
| 安卓各商店 | 需软著或备案，个人可上但流程数周，**MVP 阶段不做**，APK 自用+朋友侧载 |
| iOS | 需 Apple 开发者账号 ¥688/年；自用可走 Xcode 直装（7 天有效期）或 TestFlight，先不做 |

---

## 8. 测试清单

**逻辑测试（自动化，`flutter test`）：**
- [ ] CoinEngine：时薪、金币数、换算文案边界（0 金币、超大数）
- [ ] 视觉倍率：调倍率只改屏幕出币密度，账本数字分毫不变
- [ ] 金额精度：60 秒 ≈ 0.947 枚（3 位小数展示），不提前取整
- [ ] 上下班时间换算：09:00-18:00 = 9h、跨天夜班 22:00-06:00 = 8h
- [ ] **Shift 四态**：上班前 / 上班瞬间 / 搬砖中 / 下班瞬间 / 下班后 各边界正确
- [ ] **Shift 跨天夜班**：22:00-06:00 凌晨 02:00 算"搬砖中"且归属日为前一天
- [ ] **Shift.isWorkday**：周一~周五 true，周六周日 false
- [ ] **周末不算钱**：周六/周日全天都返回 `rest` 且 `worked = 0`；`workdaysOnly:false` 时周末照常上班
- [ ] **夜班 × 周末边界**：周五夜班跨到周六凌晨仍算 `working`；周六夜班（前一天非工作日）不算

**真机手工测试：**
- [ ] 上班前打开：显示"还没到点"，本地存储**不生成**当天战报
- [ ] 搬砖中打开：数字每秒跳动（可隔 3 秒截两张图做像素差分验证）
- [ ] 已过下班时间打开：显示"今日已收工"，本地存储**自动生成**当天战报
- [ ] 周末打开：显示"今天休息"，本地存储**不生成**任何战报
- [ ] 设置月薪/上下班时间后杀进程重开，设置还在（参数持久化）
- [ ] 爆金币 10 分钟：帧率、发热、粒子数上限生效
- [ ] 卸载重装：数据清零，不崩溃
- [ ] 息屏 30 分钟再回来：提示"你摸鱼了 30 分钟"，且金币照给不扣

---

## 9. 常见坑速查表

| 症状 | 原因/解法 |
|---|---|
| `flutter doctor` 红叉 android licenses | `flutter doctor --android-licenses` 全输 y |
| 真机运行检测不到手机 | 数据线是充电线（换线）；开发者模式 USB 调试没开；手机弹窗没点允许 |
| 中文路径报错 | Flutter 项目和 SDK 都不能放中文/空格路径 |
| `pub get` 卡住 | 换国内镜像：PowerShell 执行 `$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"; $env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"` 后重试 |
| 图片不显示 | pubspec.yaml 缩进必须严格 2 空格；assets 路径写的是文件夹要带尾部 `/` |
| 动画越跑越卡 | 粒子上限没生效/落地金币没回收；检查 `maxCoins` 与移除逻辑 |
| 热重载后状态错乱 | 涉及 initState 的改动要热**重启**（Shift+F5 后再 F5），不是热重载 |
| 真机安装失败 | 手机开了"纯净模式"（小米等品牌），去设置关掉安装拦截 |
| 小米/红米报 `INSTALL_FAILED_USER_RESTRICTED` | 开发者选项里打开「USB 调试（安全设置）」（需登录小米账号 + 插 SIM 卡），否则 `flutter run` 装不上 App |
| 小米手机 `adb devices` 一直为空 | 小米锁屏会切断 USB 数据连接：保持手机解锁亮屏，再拔插一次数据线 |
| 偶发 `INSTALL_FAILED_USER_RESTRICTED: Install canceled by user` | **不是锁屏导致的**（已用 4 组对照实验排除）。直接重试通常就好；仍失败则 `adb shell input keyevent KEYCODE_WAKEUP` + `input keyevent 82` + `input swipe 540 1800 540 600` 解锁后再装 |
| `run-as: package not debuggable` | release 包不可调试，读不到 `shared_prefs`。要验证数据就临时装 debug 包 |
| `adb install` 报 `INSTALL_FAILED_VERSION_DOWNGRADE` | 分包版本号 = `versionCode + 1000×ABI`（arm64 会到 2001），比 debug 包(1)大。装 debug 时先 `adb uninstall` 或加 `-d` |
| **手写 `FlutterSharedPreferences.xml` 被系统重置** | 文件不能带 UTF-8 **BOM**（`Get-Content -Raw` 写出来会带），否则 SharedPreferences 解析失败 → 整个文件被清空。要改测试数据就用 `-AsByteStream`，或干脆改代码里的默认值重新构建 |
| 加了插件后构建报 `Could not close incremental caches` | `android/gradle.properties` 加 `kotlin.incremental=false` + 清 `build/` |

---

## 10. P1 功能实现指引

- **摸鱼提示**：`WidgetsBindingObserver.didChangeAppLifecycleState` 监听前后台切换，记录 `paused` 时刻；回前台时算差值 → 弹"你摸鱼了 X 分钟"横幅。**金币照给、不扣**（金币本来就按上班时间推算），只做调侃提醒
- **整点金币雨**：`Stream.periodic(1s)` 里判断 `DateTime.now().minute == 0` 触发 3 秒高速喷发
- **皮肤系统**：把 `_frames` 换成皮肤包（皮肤 = 4 帧精灵图 + 主题色 + 名称），金币余额达到阈值解锁，存 `shared_preferences`
- **历史记录**：`daily_report` 列表存 SQLite（用 `drift` 或 `sqflite` 包），金库页加日历热力图
- **桌面小组件**：`home_widget` 包，显示今日金币数（安卓支持好，iOS 受限）

---

## 附：每周节奏建议（业余开发者）

- **工作日晚上 1 小时**：只做小任务（写一个函数、调一个样式、跑一次测试）
- **周末大块时间**：攻坚（粒子系统、战报动画这种需要进入心流的）
- **每次收工前**：`git add . && git commit -m "..."` 提交一版。命令不会就用 VS Code 左侧源代码管理面板点按钮。**每周至少一次提交，这是你唯一的后悔药**

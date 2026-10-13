# M0 环境搭建 · 完成记录

> 状态：**✅ 已完成**（2026-10-11）
> 对应 `02-Dev-Manual.md` 第 2 章。本文记录**实际执行的操作**与踩坑，供后续排障与换机复现。

---

## 1. 最终安装清单

| 组件 | 版本 | 安装位置 |
|---|---|---|
| Flutter SDK | **3.47.7 stable**（Dart 3.13.5） | `D:\flutter` |
| JDK | **Microsoft OpenJDK 21.0.12.1** | `D:\Android\jdk-21` |
| Android cmdline-tools | 16111833 | `D:\Android\Sdk\cmdline-tools\latest` |
| Android SDK Platform | **android-36** | `D:\Android\Sdk\platforms\android-36` |
| Android Build-Tools | **36.0.0** | `D:\Android\Sdk\build-tools\36.0.0` |
| Android Platform-Tools | r37.0.1（含 adb） | `D:\Android\Sdk\platform-tools` |
| Android NDK | **28.2.13676358** | `D:\Android\Sdk\ndk\28.2.13676358` |
| Gradle（构建时自动下载） | 9.3.1（走腾讯镜像） | `%USERPROFILE%\.gradle` |

> ⚠️ **没有装 Android Studio**。本项目用 VS Code 写代码 + 真机调试，不需要 Android Studio 的 IDE 和模拟器，因此改用「命令行工具 + 独立 JDK」，省了 5~8 GB 磁盘和一堆手动点击。

**Flutter 模板的 Android 基准**（来自 `FlutterExtension.kt`）：compileSdk **36** / targetSdk **36** / minSdk **24**。

---

## 2. 已写入的环境变量（用户级，永久生效）

| 变量 | 值 |
|---|---|
| `Path`（追加） | `D:\flutter\bin`、`D:\Android\jdk-21\bin`、`D:\Android\Sdk\platform-tools`、`D:\Android\Sdk\cmdline-tools\latest\bin` |
| `JAVA_HOME` | `D:\Android\jdk-21` |
| `ANDROID_HOME` | `D:\Android\Sdk` |
| `ANDROID_SDK_ROOT` | `D:\Android\Sdk` |
| `PUB_HOSTED_URL` | `https://pub.flutter-io.cn` |
| `FLUTTER_STORAGE_BASE_URL` | `https://storage.flutter-io.cn` |

**注意**：环境变量只对**新开的**终端生效。装完后已有的终端窗口需要关掉重开。

---

## 3. 验证结果（全部通过）

| 检查项 | 结果 |
|---|---|
| `flutter --version` | Flutter 3.47.7 / Dart 3.13.5 ✅ |
| `flutter doctor` | Android toolchain ✅（Android SDK 36.0.0） |
| `flutter test` | 5 个用例全过 ✅ |
| `flutter analyze` | No issues found ✅ |
| `flutter build apk --debug` | 构建成功，产物 143 MB ✅ |

**产物路径**：`gold_rain\build\app\outputs\flutter-apk\app-debug.apk`

> `flutter doctor` 里剩下的两项提示可忽略：
> - `Visual Studio` —— 只在做 Windows 桌面程序时需要，本项目不需要
> - `Network resources` 的 GitHub 超时 —— 国内网络正常现象，不影响构建（已用国内镜像）

---

## 4. 踩坑记录（换机复现时照做）

### 坑 1：新版 Android CLI 的包名用 `/`，不是 `;`
`cmdline-tools 16111833` 里 `sdkmanager` 已被标记为废弃，实际转发给新的 Android CLI。安装包时必须用**正斜杠**：
```powershell
# ❌ 旧写法（会被拆成两个包名而报错）
sdkmanager "platforms;android-36"
# ✅ 新写法
sdkmanager "platforms/android-36" "build-tools/36.0.0"
```

### 坑 2：NDK 必须手动装
AGP 的自动下载 NDK 功能在新 CLI 下失效，报错：
`Android sdkmanager did not install NDK 28.2.13676358`。
解法（Flutter 3.47 模板锁定该版本）：
```powershell
sdkmanager "ndk/28.2.13676358"
```

### 坑 3：Gradle 从国外拉太慢
`android/gradle/wrapper/gradle-wrapper.properties` 的 `distributionUrl` 已改成腾讯镜像：
```
distributionUrl=https\://mirrors.cloud.tencent.com/gradle/gradle-9.3.1-all.zip
```

### 坑 4：`Colors.grey.shadeXXX` 不能用在 `const` 里
M0 demo 代码从未编译过，首次编译暴露：
```dart
// ❌ 编译错误：Not a constant expression
const Text('...', style: TextStyle(color: Colors.grey.shade400))
// ✅ 去掉 const 即可
Text('...', style: TextStyle(color: Colors.grey.shade400))
```
已修复 `lib/main.dart` 两处（搬砖中 / 明天继续爆）。

### 坑 5：`flutter create` 会生成用不上的模板测试
它会生成 `test/widget_test.dart`（测默认计数器 App），与项目代码不匹配会导致 `flutter test` 失败。**已删除**。

### 坑 6：C 盘空间
搭建过程 C 盘从 35.7 GB → 24.7 GB（Gradle 缓存 + pub 缓存占的）。后续若紧张，可把 `GRADLE_USER_HOME` 指到 D 盘。

---

## 5. 日常开发命令（新开终端直接可用）

```powershell
cd "E:\0_CodeProject\12_GoldRainApp\gold_rain"

flutter run                 # 真机调试（热重载）
flutter test                # 跑单元测试
flutter analyze             # 静态检查
# 打正式包（v3.4 起加了产品风味，必须带 --flavor prod，否则 Gradle 变体不明确）
flutter build apk --flavor prod --release --split-per-abi --obfuscate --split-debug-info=build/symbols
# 打演示/调试包（独立包名 com.example.gold_rain.demo，可与正式版并排安装、数据隔离）
flutter build apk --flavor demo --release --split-per-abi --obfuscate --split-debug-info=build/symbols
```
产物路径带风味名：`build/app/outputs/flutter-apk/app-arm64-v8a-prod-release.apk` / `app-arm64-v8a-demo-release.apk`。

**⚠️ 首次安装「演示版」需手机一次确认**：MIUI 对**全新包名**的安装（纯净模式）会拦截，`adb install` 报 `INSTALL_FAILED_USER_RESTRICTED: Install canceled by user`（正式版因为是替换同包名，可静默直装）。二选一放行一次即可：
1. 开发者选项 → 打开「**USB 安装**（通过 USB 安装应用）」，再重试；
2. 或在手机上直接点开 APK 手动安装并允许一次。
放行后同一个 demo 包后续 `adb install -r` 也能静默直装。

**真机首次运行**：手机连点 7 次"版本号"开开发者模式 → 打开 USB 调试 → 数据线连电脑 → 手机弹窗点"允许" → `flutter devices` 确认能看到手机 → `flutter run`。

**发版安装（MIUI 已根治，一条命令直装，无需操作手机）**：
```powershell
adb install -r "E:\0_CodeProject\12_GoldRainApp\1_apk_files\搬砖爆金币-vX.Y.Z-arm64版-推荐.apk"
adb shell am start -n com.example.gold_rain/.MainActivity   # 装完直接拉起验证
```

---

## 6. M0 验收对照

- [x] Flutter SDK 安装完成
- [x] Android 工具链就绪（doctor 关键项全绿）
- [x] `flutter test` 5 个用例全过
- [x] `flutter analyze` 无问题
- [x] APK 构建成功（构建链路完整验证）
- [ ] 真机上跑通 demo（**待用户插手机验证**）

> 前 5 项已完成。最后一项需要你把安卓手机用数据线连上电脑，然后执行 `flutter run`。

---

## 7. MIUI 真机安装通道（adb 直装 · v0.6.0 根治 · 2026-10-12）

> 现状：**已根治**。以后发版 `adb install -r` 一条命令直装，**不需要用户再操作手机**（不弹窗、不按指纹）。本节是排查记录 + 备用兜底方案。

### 7.1 症状（根治前）

- `adb install` / `pm install -r` / `INSTALL_PACKAGE` intent 一律报 `INSTALL_FAILED_USER_RESTRICTED`，Toast「Shell 没有权限安装」
- 开发者选项「USB 安装」已开（`adb_install_need_confirm=0`）、未知来源已开（`install_non_market_apps=1`）、`appops set com.android.shell REQUEST_INSTALL_PACKAGES allow` 全部做了仍被拦
- 走「文件管理器」路径能装，但**每次首次安装都要按指纹**，且白名单记录装完即被系统清空

### 7.2 根因

MIUI 13 的「增强安全模式」在 `com.miui.packageinstaller` 内部做强制来源校验，**绕过了 AOSP 标准通道**（`adb_install_need_confirm` / `REQUEST_INSTALL_PACKAGES`），所以开发者选项的开关看着开了实际无效。三个关键开关：

| 设置键（secure） | 拦截值 → 已改 | 含义 |
|---|---|---|
| `miui_security_mode_style` | `enhance` → `basic` | 增强安全模式 |
| `miui_safe_mode` | `1` → `0` | 安全模式 |
| `installer_full_safe_version` | `1`（未动） | 完整安全版本，够用即可不必动 |

### 7.3 根治命令（一次性，已执行）

```powershell
adb shell settings put secure miui_security_mode_style basic
adb shell settings put secure miui_safe_mode 0
# 读回确认：
adb shell settings get secure miui_security_mode_style   # 应输出 basic
adb shell settings get secure miui_safe_mode             # 应输出 0
```

手机侧可回退：设置 → 密码与安全 → 系统安全 → 增强安全模式（嫌不安全随时开回来，但会退回弹指纹状态）。

### 7.4 验证

- `adb install -r` 直接 `Success`，无弹窗、无指纹
- `dumpsys package` 确认 `versionName` 正确，`am start` 拉起 App 正常

### 7.5 备用兜底（若增强安全模式被重开 / 换机未关）

文件管理器路径全自动安装（MIUI 拦 adb 时的唯一通道）：

```powershell
# 1) 推 APK 到手机 Download
adb push "1_apk_files\xxx.apk" /sdcard/Download/
# 2) 打开文件管理器并定位到 APK（MIUI 的 FileExplorerTabActivity）
adb shell am start -n com.android.fileexplorer/.FileExplorerTabActivity
adb shell uiautomator dump /sdcard/ui.xml && adb shell cat /sdcard/ui.xml   # 找 APK 文本 bounds
adb shell input tap <x> <y>
# 3) 首次会弹「安全验证」→ 需用户按一次指纹；确认后该来源本次放行
```

> 该白名单记录（`com.miui.packageinstaller_install_not_allow_package_<pkg>`）是**一次性**的，装完即清空，所以每次都弹指纹——根治后不再依赖此通道。

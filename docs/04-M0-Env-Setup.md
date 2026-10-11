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
flutter build apk --release # 打正式包（约 20 MB）
```

**真机首次运行**：手机连点 7 次"版本号"开开发者模式 → 打开 USB 调试 → 数据线连电脑 → 手机弹窗点"允许" → `flutter devices` 确认能看到手机 → `flutter run`。

---

## 6. M0 验收对照

- [x] Flutter SDK 安装完成
- [x] Android 工具链就绪（doctor 关键项全绿）
- [x] `flutter test` 5 个用例全过
- [x] `flutter analyze` 无问题
- [x] APK 构建成功（构建链路完整验证）
- [ ] 真机上跑通 demo（**待用户插手机验证**）

> 前 5 项已完成。最后一项需要你把安卓手机用数据线连上电脑，然后执行 `flutter run`。

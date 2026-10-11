# 搬砖爆金币 · gold_rain（M0 demo）

> 配套文档：`../docs/01-PRD.md`（产品定义）+ `../docs/02-Dev-Manual.md`（开发手册）

这个文件夹里已经写好的东西：

```
gold_rain/
├── lib/
│   ├── main.dart                 # M0 demo：打卡→金币实时涨→迷你战报，黑金视觉
│   └── engine/
│       └── coin_engine.dart      # 金币数值引擎（提前把 M1 核心逻辑写好了）
├── test/
│   └── coin_engine_test.dart     # 引擎单元测试（5 个用例）
├── pubspec.yaml                  # 项目依赖声明
├── analysis_options.yaml         # 代码规范
└── .gitignore
```

## demo 里能玩到什么

1. **上班打卡** → 进入"搬砖中"画面，金币大数字按真实公式实时上涨（默认月薪 10000 → 约 1.58 枚/秒）
2. **下班打卡** → 迷你"今日战报"：数字滚动动画 + 奶茶/海底捞购买力换算吐槽
3. 打卡有振动反馈，土豪金 + 深色背景的视觉基调已立住

> 金币爆屏粒子动画（灵魂部分）是 M2 里程碑的内容，这个 demo 先把数字闭环跑通。

## 怎么跑起来（3 步）

⚠️ 前提：电脑上还没装 Flutter。先按开发手册第 2 章装好 Flutter + Android Studio，
`flutter doctor` 全绿后再回来。

```powershell
# 1. 进入本文件夹（gold_rain），把下面的路径换成你的实际路径
cd "E:\0_CodeProject\12_GoldRainApp\gold_rain"

# 2. 生成安卓等平台文件夹（lib/ 里已写好的代码会原样保留）
flutter create .

# 3. 插上手机（开 USB 调试），运行
flutter run
```

跑单元测试：

```powershell
flutter test
```

## ⚠️ 中文路径问题（处理进展）

开发手册明确说过 **Flutter 项目不要放中文路径**。处理进展：

- ✅ 工作区内部已全部英文化：文档文件夹 `爆金币App` → `docs`，两个 md 已改名
  `01-PRD.md` / `02-Dev-Manual.md`；项目文件夹本来就叫 `gold_rain`
- ⏳ **根目录 `12_上班爆金币App` → `12_GoldRainApp` 需要手动改**：
  它是 WorkBuddy 的活动工作区，程序锁着它，会话内改不了。
  做法见 README 底部"根目录改名步骤"。

## 根目录改名步骤（一次性，10 秒）

1. 完全关闭 WorkBuddy（托盘图标也退出）
2. 打开文件资源管理器 → `E:\0_CodeProject`
3. 右键 `12_上班爆金币App` → 重命名 → 输入 `12_GoldRainApp` → 回车
4. 重新打开 WorkBuddy，打开新路径 `E:\0_CodeProject\12_GoldRainApp` 作为工作区
5. 跟 AI 说一声"改好了"，它会更新剩余引用

## M0 验收标准

- [ ] `flutter doctor` 全绿
- [ ] `flutter test` 5 个用例全过
- [ ] 手机上点"上班打卡"，金币数字每秒在涨
- [ ] 点"下班打卡"，战报数字滚动 + 换算文案出现
- [ ] 返回键退出不崩溃

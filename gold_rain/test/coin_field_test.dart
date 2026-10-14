// CoinField 渲染冒烟测试（M2）：粒子系统能出生、物理推进不崩、无异常。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_rain/render/coin_field.dart';

void main() {
  testWidgets('CoinField 高速率下渲染不报错、金币正常出生', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CoinField(spawnPerSecond: 30),
        ),
      ),
    );
    // 跑 30 帧（30fps × 1 秒），让出生 + 物理推进都走一遍
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    expect(tester.takeException(), isNull);

    // 卸载页面（dispose Ticker），避免测试结束时报 Ticker 泄漏
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('CoinField 极低速率也不报错（写实模式 ×1）', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CoinField(spawnPerSecond: 0.016),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('CoinField 攒够 15 颗自动收仓：触发钱袋吸入并清空', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CoinField(spawnPerSecond: 30),
        ),
      ),
    );
    final state = tester.state<CoinFieldState>(find.byType(CoinField));
    // 高出生率跑 1 秒：屏幕金币超过 15 颗 → 触发收仓
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    expect(state.isCollecting, isTrue, reason: '攒够 15 颗应触发收仓');
    // 收仓动画（最长 1.2s）跑完：清空收集中的金币、收仓结束
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    expect(state.isCollecting, isFalse, reason: '收仓应在 1.2s 内结束');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

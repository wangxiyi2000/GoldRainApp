// 搬砖页大金额「数字恒定居中」回归测试：
// 金额位数变化时，数字块的水平中心必须始终等于屏幕中心（「元」固定在右侧）。
//
// 注意：必须用「手机尺寸」的画布跑，否则宽画布不会触发 Row 溢出，
// 会把「窄屏溢出导致数字整体偏右」的 bug 放过去（这正是真机复现过的问题）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_rain/models/app_settings.dart';
import 'package:gold_rain/pages/rain_page.dart';

Widget _wrap(double coins) => MaterialApp(
      home: Scaffold(
        body: RainPage(
          settings: const AppSettings(),
          coins: coins,
          elapsed: const Duration(minutes: 9),
          eggLevel: 0,
          onEggAdvanced: (_) {},
          onOpenVault: () {},
          onOpenFinance: () {},
          onOpenSettings: () {},
        ),
      ),
    );

/// 模拟真机：1080x2400 @ dpr 2.75（逻辑宽约 392.7）
void _usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

Future<void> _mount(WidgetTester tester, double coins) async {
  _usePhoneSurface(tester);
  await tester.pumpWidget(_wrap(coins));
  // 让金额补间动画（600ms）跑完，取最终稳定值
  await tester.pump(const Duration(milliseconds: 800));
}

void _expectCentered(WidgetTester tester, String text) {
  final amount = find.text(text);
  expect(amount, findsOneWidget);
  expect(tester.takeException(), isNull, reason: '不应有布局溢出等异常');

  final screen = tester.getSize(find.byType(MaterialApp));
  final center = tester.getCenter(amount);
  expect(center.dx, closeTo(screen.width / 2, 1.0),
      reason: '数字中心应等于屏幕中心（不因位数少而偏右）');
}

void main() {
  testWidgets('金额很小（3.116）时数字仍水平居中', (tester) async {
    await _mount(tester, 3.116);
    _expectCentered(tester, '3.116');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('金额较大（1234.567）时数字同样水平居中', (tester) async {
    await _mount(tester, 1234.567);
    _expectCentered(tester, '1,234.567');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('超长金额（123456.789）不溢出且仍居中', (tester) async {
    await _mount(tester, 123456.789);
    _expectCentered(tester, '123,456.789');
    await tester.pumpWidget(const SizedBox());
  });
}

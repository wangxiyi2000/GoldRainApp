// ReportGenerator 单元测试：同一天必须看到同一句文案
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_rain/engine/report_generator.dart';

void main() {
  test('同一天的文案固定不变', () {
    final d = DateTime(2026, 10, 11);
    expect(ReportGenerator.opener(d), ReportGenerator.opener(d));
    expect(ReportGenerator.closer(d), ReportGenerator.closer(d));
  });

  test('文案非空', () {
    final d = DateTime(2026, 10, 11);
    expect(ReportGenerator.opener(d), isNotEmpty);
    expect(ReportGenerator.closer(d), isNotEmpty);
  });

  test('日期种子按年月日生成', () {
    expect(ReportGenerator.seedOf(DateTime(2026, 10, 11)), 20261011);
  });
}

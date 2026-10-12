// 彩蛋档位持久化测试（v0.6.0）：egg_date/egg_level 默认值 + 往返一致性。
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_rain/store/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('彩蛋档位：从未庆祝 → (null, 0)，保存后往返一致', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();

    final (date0, level0) = await store.loadEggState();
    expect(date0, isNull);
    expect(level0, 0);

    await store.saveEggState('2026-10-12', 3);
    final (date1, level1) = await store.loadEggState();
    expect(date1, '2026-10-12');
    expect(level1, 3);
  });

  test('彩蛋档位：覆盖保存（同一天推进档位）', () async {
    SharedPreferences.setMockInitialValues({'egg_date': '2026-10-12', 'egg_level': 1});
    final store = LocalStore();

    await store.saveEggState('2026-10-12', 4);
    final (date, level) = await store.loadEggState();
    expect(date, '2026-10-12');
    expect(level, 4);
  });
}

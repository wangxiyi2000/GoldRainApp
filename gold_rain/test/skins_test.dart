// P1 皮肤系统 + 设置向后兼容测试
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_rain/models/app_settings.dart';
import 'package:gold_rain/render/skins.dart';

void main() {
  test('默认皮肤是金币且永远解锁', () {
    expect(kSkins.first.id, 'gold');
    expect(kGoldSkin.isUnlocked(0), isTrue);
    expect(kGoldSkin.framePaths.length, 4);
  });

  test('皮肤解锁门槛按金库总额判断', () {
    expect(kRedpackSkin.isUnlocked(99), isFalse);
    expect(kRedpackSkin.isUnlocked(100), isTrue);
    expect(kPaycheckSkin.isUnlocked(1999), isFalse);
    expect(kPaycheckSkin.isUnlocked(2000), isTrue);
  });

  test('未知皮肤 id 回退默认金币', () {
    expect(skinById('nope').id, 'gold');
    expect(skinById('redpack').id, 'redpack');
    expect(kSkins.map((s) => s.id).toSet().length, kSkins.length); // id 不重复
  });

  test('旧存档没有新字段时向后兼容', () {
    final old = AppSettings.fromJson({
      'monthlySalary': 10000,
      'workStartMinutes': 540,
      'workEndMinutes': 1080,
      'workDaysPerMonth': 22,
      'visualMultiplier': 100,
    });
    expect(old.soundEnabled, isTrue);
    expect(old.skinId, 'gold');
    expect(old.skin.id, 'gold');
  });

  test('新字段正常持久化往返', () {
    const s = AppSettings(soundEnabled: false, skinId: 'paycheck');
    final back = AppSettings.fromJson(
        Map<String, dynamic>.from(s.toJson().map((k, v) => MapEntry(k, v))));
    expect(back.soundEnabled, isFalse);
    expect(back.skinId, 'paycheck');
  });
}

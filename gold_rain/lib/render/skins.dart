// 皮肤系统（P1）：皮肤 = 4 帧精灵图 + 主题色 + 名称 + 解锁门槛。
// 解锁门槛按「金库总额」算：vaultCoins >= unlockCoins 才可选（0 = 默认解锁）。
// 精灵图由 assets/make_coins.py 程序化生成，换皮肤本质就是换一组图。
import 'package:flutter/material.dart';

import '../theme.dart';

class CoinSkin {
  const CoinSkin({
    required this.id,
    required this.name,
    required this.themeColor,
    required this.unlockCoins,
    required this.framePaths,
  });

  final String id;
  final String name;
  final Color themeColor; // 堆山 / 占位圆 / 飘字用色（默认皮肤=金色）
  final int unlockCoins; // 金库余额达到该值解锁
  final List<String> framePaths; // 4 帧精灵图路径

  bool isUnlocked(double vaultCoins) => vaultCoins >= unlockCoins;
}

const kGoldSkin = CoinSkin(
  id: 'gold',
  name: '金币',
  themeColor: kGold,
  unlockCoins: 0,
  framePaths: [
    'assets/images/coin_0.png',
    'assets/images/coin_1.png',
    'assets/images/coin_2.png',
    'assets/images/coin_3.png',
  ],
);

const kRedpackSkin = CoinSkin(
  id: 'redpack',
  name: '红包',
  themeColor: Color(0xFFFF4D4F),
  unlockCoins: 100,
  framePaths: [
    'assets/skins/redpack/0.png',
    'assets/skins/redpack/1.png',
    'assets/skins/redpack/2.png',
    'assets/skins/redpack/3.png',
  ],
);

const kMilkTeaSkin = CoinSkin(
  id: 'milktea',
  name: '奶茶',
  themeColor: Color(0xFFC68642),
  unlockCoins: 300,
  framePaths: [
    'assets/skins/milktea/0.png',
    'assets/skins/milktea/1.png',
    'assets/skins/milktea/2.png',
    'assets/skins/milktea/3.png',
  ],
);

const kDiamondSkin = CoinSkin(
  id: 'diamond',
  name: '钻石',
  themeColor: Color(0xFF4DD8FF),
  unlockCoins: 800,
  framePaths: [
    'assets/skins/diamond/0.png',
    'assets/skins/diamond/1.png',
    'assets/skins/diamond/2.png',
    'assets/skins/diamond/3.png',
  ],
);

const kPaycheckSkin = CoinSkin(
  id: 'paycheck',
  name: '工资条',
  themeColor: Color(0xFF4CD964),
  unlockCoins: 2000,
  framePaths: [
    'assets/skins/paycheck/0.png',
    'assets/skins/paycheck/1.png',
    'assets/skins/paycheck/2.png',
    'assets/skins/paycheck/3.png',
  ],
);

/// 全部皮肤（顺序即设置页展示顺序）
const kSkins = [
  kGoldSkin,
  kRedpackSkin,
  kMilkTeaSkin,
  kDiamondSkin,
  kPaycheckSkin,
];

/// 按 id 取皮肤，未知 id 回退默认金币
CoinSkin skinById(String id) {
  for (final s in kSkins) {
    if (s.id == id) return s;
  }
  return kGoldSkin;
}

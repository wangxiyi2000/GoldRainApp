// 全局视觉基调与公共小部件（PRD 第 5 节）
import 'package:flutter/material.dart';

const kGold = Color(0xFFFFD700); // 土豪金
const kGoldDark = Color(0xFFB8860B);
const kBg = Color(0xFF121212); // 深色背景

/// 金额格式化：千分位 + 固定 3 位小数（如 1,234.567）
String formatCoins(double v) {
  final s = v.toStringAsFixed(3); // 1234.567
  final dot = s.indexOf('.');
  final intPart = s.substring(0, dot);
  final decPart = s.substring(dot + 1);
  final grouped =
      intPart.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return '$grouped.$decPart';
}

/// 时长格式化：1h23m45s / 23m45s / 45s
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}m';
  if (m > 0) return '${m}m${s.toString().padLeft(2, '0')}s';
  return '${s}s';
}

/// 土豪金按钮
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onTap,
    this.outlined = false,
    this.height = 64,
  });

  final String label;
  final VoidCallback onTap;
  final bool outlined;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: outlined ? Colors.transparent : kGold,
          foregroundColor: outlined ? kGold : Colors.black,
          side: BorderSide(color: kGold, width: outlined ? 2 : 0),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        ),
        child: Text(label),
      ),
    );
  }
}

/// 顶部小标题
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      );
}

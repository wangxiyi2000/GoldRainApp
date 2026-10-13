// 设置页：月薪 / 上班时间 / 下班时间 / 每月工作日 / 视觉倍率 / 音效 / 皮肤。
// 保存后返回新的 AppSettings，由上层写进本地存储。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../render/skins.dart';
import '../theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.initial, required this.vaultCoins});

  final AppSettings initial;
  final double vaultCoins; // 金库总额（皮肤解锁门槛用）

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _salary;
  late int _start;
  late int _end;
  late int _days;
  late int _multiplier;
  late bool _soundOn;
  late String _skinId;

  static const _multipliers = [1, 10, 50, 100];

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _salary = TextEditingController(text: s.monthlySalary.toStringAsFixed(0));
    _start = s.workStartMinutes;
    _end = s.workEndMinutes;
    _days = s.workDaysPerMonth;
    _multiplier = s.visualMultiplier;
    _soundOn = s.soundEnabled;
    _skinId = s.skinId;
  }

  @override
  void dispose() {
    _salary.dispose();
    super.dispose();
  }

  AppSettings get _draft => widget.initial.copyWith(
        monthlySalary: double.tryParse(_salary.text.trim()) ??
            widget.initial.monthlySalary,
        workStartMinutes: _start,
        workEndMinutes: _end,
        workDaysPerMonth: _days,
        visualMultiplier: _multiplier,
        soundEnabled: _soundOn,
        skinId: _skinId,
      );

  Future<void> _pickTime({required bool isStart}) async {
    final cur = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
    );
    if (picked == null) return;
    setState(() {
      final m = picked.hour * 60 + picked.minute;
      if (isStart) {
        _start = m;
      } else {
        _end = m;
      }
    });
  }

  void _save() {
    final s = _draft;
    if (s.monthlySalary <= 0) {
      _toast('月薪要大于 0 哦');
      return;
    }
    if (s.hoursPerDay <= 0) {
      _toast('上班时间和下班时间不能一样');
      return;
    }
    Navigator.of(context).pop(s);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final engine = draft.toEngine();

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: kBg,
        foregroundColor: kGold,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _label('月薪（元）'),
          TextField(
            controller: _salary,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: const TextStyle(color: Colors.white, fontSize: 20),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          _label('上班时间 / 下班时间'),
          Row(
            children: [
              Expanded(
                child: _TimeBox(
                  label: '上班',
                  text: AppSettings.minutesToHm(_start),
                  onTap: () => _pickTime(isStart: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeBox(
                  label: '下班',
                  text: AppSettings.minutesToHm(_end),
                  onTap: () => _pickTime(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '每日工时 ${draft.hoursPerDay.toStringAsFixed(1)} 小时'
            '${_end <= _start ? '（跨天夜班）' : ''}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '到点自动开始积累、到点自动收工入账，不用打卡；周末好好休息',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 20),
          _label('每月工作日'),
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _days = (_days - 1).clamp(1, 31)),
                icon: const Icon(Icons.remove_circle_outline, color: kGold),
              ),
              Text('$_days 天',
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
              IconButton(
                onPressed: () => setState(() => _days = (_days + 1).clamp(1, 31)),
                icon: const Icon(Icons.add_circle_outline, color: kGold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _label('屏幕视觉倍率（只影响画面，不改账本数字）'),
          Wrap(
            spacing: 8,
            children: _multipliers
                .map((m) => ChoiceChip(
                      label: Text('×$m'),
                      selected: _multiplier == m,
                      selectedColor: kGold,
                      labelStyle: TextStyle(
                          color: _multiplier == m ? Colors.black : kGold),
                      onSelected: (_) => setState(() => _multiplier = m),
                    ))
                .toList(),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('算出来的结果',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                const SizedBox(height: 8),
                Text('时薪 ${engine.hourlyRate.toStringAsFixed(2)} 元/小时',
                    style: const TextStyle(color: kGold, fontSize: 16)),
                Text(
                    '账本 ＋${engine.coinsPerSecond.toStringAsFixed(4)} 枚/秒'
                    '（屏幕 ×$_multiplier → 每秒爆 ${engine.spawnPerSecond.toStringAsFixed(1)} 枚）',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _label('音效（金币落地叮 + 爆发唰，可关）'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('金币音效', style: TextStyle(color: Colors.white)),
            subtitle: Text('关掉就是纯视觉爽感',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            value: _soundOn,
            activeTrackColor: kGoldDark,
            activeThumbColor: kGold,
            onChanged: (v) => setState(() => _soundOn = v),
          ),
          const SizedBox(height: 20),
          _label('皮肤（金库余额达到门槛自动解锁）'),
          ...kSkins.map((skin) => _SkinTile(
                skin: skin,
                vaultCoins: widget.vaultCoins,
                selected: _skinId == skin.id,
                onTap: () {
                  if (!skin.isUnlocked(widget.vaultCoins)) return;
                  setState(() => _skinId = skin.id);
                },
              )),
          const SizedBox(height: 28),
          GoldButton(label: '保存', onTap: _save),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
      );
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.text, required this.onTap});

  final String label;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            const SizedBox(height: 4),
            Text(text,
                style: const TextStyle(
                    color: kGold, fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

/// 皮肤选择行：色块 + 名称 + 解锁门槛 / 已解锁 / 已选中
class _SkinTile extends StatelessWidget {
  const _SkinTile({
    required this.skin,
    required this.vaultCoins,
    required this.selected,
    required this.onTap,
  });

  final CoinSkin skin;
  final double vaultCoins;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unlocked = skin.isUnlocked(vaultCoins);
    final subtitle = unlocked
        ? '已解锁'
        : '攒到 ${skin.unlockCoins} 枚解锁（还差 ${(skin.unlockCoins - vaultCoins).toStringAsFixed(0)}）';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: skin.themeColor.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
              color: unlocked ? skin.themeColor : Colors.white24, width: 2),
        ),
        child: Icon(
          unlocked ? Icons.paid : Icons.lock,
          size: 20,
          color: unlocked ? skin.themeColor : Colors.grey.shade600,
        ),
      ),
      title: Text(skin.name,
          style: TextStyle(
            color: unlocked ? Colors.white : Colors.grey.shade600,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          )),
      subtitle: Text(subtitle,
          style: TextStyle(
              color: unlocked ? Colors.grey.shade400 : Colors.grey.shade700,
              fontSize: 12)),
      trailing: selected
          ? const Icon(Icons.check_circle, color: kGold, size: 22)
          : null,
      onTap: onTap,
    );
  }
}

// 极简音效播放器（P1）：懒加载 AudioPlayer，全程 try/catch——
// 测试环境（无平台通道）、素材缺失、播放失败都不炸、静默跳过。
// 音量压到 0.25，金币"叮"限频 120ms，避免太吵（PRD：音效别太吵）。
import 'package:audioplayers/audioplayers.dart';

class SoundPlayer {
  SoundPlayer({this.enabled = true, this.volume = 0.25});

  bool enabled;
  final double volume;

  final Map<String, AudioPlayer> _players = {};
  DateTime _lastDing = DateTime.fromMillisecondsSinceEpoch(0);

  static const _throttle = Duration(milliseconds: 120);

  Future<void> _play(String asset) async {
    if (!enabled) return;
    try {
      final p = _players.putIfAbsent(asset, () => AudioPlayer());
      await p.setVolume(volume);
      await p.stop();
      await p.play(AssetSource('sounds/$asset'));
    } catch (_) {
      // 播放失败静默（真机上基本不会走到）
    }
  }

  /// 金币落地 / 出生"叮"（限频防炸耳）
  Future<void> ding() async {
    final now = DateTime.now();
    if (now.difference(_lastDing) < _throttle) return;
    _lastDing = now;
    await _play('coin_ding.wav');
  }

  /// 瀑布 / 整点大爆发"唰"
  Future<void> whoosh() => _play('surge.wav');
}

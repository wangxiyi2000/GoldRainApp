// 极简音效播放器（P1 + v0.5.0）：懒加载 AudioPlayer，全程 try/catch——
// 测试环境（无平台通道）、素材缺失、播放失败都不炸、静默跳过。
// 音量压到 0.25，金币"叮"限频 120ms，避免太吵（PRD：音效别太吵）。
// v0.5.0：新增 burstDing()——爆发期密集叮声（40ms 限频、音量 0.3）。
import 'package:audioplayers/audioplayers.dart';

class SoundPlayer {
  SoundPlayer({this.enabled = true, this.volume = 0.25});

  bool enabled;
  final double volume;

  final Map<String, AudioPlayer> _players = {};
  DateTime _lastDing = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastBurst = DateTime.fromMillisecondsSinceEpoch(0);

  static const _throttle = Duration(milliseconds: 120);
  static const _burstThrottle = Duration(milliseconds: 40);

  Future<void> _play(String asset, {double? volume}) async {
    if (!enabled) return;
    try {
      final p = _players.putIfAbsent(asset, () => AudioPlayer());
      await p.setVolume(volume ?? this.volume);
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

  /// 爆发期密集叮声（40ms 限频、音量稍大，配合满屏爆落噼里啪啦）
  Future<void> burstDing() async {
    final now = DateTime.now();
    if (now.difference(_lastBurst) < _burstThrottle) return;
    _lastBurst = now;
    await _play('coin_ding.wav', volume: 0.3);
  }

  /// 瀑布 / 整点大爆发"唰"
  Future<void> whoosh() => _play('surge.wav');
}

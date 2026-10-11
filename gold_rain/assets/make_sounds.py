# 一次性工具：程序化生成 P1 音效（小体积 wav，16bit 单声道 22050Hz）。
#   coin_ding.wav  金币落地"叮"（双泛音快速衰减，0.18s）
#   surge.wav      瀑布/整点爆发"唰"（上扫频+噪声包络，0.5s）
# 输出到 assets/sounds/，播放器会把音量压到 0.25，别吵。
import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.abspath(__file__))
SOUNDS = os.path.join(ROOT, 'sounds')
SR = 22050


def write_wav(name, samples):
    os.makedirs(SOUNDS, exist_ok=True)
    path = os.path.join(SOUNDS, name)
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(
            struct.pack('<h', int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))
    print(name, round(os.path.getsize(path) / 1024, 1), 'KB')


# 金币"叮"：1318.5Hz(E6) + 1975.5Hz(B6) 双泛音，指数衰减
n = int(SR * 0.18)
ding = []
for i in range(n):
    t = i / SR
    env = math.exp(-t * 22)
    ding.append((math.sin(2 * math.pi * 1318.5 * t) * 0.6
                 + math.sin(2 * math.pi * 1975.5 * t) * 0.4) * env)
write_wav('coin_ding.wav', ding)

# 爆发"唰"：频率上扫 + 噪声，正弦包络渐强再弱
random.seed(7)
n2 = int(SR * 0.5)
surge = []
for i in range(n2):
    t = i / SR
    f = 400 + 1400 * (i / n2)
    env = math.sin(math.pi * i / n2) ** 0.7
    surge.append((0.5 * math.sin(2 * math.pi * f * t) + 0.5 * random.uniform(-1, 1)) * env * 0.8)
write_wav('surge.wav', surge)

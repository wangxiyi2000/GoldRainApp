# 一次性工具：程序化生成 P1 全部皮肤精灵（2 套 × 4 帧，128px 透明底）。
# 帧约定：0=正面 → 1=侧转 30° → 2=侧缘 → 3=侧转 30°，循环 = 旋转一圈。
# 输出到 assets/skins/<id>/0..3.png，与 lib/render/skins.dart 的 framePaths 对应。
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, 'skins')
SIZE = 128

# 注意：gold 皮肤复用 assets/images/coin_*（make_coins.py 生成），这里不重复生成
# v0.6.6 起移除奶茶/钻石皮肤，仅保留红包、工资条
SKINS = ['redpack', 'paycheck']


def font(size):
    for p in [
        r'C:\Windows\Fonts\msyh.ttc',
        r'C:\Windows\Fonts\simhei.ttf',
        r'C:\Windows\Fonts\msyhbd.ttc',
    ]:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()


def draw_shape(kind):
    """把一种皮肤的正面向量图画进 256×256 透明画布，返回 Image。"""
    S = SIZE
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = S / 2

    if kind == 'gold':
        r = S * 0.42
        d.ellipse([c - r, c - r, c + r, c + r],
                  fill=(255, 215, 0, 255), outline=(184, 134, 11, 255), width=int(S * 0.04))
        d.ellipse([c - r * 0.82, c - r * 0.82, c + r * 0.82, c + r * 0.82],
                  outline=(255, 235, 120, 255), width=int(S * 0.016))
        glyph = '¥'
    elif kind == 'redpack':
        w, h = S * 0.66, S * 0.80
        x0, y0 = c - w / 2, c - h / 2
        d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=int(S * 0.055),
                            fill=(255, 77, 79, 255), outline=(200, 20, 30, 255), width=int(S * 0.031))
        band = S * 0.07
        d.rounded_rectangle([x0, c - band, x0 + w, c + band], radius=int(S * 0.04),
                            fill=(255, 215, 0, 255))
        glyph = '福'
    elif kind == 'paycheck':  # 工资条
        w, h = S * 0.62, S * 0.84
        x0, y0 = c - w / 2, c - h / 2
        d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=int(S * 0.039),
                            fill=(76, 217, 100, 255), outline=(20, 140, 60, 255), width=int(S * 0.031))
        for i in range(4):
            yy = y0 + h * 0.22 + i * h * 0.14
            d.line([x0 + w * 0.18, yy, x0 + w * 0.82, yy], fill=(255, 255, 255, 255), width=int(S * 0.027))
        glyph = '薪'
    else:  # 兜底：金币
        r = S * 0.42
        d.ellipse([c - r, c - r, c + r, c + r],
                  fill=(255, 215, 0, 255), outline=(184, 134, 11, 255), width=int(S * 0.04))
        d.ellipse([c - r * 0.82, c - r * 0.82, c + r * 0.82, c + r * 0.82],
                  outline=(255, 235, 120, 255), width=int(S * 0.016))
        glyph = '¥'

    f = font(int(S * 0.27))
    bbox = d.textbbox((0, 0), glyph, font=f)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text((c - tw / 2 - bbox[0], c - th / 2 - bbox[1]), glyph, font=f,
           fill=(255, 255, 255, 255))
    return img


def frames(shape_img):
    """正面图 → 4 帧旋转序列（水平缩放模拟旋转）。"""
    factors = [1.0, 0.65, 0.25, 0.65]
    out = []
    for f in factors:
        w = max(2, int(SIZE * f))
        resized = shape_img.resize((w, SIZE), Image.LANCZOS)
        frame = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
        frame.paste(resized, ((SIZE - w) // 2, 0), resized)
        out.append(frame)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    for kind in SKINS:
        folder = os.path.join(OUT, kind)
        os.makedirs(folder, exist_ok=True)
        shape = draw_shape(kind)
        for i, frame in enumerate(frames(shape)):
            frame.save(os.path.join(folder, f'{i}.png'))
        print('skins/', kind, 'ok')


if __name__ == '__main__':
    main()

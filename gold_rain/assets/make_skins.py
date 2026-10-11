# 一次性工具：程序化生成 P1 全部皮肤精灵（5 套 × 4 帧，256px 透明底）。
# 帧约定：0=正面 → 1=侧转 30° → 2=侧缘 → 3=侧转 30°，循环 = 旋转一圈。
# 输出到 assets/skins/<id>/0..3.png，与 lib/render/skins.dart 的 framePaths 对应。
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, 'skins')
SIZE = 256

SKINS = ['gold', 'redpack', 'milktea', 'diamond', 'paycheck']


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
                  fill=(255, 215, 0, 255), outline=(184, 134, 11, 255), width=10)
        d.ellipse([c - r * 0.82, c - r * 0.82, c + r * 0.82, c + r * 0.82],
                  outline=(255, 235, 120, 255), width=4)
        glyph = '¥'
    elif kind == 'redpack':
        w, h = S * 0.66, S * 0.80
        x0, y0 = c - w / 2, c - h / 2
        d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=14,
                            fill=(255, 77, 79, 255), outline=(200, 20, 30, 255), width=8)
        d.rounded_rectangle([x0, c - 18, x0 + w, c + 18], radius=10, fill=(255, 215, 0, 255))
        glyph = '福'
    elif kind == 'milktea':
        w, h = S * 0.60, S * 0.78
        x0, y0 = c - w / 2, c - h / 2
        d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=22,
                            fill=(198, 134, 66, 255), outline=(120, 70, 30, 255), width=8)
        d.ellipse([x0 - 14, y0 - 30, x0 + w + 14, y0 + 46], fill=(255, 240, 220, 255))
        d.line([c + 20, y0 - 46, c + 44, y0 - 90], fill=(255, 120, 150, 255), width=16)
        glyph = '茶'
    elif kind == 'diamond':
        pts = [(c, c - S * 0.42), (c + S * 0.30, c), (c, c + S * 0.42), (c - S * 0.30, c)]
        d.polygon(pts, fill=(77, 216, 255, 255), outline=(20, 100, 200, 255))
        d.line([c, c - S * 0.42, c, c + S * 0.42], fill=(255, 255, 255, 255), width=4)
        d.line([c - S * 0.30, c, c + S * 0.30, c], fill=(255, 255, 255, 255), width=4)
        glyph = '钻'
    else:  # paycheck 工资条
        w, h = S * 0.62, S * 0.84
        x0, y0 = c - w / 2, c - h / 2
        d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=10,
                            fill=(76, 217, 100, 255), outline=(20, 140, 60, 255), width=8)
        for i in range(4):
            yy = y0 + h * 0.22 + i * h * 0.14
            d.line([x0 + w * 0.18, yy, x0 + w * 0.82, yy], fill=(255, 255, 255, 255), width=7)
        glyph = '薪'

    f = font(70)
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

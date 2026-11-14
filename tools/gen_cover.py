"""itch.io cover (630x500): swamp backdrop, Kira leaping for the Ambrosia Apple, title.

Run from the project root:  python tools/gen_cover.py   ->  build/cover.png
"""
import pathlib
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
BG = ROOT / "forest-nature-fantasy-tileset-free/Fantasy Swamp Forest/Free"
W, H = 630, 500


def sprite(path, frame, scale, flip=False):
    img = Image.open(ROOT / path).convert("RGBA").crop((frame * 16, 0, frame * 16 + 16, 16))
    img = img.resize((16 * scale, 16 * scale), Image.NEAREST)
    return img.transpose(Image.FLIP_LEFT_RIGHT) if flip else img


def text(s, scale, color=(239, 230, 213)):
    """Pixel text: drawn at the font's native 16px without antialiasing, then scaled up."""
    font = ImageFont.truetype(str(ROOT / "assets/third_party/font/boldpixels.ttf"), 16)
    w = int(font.getlength(s)) + 4
    img = Image.new("RGBA", (w, 22))
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    d.text((2, 2), s, font=font, fill=color, stroke_width=1, stroke_fill=(13, 11, 10))
    return img.resize((w * scale, 22 * scale), Image.NEAREST)


cover = Image.new("RGBA", (W, H), (214, 230, 240, 255))
for name, x in (("BG_3/BG_3.png", -200), ("BG_2/BG_2.png", -300), ("BG_1/BG_1.png", -900)):
    cover.alpha_composite(Image.open(BG / name).convert("RGBA"), (x, 0))
cover.alpha_composite(Image.new("RGBA", (W, H), (28, 26, 38, 80)))
ImageDraw.Draw(cover).rectangle((0, 372, W, H), fill=(29, 26, 38, 255))

# Apple up high with a soft halo, Kira leaping for it, Melina in stone below.
halo = Image.new("RGBA", (W, H))
for r, a in ((70, 40), (50, 60), (34, 90)):
    ImageDraw.Draw(halo).ellipse((470 - r, 72 - r, 470 + r, 72 + r), fill=(244, 196, 48, a))
cover.alpha_composite(halo)
cover.alpha_composite(sprite("assets/sprites/apple.png", 0, 4), (438, 40))
cover.alpha_composite(sprite("assets/sprites/kira.png", 10, 7), (300, 120))
stone = sprite("assets/sprites/melina.png", 0, 5, flip=True)
gray = stone.convert("LA").convert("RGBA")
gray.putalpha(stone.getchannel("A"))
cover.alpha_composite(gray, (110, 292))

title = text("BOUNCE BACK", 4)
cover.alpha_composite(title, ((W - title.width) // 2, 374))
sub = text("Ascenso al Olimpo", 2, (244, 196, 48))
cover.alpha_composite(sub, ((W - sub.width) // 2, 452))

out = ROOT / "build/cover.png"
cover.convert("RGB").save(out)
print(out, cover.size)

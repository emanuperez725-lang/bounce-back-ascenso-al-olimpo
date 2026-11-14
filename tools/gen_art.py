"""Generates pixel-art placeholders in the Attic palette.

Run from the project root:  python tools/gen_art.py
Outputs:
  assets/sprites/kira.png        22 frames of 16x16, order = FRAMES (idle4 run6 jump peak fall2 dash2 climb4 wallslide land)
  assets/sprites/kira_spent.png  same, sandals white (dash used)
  assets/sprites/kira_barefoot.png  same, no sandals (prologue, before the altar)
  assets/sprites/apple.png       ambrosia apple 16x16
  assets/bg/sky.png, mountains.png, clouds.png   384x216
  preview/sprites.png (x8), preview/kira.gif (all animations)
Tiles and decor are baked per room at runtime by scripts/room.gd.
"""
import math
import pathlib
import random

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
PAL = {
    "k": (0x0D, 0x0B, 0x0A, 255),  # black
    "d": (0x7D, 0x38, 0x1B, 255),  # dark terracotta
    "t": (0xBA, 0x55, 0x26, 255),  # base terracotta
    "o": (0xEB, 0xB4, 0x71, 255),  # ochre
    "r": (0x82, 0x1D, 0x24, 255),  # rust red
    "w": (0xEF, 0xE6, 0xD5, 255),  # kaolin white
    "g": (0xF4, 0xC4, 0x30, 255),  # gold
}
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
W, H = 384, 216


def outline(img):
    """Black-figure look: every empty pixel touching a filled one turns black."""
    px = img.load()
    out = img.copy()
    po = out.load()
    for y in range(img.height):
        for x in range(img.width):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < img.width and 0 <= ny < img.height and px[nx, ny][3]:
                    po[x, y] = PAL["k"]
                    break
    return out


def rect(d, x0, y0, x1, y1, c):
    d.rectangle((x0, y0, x1, y1), fill=PAL[c])


# --- Kira: 16x16 sprite, 1x pixels like the tiles -----------------------------------
# Chunky pixels, big hair mass, tiny face, stubby limbs: readable at a glance.
# Feet on row 15, hitbox = cols 4-11 / rows 4-15 (8x12 px).

HEAD = [  # 8x6, faces right: round hair mass, headband, eye
    "..dddd..",
    ".dddddd.",
    "wwwwwwww",
    "dddtttt.",
    "ddttktt.",
    ".dtttt..",
]
TORSO = [  # chiton with dark belt, flared hem
    ".oooo",
    ".dddd",
    ".oooo",
    "oooooo",
]


class Px:
    """Tiny pixel canvas with bounds-safe drawing."""

    def __init__(self, w=16, h=16):
        self.img = Image.new("RGBA", (w, h))

    def put(self, x, y, c):
        if 0 <= x < self.img.width and 0 <= y < self.img.height:
            self.img.putpixel((int(x), int(y)), PAL[c])

    def block(self, x, y, rows):
        for j, row in enumerate(rows):
            for i, c in enumerate(row):
                if c != ".":
                    self.put(x + i, y + j, c)

    def seg(self, a, b, c):
        steps = max(abs(b[0] - a[0]), abs(b[1] - a[1]), 1)
        for i in range(steps + 1):
            self.put(round(a[0] + (b[0] - a[0]) * i / steps), round(a[1] + (b[1] - a[1]) * i / steps), c)

    def poly(self, pts, c):
        ImageDraw.Draw(self.img).polygon(pts, fill=PAL[c])


def kira(legs, arms, cape, dy=0, lean=0, droop=0.5, sandal="g"):
    """legs: [(hip_x, foot_x, foot_y)] back first. arms: [hand back, hand front].
    cape: polygon (moves with dy). droop: headband tails, + down / - up."""
    px = Px()
    px.poly([(x, y + dy) for x, y in cape], "r")
    px.seg((6, 11 + dy), (arms[0][0], arms[0][1] + dy), "d")
    for i, (hip, fx, fy) in enumerate(legs):
        px.seg((hip, 13 + dy), (fx, fy - 1), "d" if i == 0 else "t")
        px.put(fx, fy, sandal if sandal != "t" else "t")
        px.put(fx + 1, fy, sandal if sandal != "t" else "t")
    px.block(5, 10 + dy, TORSO)
    hx, hy = 5 + lean, 4 + dy
    px.put(hx - 1, hy + 2, "w")
    px.put(hx - 2, hy + 2 + round(droop), "w")
    px.put(hx - 3, hy + 2 + round(droop * 2), "w")
    px.block(hx, hy, HEAD)
    px.seg((10, 11 + dy), (arms[1][0], arms[1][1] + dy), "t")
    return outline(px.img)


def run_frame(i):
    a, swap = i % 3, i >= 3
    feet = [((4, 14), (11, 15)), ((5, 13), (10, 15)), ((8, 13), (7, 15))][a]
    back, front = (6, *feet[0]), (9, *feet[1])
    if swap:
        back, front = (6, *feet[1]), (9, *feet[0])
    hands = [((9, 12), (12, 11)), ((7, 13), (11, 12)), ((5, 12), (10, 13))][a]
    if swap:
        hands = hands[::-1]
    return dict(legs=[back, front], arms=list(hands), dy=(0, 1, 0)[a], lean=1, droop=0.0,
                cape=[(6, 10), (4, 10), (1, 11 + a % 2), (1, 13), (5, 13)])


STAND = [(6, 6, 15), (9, 9, 15)]
FRAMES = {
    **{f"idle{i}": dict(legs=STAND, arms=[(5, 13), (11, 13)], dy=(0, 0, 1, 1)[i], droop=1.0,
                        cape=[(6, 10), (4, 10), (3 - (i in (1, 2)), 14), (6, 14)]) for i in range(4)},
    **{f"run{i}": run_frame(i) for i in range(6)},
    "jump": dict(legs=[(6, 5, 14), (9, 10, 13)], arms=[(4, 9), (12, 8)], droop=1.5,
                 cape=[(6, 10), (4, 11), (4, 15), (6, 14)]),
    "peak": dict(legs=[(6, 5, 15), (9, 10, 15)], arms=[(3, 10), (13, 10)], droop=0.5,
                 cape=[(6, 10), (3, 11), (2, 13), (5, 13)]),
    **{f"fall{i}": dict(legs=[(6, 6, 15), (9, 10, 15)], arms=[(3, 8 - i), (13, 7 + i)], droop=-1.0,
                        cape=[(6, 10), (4, 9), (2, 6 + i), (4, 5), (6, 8)]) for i in range(2)},
    **{f"dash{i}": dict(legs=[(6, 3, 14), (9, 7, 15)], arms=[(3, 11), (14, 10)], lean=1, droop=0.0,
                        cape=[(6, 10), (5, 9), (0, 9 + i), (0, 11), (5, 12)]) for i in range(2)},
    **{f"climb{i}": dict(legs=[(6, 8, (15, 14, 15, 14)[i]), (9, 10, (14, 15, 14, 15)[i])],
                         arms=[(11, (11, 9, 7, 9)[i]), (12, (7, 9, 11, 9)[i])], dy=i % 2, droop=1.0,
                         cape=[(6, 10), (4, 10), (4, 15), (6, 14)]) for i in range(4)},
    "wallslide": dict(legs=[(6, 7, 15), (9, 10, 14)], arms=[(11, 10), (12, 6)], droop=-1.0,
                      cape=[(6, 10), (4, 9), (3, 6), (5, 6), (6, 8)]),
    "land": dict(legs=[(6, 4, 15), (9, 11, 15)], arms=[(4, 13), (12, 13)], dy=1, droop=1.5,
                 cape=[(6, 10), (3, 11), (2, 14), (6, 14)]),
}
FRAME_W = 16


def sheet(sandal):
    out = Image.new("RGBA", (FRAME_W * len(FRAMES), 16))
    for i, f in enumerate(FRAMES.values()):
        out.paste(kira(sandal=sandal, **f), (i * FRAME_W, 0))
    return out


def apple():
    img = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(img)
    d.ellipse((3, 5, 12, 14), fill=PAL["g"])
    d.ellipse((7, 9, 12, 14), fill=PAL["o"])
    rect(d, 5, 7, 6, 8, "w")
    rect(d, 7, 2, 7, 5, "d")
    rect(d, 8, 2, 10, 3, "d")
    return outline(img)


# --- background ----------------------------------------------------------------

def dither(stops, t, x, y):
    """Ordered dither across a list of palette keys, t in [0, 1]."""
    f = max(0.0, min(0.999, t)) * (len(stops) - 1)
    i, frac = int(f), f - int(f)
    return PAL[stops[i + 1] if frac * 16 > BAYER[y % 4][x % 4] else stops[i]]


def sky():
    img = Image.new("RGBA", (W, H))
    for y in range(H):
        for x in range(W):
            img.putpixel((x, y), dither(["t", "o", "w"], y / 160, x, y))
    return img


def temple(d, cx, base, w, c):
    """Peripteral temple silhouette: steps, columns, architrave, pediment."""
    x0, x1 = cx - w // 2, cx + w // 2
    d.rectangle((x0 - 2, base - 2, x1 + 2, base), fill=PAL[c])
    for x in range(x0, x1 + 1, 3):
        d.rectangle((x, base - 9, x + 1, base - 3), fill=PAL[c])
    d.rectangle((x0 - 1, base - 12, x1 + 1, base - 10), fill=PAL[c])
    d.polygon([(x0 - 1, base - 13), (x1 + 1, base - 13), (cx, base - 18)], fill=PAL[c])


def mountains():
    img = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(img)
    ridge = []
    for x in range(W):
        h = (150 - 62 * math.exp(-((x - 270) / 46) ** 2) - 24 * math.exp(-((x - 80) / 38) ** 2)
             - 4 * math.sin(x / 7) - 2 * math.sin(x / 2.7))
        ridge.append(int(h))
        for y in range(int(h), H):
            img.putpixel((x, y), dither(["t", "d"], (y - h) / 90, x, y))
    temple(d, 270, ridge[270] + 2, 22, "d")
    temple(d, 80, ridge[80] + 2, 14, "d")
    # sea of clouds at the mountain's feet
    rnd = random.Random(3)
    for x in range(-10, W + 10, 14):
        y = 196 + rnd.randint(-4, 4)
        r = rnd.randint(9, 14)
        d.ellipse((x - r, y - r, x + r, y + r), fill=PAL["w"])
        d.ellipse((x - r + 2, y - r + 4, x + r, y + r + 4), fill=PAL["o"])
    d.rectangle((0, 204, W, H), fill=PAL["o"])
    return img


def clouds():
    img = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(img)
    rnd = random.Random(7)
    for cx, cy, w in ((60, 34, 90), (210, 22, 70), (330, 60, 80), (150, 84, 50)):
        puffs = [(cx - w // 2 + i * w // 5, cy + rnd.randint(-5, 3), rnd.randint(7, 12)) for i in range(6)]
        for x, y, r in puffs:
            d.ellipse((x - r, y - r + 3, x + r, y + r + 3), fill=PAL["r"])
        for x, y, r in puffs:
            d.ellipse((x - r, y - r, x + r, y + r - 2), fill=PAL["d"])
            d.arc((x - r + 3, y - r + 3, x + 2, y + 2), 180, 300, fill=PAL["t"])
    return outline(img)


# --- preview -------------------------------------------------------------------

def big(img, s):
    return img.resize((img.width * s, img.height * s), Image.NEAREST)


def main():
    for sub in ("assets/sprites", "assets/bg", "preview"):
        (ROOT / sub).mkdir(parents=True, exist_ok=True)
    charged, spent = sheet("g"), sheet("w")
    charged.save(ROOT / "assets/sprites/kira.png")
    spent.save(ROOT / "assets/sprites/kira_spent.png")
    sheet("t").save(ROOT / "assets/sprites/kira_barefoot.png")  # before the altar
    apple().save(ROOT / "assets/sprites/apple.png")
    s, m, c = sky(), mountains(), clouds()
    s.save(ROOT / "assets/bg/sky.png")
    m.save(ROOT / "assets/bg/mountains.png")
    c.save(ROOT / "assets/bg/clouds.png")

    board = Image.new("RGBA", (charged.width + 8, 16 * 3 + 12 + 20), PAL["w"])
    board.alpha_composite(charged, (4, 4))
    board.alpha_composite(spent, (4, 24))
    board.alpha_composite(sheet("t"), (4, 44))
    board.alpha_composite(apple(), (4, 64))
    big(board, 8).save(ROOT / "preview/sprites.png")

    # Every animation in a row on an ochre backdrop: idle, run x2, jump arc, land, dash, climb.
    seq = (["idle0", "idle1", "idle2", "idle3"] * 2 + [f"run{i}" for i in range(6)] * 3
           + ["jump"] * 3 + ["peak"] * 2 + ["fall0", "fall1"] * 2 + ["land"] * 2
           + ["dash0", "dash1"] * 3 + [f"climb{i}" for i in range(4)] * 2 + ["wallslide"] * 4)
    gif = []
    for n in seq:
        f = Image.new("RGBA", (16, 16), PAL["o"])
        f.alpha_composite(kira(**FRAMES[n]))
        gif.append(big(f, 12).convert("P"))
    gif[0].save(ROOT / "preview/kira.gif", save_all=True, append_images=gif[1:], duration=90, loop=0)
    print("art generated:", len(FRAMES), "kira frames")


main()

"""Builds Kira's sprite sheets on the 2D Platformer Character Template model (16x16 frames).

Run from the project root:  python tools/gen_kira.py
Template placeholder colors become Kira's original design: brown hair, white headband,
terracotta skin, ochre tunic, rust-red cape and the sandals of Hermes, whose color shows the
dash (gold = ready, white = spent, bare feet = no sandals yet).
Output: assets/sprites/kira{,_spent,_barefoot}.png and melina.png (cutscenes), one row of FRAMES + 4 climb frames.
"""
import pathlib
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/third_party/character_template"
OUT = ROOT / "assets/sprites"

# Frame order (scripts/player.gd enum). Climb frames are made from WallSlide, appended last.
FRAMES = [("Idle", 1), ("Run", 8), ("Jump", 5), ("Dash", 2), ("WallSlide", 1), ("Crouch", 2)]

OUTLINE, HAIR = (14, 7, 27), (26, 25, 50)
SKIN, SKIN_D = (153, 230, 95), (90, 197, 79)
CAPE, CAPE_D = (0, 205, 249), (0, 152, 220)
TUNIC, TUNIC_D = (255, 162, 20), (237, 118, 20)
LEGS = {(245, 85, 93), (234, 50, 60)}
LEGS_D = (196, 36, 48)

KIRA = {
    OUTLINE: (13, 11, 10), HAIR: (125, 56, 27),
    SKIN: (200, 106, 58), SKIN_D: (154, 74, 38),
    CAPE: (130, 29, 36), CAPE_D: (94, 20, 25),
    TUNIC: (235, 180, 113), TUNIC_D: (200, 146, 90),
    LEGS_D: (154, 74, 38),
}
for c in LEGS:
    KIRA[c] = (200, 106, 58)
HEADBAND = (239, 230, 213)
# Melina, same model: black hair, pale skin, white chiton, blue cloak, no headband.
MELINA = dict(KIRA)
MELINA.update({HAIR: (40, 30, 42), SKIN: (226, 160, 120), SKIN_D: (180, 120, 90),
               CAPE: (60, 90, 160), CAPE_D: (40, 60, 120), TUNIC: (239, 230, 213), TUNIC_D: (190, 180, 170),
               LEGS_D: (180, 120, 90)})
for c in LEGS:
    MELINA[c] = (226, 160, 120)
SANDALS = {"": (244, 196, 48), "_spent": (239, 230, 213), "_barefoot": None}


def frames():
    out = []
    for name, n in FRAMES:
        sheet = Image.open(SRC / f"2DPCT_{name}.png").convert("RGBA")
        out += [sheet.crop((i * 16, 0, i * 16 + 16, 16)) for i in range(n)]
    slide = out[16]
    out += [slide, shift(slide, {CAPE, CAPE_D}), slide, shift(slide, LEGS | {LEGS_D})]
    return out


def shift(img, colors):
    """Move pixels of `colors` one up (a climbing reach), leaving the rest in place."""
    src, out = img.load(), img.copy()
    dst = out.load()
    for y in range(16):
        for x in range(16):
            if src[x, y][:3] in colors and src[x, y][3]:
                dst[x, y] = src[x, y - 1] if y and src[x, y - 1][:3] not in colors else src[x, y]
    for y in range(1, 16):
        for x in range(16):
            if src[x, y][:3] in colors and src[x, y][3]:
                dst[x, y - 1] = src[x, y]
    return out


def kira(img, sandal, palette=KIRA, headband=True):
    px = img.load()
    rows = [[px[x, y][:3] if px[x, y][3] else None for x in range(16)] for y in range(16)]
    skin_rows = [y for y in range(16) if any(c in (SKIN, SKIN_D) for c in rows[y])]
    leg_rows = [y for y in range(16) if any(c in LEGS or c == LEGS_D for c in rows[y])]
    for y in range(16):
        for x in range(16):
            c = rows[y][x]
            if c is None or c not in palette:
                continue
            new = palette[c]
            if headband and skin_rows and y == skin_rows[0] and c in (SKIN, SKIN_D):
                new = HEADBAND
            if sandal and leg_rows and y == leg_rows[-1] and (c in LEGS or c == LEGS_D):
                new = sandal
            px[x, y] = new + (255,)
    return img


if __name__ == "__main__":
    fs = frames()
    assert len(fs) == 23, len(fs)
    for suffix, sandal in SANDALS.items():
        sheet = Image.new("RGBA", (16 * len(fs), 16))
        for i, f in enumerate(fs):
            sheet.paste(kira(f.copy(), sandal), (i * 16, 0))
        sheet.save(OUT / f"kira{suffix}.png")
        if suffix == "":
            sheet.resize((sheet.width * 8, 128), Image.NEAREST).save(ROOT / "preview/kira_template.png")
    sheet = Image.new("RGBA", (16 * len(fs), 16))
    for i, f in enumerate(fs):
        sheet.paste(kira(f.copy(), None, MELINA, headband=False), (i * 16, 0))
    sheet.save(OUT / "melina.png")
    print("kira + melina sheets:", len(fs), "frames")

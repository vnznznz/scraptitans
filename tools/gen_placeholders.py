#!/usr/bin/env python3
import os
import random

from PIL import Image, ImageDraw

OUT = "art"

INK = (20, 18, 24, 255)
METAL_D = (58, 62, 74, 255)
METAL = (96, 104, 120, 255)
METAL_L = (150, 158, 172, 255)
RUST = (150, 82, 50, 255)
RUST_L = (196, 120, 70, 255)
GOLD = (255, 211, 77, 255)
GOLD_D = (196, 140, 40, 255)
RED = (214, 64, 56, 255)
GREEN = (96, 196, 96, 255)
GREEN_D = (48, 120, 56, 255)
WHITE = (240, 240, 232, 255)
CLEAR = (0, 0, 0, 0)

ACCENT = {
    "frame": (80, 150, 220, 255),
    "core": (150, 100, 200, 255),
    "arms": (230, 140, 50, 255),
    "plating": (120, 190, 110, 255),
}


def new(w, h):
    img = Image.new("RGBA", (w, h), CLEAR)
    return img, ImageDraw.Draw(img)


def box(d, x0, y0, x1, y1, fill, outline=INK):
    d.rectangle([x0, y0, x1, y1], fill=fill, outline=outline)


def save(img, path):
    full = os.path.join(OUT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    img.save(full)


CREDIT_TIERS = [(GOLD_D, GOLD), ((30, 120, 70, 255), (100, 220, 140, 255)), ((130, 50, 190, 255), (220, 140, 255, 255))]
SCRAP_TIERS = [METAL_L, (90, 200, 230, 255), (240, 120, 50, 255)]


def ui():
    for name, size, (dark, light) in [("ui/credits.png", 16, CREDIT_TIERS[0])] + [
        (f"fx/disc_credits_{i + 1}.png", 10, c) for i, c in enumerate(CREDIT_TIERS)
    ]:
        img, d = new(size, size)
        d.ellipse([0, 0, size - 1, size - 1], fill=dark, outline=INK)
        d.ellipse([1, 1, size - 3, size - 3], fill=light)
        m = size // 2
        d.rectangle([m - 1, 3, m, size - 4], fill=dark)
        save(img, name)

    for name, size, fill in [("ui/scrap.png", 16, SCRAP_TIERS[0])] + [
        (f"fx/disc_scrap_{i + 1}.png", 10, c) for i, c in enumerate(SCRAP_TIERS)
    ]:
        img, d = new(size, size)
        c = size // 3
        e = size - 1
        d.polygon([(c, 0), (e - c, 0), (e, c), (e, e - c), (e - c, e), (c, e), (0, e - c), (0, c)], fill=fill, outline=INK)
        m = size // 2
        d.rectangle([m - 2, m - 2, m + 1, m + 1], fill=INK)
        save(img, name)

    img, d = new(16, 16)
    box(d, 5, 1, 10, 5, METAL_L)
    d.rectangle([8, 3, 9, 3], fill=RED)
    box(d, 3, 6, 12, 10, METAL)
    box(d, 12, 7, 15, 8, METAL_D)
    box(d, 4, 11, 6, 15, METAL_D)
    box(d, 9, 11, 11, 15, METAL_D)
    save(img, "ui/mech.png")

    img, d = new(16, 16)
    d.ellipse([1, 1, 14, 14], fill=METAL_L, outline=INK)
    d.rectangle([7, 4, 8, 5], fill=INK)
    d.rectangle([7, 7, 8, 11], fill=INK)
    save(img, "ui/info.png")

    img, d = new(16, 16)
    for x, y in [(7, 1), (7, 13), (1, 7), (13, 7), (3, 3), (11, 3), (3, 11), (11, 11)]:
        d.rectangle([x, y, x + 1, y + 1], fill=METAL_L)
    d.ellipse([3, 3, 12, 12], fill=METAL_L)
    d.ellipse([6, 6, 9, 9], fill=METAL_D)
    save(img, "ui/gear.png")

    img, d = new(12, 12)
    box(d, 0, 0, 11, 11, RED)
    d.polygon([(4, 2), (7, 2), (9, 4), (9, 7), (7, 9), (4, 9), (2, 7), (2, 4)], fill=METAL_L, outline=INK)
    save(img, "ui/stall_scrap.png")

    img, d = new(12, 12)
    box(d, 0, 0, 11, 11, RED)
    d.rectangle([2, 5, 9, 6], fill=WHITE)
    save(img, "ui/stall_blocked.png")

    img, d = new(6, 6)
    box(d, 0, 0, 5, 5, METAL_D)
    save(img, "ui/bar_under.png")

    img, d = new(6, 6)
    box(d, 0, 0, 5, 5, GREEN, outline=INK)
    d.line([1, 1, 4, 1], fill=(160, 230, 150, 255))
    save(img, "ui/bar_fill.png")

    img, d = new(6, 6)
    box(d, 0, 0, 5, 5, RED, outline=INK)
    d.line([1, 1, 4, 1], fill=(240, 130, 110, 255))
    save(img, "ui/hp_fill.png")

    for name, face, hi in [
        ("button", METAL, METAL_L),
        ("button_hover", (112, 121, 138, 255), (172, 180, 194, 255)),
        ("button_pressed", METAL_D, METAL),
        ("button_disabled", (60, 60, 66, 255), (76, 76, 82, 255)),
    ]:
        img, d = new(12, 12)
        box(d, 0, 0, 11, 11, face)
        d.line([1, 1, 10, 1], fill=hi)
        for x, y in [(2, 2), (9, 2), (2, 9), (9, 9)]:
            d.point((x, y), fill=INK)
        save(img, f"ui/{name}.png")

    img, d = new(12, 12)
    box(d, 0, 0, 11, 11, (36, 34, 44, 255))
    d.line([1, 1, 10, 1], fill=(52, 50, 62, 255))
    save(img, "ui/panel.png")


def line():
    img, d = new(64, 8)
    box(d, 0, 0, 63, 7, (60, 56, 40, 255))
    for x in range(-8, 64, 8):
        d.polygon([(x, 7), (x + 4, 7), (x + 8, 0), (x + 4, 0)], fill=(200, 170, 40, 255))
    d.rectangle([0, 0, 63, 7], outline=INK)
    save(img, "line/pad.png")

    img, d = new(16, 8)
    box(d, 0, 0, 15, 7, (44, 44, 52, 255), outline=None)
    d.line([0, 0, 15, 0], fill=INK)
    d.line([0, 7, 15, 7], fill=INK)
    d.rectangle([2, 2, 5, 5], fill=(70, 70, 82, 255))
    d.rectangle([10, 2, 13, 5], fill=(70, 70, 82, 255))
    save(img, "line/belt.png")

    for kind, accent in ACCENT.items():
        img, d = new(80, 56)
        box(d, 4, 4, 9, 55, METAL)
        box(d, 70, 4, 75, 55, METAL)
        box(d, 2, 2, 77, 9, METAL_L)
        d.rectangle([4, 4, 75, 5], fill=accent)
        box(d, 34, 10, 45, 17, METAL_D)
        box(d, 37, 18, 42, 23, accent)
        for y in range(14, 54, 8):
            d.line([5, y, 8, y + 3], fill=METAL_D)
            d.line([71, y, 74, y + 3], fill=METAL_D)
        save(img, f"line/machine_{kind}.png")


TIER_COL = [
    (RUST, RUST_L),
    ((96, 104, 120, 255), (130, 138, 152, 255)),
    ((140, 150, 166, 255), (190, 198, 210, 255)),
    ((200, 206, 214, 255), (238, 240, 244, 255)),
    ((206, 156, 48, 255), (250, 210, 90, 255)),
    ((56, 140, 76, 255), (120, 210, 120, 255)),
]
HAZARD = (240, 210, 40, 255)


def mech():
    legs = [(0, 0, 0, 0), (-1, -1, 1, 0), (0, 0, 0, 0), (1, 0, -1, -1)]
    for t in range(6):
        col, hi = TIER_COL[t]
        sheet = Image.new("RGBA", (96, 32), CLEAR)
        for f, (lx, ly, rx, ry) in enumerate(legs):
            img, d = new(24, 32)
            bob = 1 if f in (1, 3) else 0
            lw = 3 + t // 2
            box(d, 9 - lw + lx, 21 + ly, 9 + lx, 31 + ly, METAL_D if t < 3 else METAL)
            box(d, 13 + rx, 21 + ry, 13 + lw + rx, 31 + ry, METAL_D if t < 3 else METAL)
            box(d, 6 - lw + lx, 30 + ly, 11 + lx, 31 + ly, INK)
            box(d, 12 + rx, 30 + ry, 17 + lw + rx, 31 + ry, INK)
            top = 13 - t // 2 - bob
            box(d, 5 - t // 3, top, 18 + t // 3, 22 - bob, col)
            d.line([6 - t // 3, top + 1, 17 + t // 3, top + 1], fill=hi)
            if t >= 2:
                d.rectangle([8, top + 4, 15, top + 5], fill=METAL_D)
            if t == 5:
                d.rectangle([10, top + 3, 13, top + 6], fill=HAZARD)
            sheet.paste(img, (f * 24, 0))
        save(sheet, f"mech/frame_{t + 1}.png")

        img, d = new(24, 32)
        w = 8 + t // 2
        box(d, 12 - w // 2, 4 - t // 3, 12 + w // 2, 12, hi if t >= 3 else METAL_L)
        eye = [RED, RED, (80, 200, 240, 255), (80, 200, 240, 255), (200, 120, 255, 255), HAZARD][t]
        d.rectangle([13, 7, 12 + w // 2 - 1, 8], fill=eye)
        if t in (0, 2, 4):
            d.line([10, 0, 10, 3 - t // 3], fill=INK)
        if t >= 3:
            d.rectangle([12 - w // 2 + 1, 10, 12 + w // 2 - 1, 11], fill=col)
        save(img, f"mech/core_{t + 1}.png")

        img, d = new(24, 32)
        if t == 5:
            box(d, 2, 2, 6, 22, WHITE)
            d.polygon([(2, 2), (4, -1), (6, 2)], fill=RED, outline=INK)
            for y in range(6, 20, 4):
                d.rectangle([3, y, 5, y + 1], fill=INK)
            box(d, 1, 20, 7, 23, METAL_D)
            box(d, 12, 13, 16, 18, METAL_D)
        else:
            box(d, 11, 13, 16, 19, METAL_D)
            length = 7 + t
            if t == 3:
                box(d, 14, 11, 22, 18, col)
                for y in (12, 15):
                    d.point((22, y + 1), fill=INK)
            else:
                box(d, 16, 15, min(16 + length, 23), 17, col)
                if t == 2:
                    box(d, 16, 12, min(16 + length, 23), 13, col)
                if t == 4:
                    d.line([17, 16, 23, 16], fill=(120, 220, 255, 255))
        save(img, f"mech/arms_{t + 1}.png")

        img, d = new(24, 32)
        box(d, 4, 14, 8, 21, col)
        box(d, 15, 14, 19, 21, col)
        box(d, 4, 11 - t // 3, 19, 13, hi)
        if t >= 2:
            for x in (5, 17):
                d.point((x, 17), fill=INK)
        save(img, f"mech/plating_{t + 1}.png")


def yard():
    rnd = random.Random(7)
    img, d = new(112, 64)
    d.polygon([(4, 63), (30, 24), (50, 10), (70, 14), (92, 30), (108, 63)], fill=(84, 70, 60, 255), outline=INK)
    colors = [METAL, METAL_L, RUST, RUST_L, METAL_D, (120, 110, 90, 255)]
    for _ in range(90):
        x = rnd.randint(14, 96)
        y = rnd.randint(18, 60)
        if not img.getpixel((x, y))[3]:
            continue
        w = rnd.randint(2, 6)
        h = rnd.randint(2, 4)
        d.rectangle([x, y, x + w, y + h], fill=rnd.choice(colors), outline=INK)
    save(img, "yard/pile.png")


ENEMY_COL = [
    (RED, (170, 50, 44, 255), (230, 110, 96, 255)),
    ((90, 170, 70, 255), (56, 116, 48, 255), (150, 214, 120, 255)),
    ((70, 120, 210, 255), (48, 84, 158, 255), (130, 170, 240, 255)),
    ((150, 80, 200, 255), (106, 54, 146, 255), (204, 144, 240, 255)),
    ((64, 60, 70, 255), (36, 34, 40, 255), (236, 196, 70, 255)),
]


def enemies(v, body, dark, hi):
    img, d = new(14, 10)
    box(d, 3, 2, 10, 7, body)
    d.rectangle([5, 4, 6, 5], fill=GOLD)
    d.line([0, 1, 13, 1], fill=METAL_L)
    d.line([6, 0, 7, 0], fill=INK)
    d.line([1, 8, 1, 9], fill=METAL_D)
    save(img, f"battlefield/enemy_drone_{v}.png")

    img, d = new(22, 16)
    box(d, 1, 10, 20, 15, METAL_D)
    for x in range(3, 20, 4):
        d.rectangle([x, 12, x + 1, 13], fill=METAL)
    box(d, 4, 4, 17, 10, body)
    box(d, 7, 1, 13, 4, dark)
    box(d, 0, 2, 7, 3, METAL)
    save(img, f"battlefield/enemy_crawler_{v}.png")

    img, d = new(36, 44)
    box(d, 8, 30, 14, 43, METAL_D)
    box(d, 22, 30, 28, 43, METAL_D)
    box(d, 4, 12, 31, 31, body)
    d.line([5, 13, 30, 13], fill=hi)
    box(d, 12, 2, 24, 12, dark)
    d.rectangle([13, 6, 16, 8], fill=GOLD)
    box(d, 0, 16, 8, 20, METAL)
    box(d, 0, 22, 4, 34, METAL_D)
    for x, y in [(10, 18), (20, 24), (26, 16)]:
        box(d, x, y, x + 3, y + 3, RUST_L)
    save(img, f"battlefield/enemy_brute_{v}.png")


def battlefield():
    img, d = new(360, 160)
    top, bottom = (34, 36, 60), (104, 84, 112)
    for y in range(132):
        t = y / 131
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        d.line([0, y, 359, y], fill=c)
    rnd = random.Random(3)
    x = 0
    while x < 360:
        w = rnd.randint(20, 50)
        h = rnd.randint(8, 30)
        d.rectangle([x, 131 - h, x + w, 131], fill=(58, 50, 70, 255))
        x += w
    d.rectangle([0, 132, 359, 159], fill=(70, 58, 50, 255))
    d.line([0, 132, 359, 132], fill=(96, 80, 64, 255))
    for _ in range(60):
        px = rnd.randint(0, 359)
        py = rnd.randint(136, 158)
        d.point((px, py), fill=(56, 46, 40, 255))
    save(img, "battlefield/bg.png")

    for v, (body, dark, hi) in enumerate(ENEMY_COL):
        enemies(v + 1, body, dark, hi)


def fx():
    img, d = new(16, 16)
    d.ellipse([1, 1, 14, 14], fill=(200, 200, 200, 255))
    d.ellipse([3, 3, 10, 10], fill=WHITE)
    save(img, "fx/puff.png")

    img, d = new(3, 3)
    d.rectangle([0, 0, 2, 2], fill=WHITE)
    save(img, "fx/spark.png")


def fx_extra():
    img, d = new(8, 8)
    d.polygon([(0, 2), (4, 0), (7, 3), (4, 7), (0, 5)], fill=HAZARD)
    d.rectangle([1, 3, 3, 4], fill=WHITE)
    save(img, "fx/muzzle.png")

    img, d = new(4, 2)
    d.rectangle([0, 0, 3, 1], fill=HAZARD)
    save(img, "fx/bullet.png")

    img, d = new(3, 3)
    d.rectangle([0, 0, 2, 2], fill=(255, 90, 70, 255))
    save(img, "fx/enemy_bullet.png")

    img, d = new(4, 4)
    box(d, 0, 0, 3, 3, METAL, outline=INK)
    save(img, "fx/debris.png")

    img, d = new(8, 20)
    box(d, 2, 3, 5, 16, WHITE)
    d.polygon([(2, 3), (3, 0), (4, 0), (5, 3)], fill=RED)
    for y in (6, 10):
        d.rectangle([2, y, 5, y + 1], fill=HAZARD)
    d.polygon([(0, 17), (2, 13), (2, 17)], fill=METAL_D)
    d.polygon([(7, 17), (5, 13), (5, 17)], fill=METAL_D)
    d.rectangle([3, 17, 4, 19], fill=(255, 160, 40, 255))
    save(img, "fx/missile.png")

    img, d = new(64, 72)
    d.rectangle([26, 28, 37, 71], fill=(200, 110, 60, 255))
    d.rectangle([29, 28, 34, 71], fill=(240, 170, 80, 255))
    d.ellipse([10, 58, 53, 71], fill=(160, 90, 60, 255))
    d.ellipse([2, 2, 61, 36], fill=(220, 110, 50, 255))
    d.ellipse([8, 4, 55, 26], fill=(250, 180, 80, 255))
    d.ellipse([18, 6, 45, 18], fill=(255, 235, 170, 255))
    d.ellipse([12, 28, 51, 38], fill=(180, 90, 50, 255))
    save(img, "fx/mushroom.png")

    img, d = new(80, 20)
    rnd = random.Random(11)
    d.polygon([(0, 19), (12, 8), (30, 12), (46, 4), (62, 10), (79, 19)], fill=(56, 54, 62, 255), outline=INK)
    for _ in range(30):
        x = rnd.randint(8, 70)
        y = rnd.randint(9, 17)
        if img.getpixel((x, y))[3]:
            d.rectangle([x, y, x + rnd.randint(2, 5), y + rnd.randint(1, 3)], fill=rnd.choice([METAL, METAL_D, RUST]), outline=INK)
    save(img, "line/rubble.png")

    img, d = new(16, 16)
    d.polygon([(8, 1), (14, 8), (10, 8), (10, 14), (6, 14), (6, 8), (2, 8)], fill=GREEN, outline=INK)
    save(img, "ui/up.png")


def workers():
    for name, shovel in [("line/worker.png", False), ("yard/worker.png", True)]:
        img, d = new(10, 14)
        box(d, 3, 0, 7, 2, GOLD)
        box(d, 3, 3, 6, 5, (220, 170, 130, 255))
        box(d, 2, 6, 7, 10, (60, 110, 200, 255))
        box(d, 2, 11, 3, 13, METAL_D, outline=None)
        box(d, 6, 11, 7, 13, METAL_D, outline=None)
        if shovel:
            d.line([8, 3, 8, 11], fill=RUST_L)
            box(d, 7, 11, 9, 13, METAL_L)
        save(img, name)

    img, d = new(16, 16)
    box(d, 5, 1, 10, 3, GOLD)
    box(d, 5, 4, 9, 7, (220, 170, 130, 255))
    box(d, 3, 8, 11, 14, (60, 110, 200, 255))
    d.rectangle([12, 8, 14, 14], fill=GREEN)
    d.rectangle([11, 10, 15, 12], fill=GREEN)
    save(img, "ui/worker.png")

    img, d = new(16, 16)
    box(d, 3, 2, 6, 13, WHITE)
    box(d, 9, 2, 12, 13, WHITE)
    save(img, "ui/pause.png")

    img, d = new(16, 16)
    d.polygon([(4, 2), (13, 8), (4, 13)], fill=GREEN, outline=INK)
    save(img, "ui/play.png")


if __name__ == "__main__":
    ui()
    line()
    mech()
    yard()
    battlefield()
    fx()
    workers()
    fx_extra()

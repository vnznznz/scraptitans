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


def ui():
    img, d = new(8, 8)
    d.ellipse([0, 0, 7, 7], fill=GOLD_D)
    d.ellipse([1, 1, 6, 6], fill=GOLD)
    d.rectangle([3, 2, 4, 5], fill=GOLD_D)
    save(img, "ui/credits.png")

    img, d = new(8, 8)
    d.polygon([(2, 0), (5, 0), (7, 2), (7, 5), (5, 7), (2, 7), (0, 5), (0, 2)], fill=METAL_L, outline=INK)
    d.rectangle([3, 3, 4, 4], fill=INK)
    save(img, "ui/scrap.png")

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

    for name, face, hi in [
        ("button", METAL, METAL_L),
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


def mech():
    img, d = new(24, 32)
    box(d, 7, 21, 10, 31, METAL)
    box(d, 13, 21, 16, 31, METAL)
    box(d, 5, 30, 11, 31, METAL_D)
    box(d, 12, 30, 18, 31, METAL_D)
    box(d, 5, 12, 18, 22, RUST)
    d.line([6, 13, 17, 13], fill=RUST_L)
    save(img, "mech/frame_1.png")

    img, d = new(24, 32)
    box(d, 8, 4, 16, 12, METAL_L)
    d.rectangle([13, 7, 15, 8], fill=RED)
    d.line([10, 1, 10, 3], fill=INK)
    save(img, "mech/core_1.png")

    img, d = new(24, 32)
    box(d, 12, 13, 16, 18, METAL_D)
    box(d, 16, 15, 23, 17, METAL)
    save(img, "mech/arms_1.png")


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

    img, d = new(20, 20)
    box(d, 2, 10, 17, 17, RED)
    box(d, 6, 5, 14, 10, (170, 50, 44, 255))
    box(d, 0, 7, 6, 8, METAL_D)
    d.rectangle([2, 17, 17, 19], fill=INK)
    save(img, "battlefield/enemy_1.png")


def fx():
    img, d = new(16, 16)
    d.ellipse([1, 1, 14, 14], fill=(200, 200, 200, 255))
    d.ellipse([3, 3, 10, 10], fill=WHITE)
    save(img, "fx/puff.png")


if __name__ == "__main__":
    ui()
    line()
    mech()
    yard()
    battlefield()
    fx()

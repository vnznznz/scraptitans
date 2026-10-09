#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""Generate the CrazyGames covers and cover layers in release/marketing/ from the sprites
in art/ (run gen_art.py first).

Usage:
    uv run tools/gen_covers.py
"""

import os

from PIL import Image

from gen_art import CELL, NUKE_CELL, PARALLAX, mech_cell, title, upscale

ART = "art"
OUT = "release/marketing"
SCALE = 8
FRONT = 330
FIELD_H = 160
GROUND_TOP = 106
FEET = 146


def sprite(path, cell=None, col=0):
    img = Image.open(os.path.join(ART, path)).convert("RGBA")
    if cell:
        img = img.crop((col * cell[0], 0, (col + 1) * cell[0], cell[1]))
    return img


def field(width, height):
    img = Image.new("RGBA", (width, FIELD_H))
    img.alpha_composite(sprite("battlefield/sky.png").crop((0, 0, width, 110)))
    for name in ("far", "near"):
        x = round(FRONT * PARALLAX[name])
        img.alpha_composite(sprite(f"battlefield/{name}.png").crop((x, 0, x + width, 110)))
    img.alpha_composite(sprite("battlefield/ground.png").crop((FRONT, 0, FRONT + width, FIELD_H - GROUND_TOP)), (0, GROUND_TOP))
    return img.crop((0, FIELD_H - height, width, FIELD_H))


def stand(img, s, x, feet):
    img.alpha_composite(s, (x, feet - s.height))


def save(img, name):
    path = os.path.join(OUT, name + ".png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    upscale(img, SCALE).save(path)


def landscape():
    w, h = 240, 135
    feet = h - (FIELD_H - FEET)
    img = field(w, h)
    for x, y in ((148, 22), (172, 34), (196, 16), (218, 30), (160, 48), (206, 50)):
        img.alpha_composite(sprite("battlefield/enemy_drone_1.png"), (x, y))
    stand(img, sprite("battlefield/enemy_boss_1.png"), 172, feet)
    stand(img, sprite("battlefield/enemy_brute_1.png"), 140, feet + 4)
    stand(img, sprite("battlefield/enemy_crawler_1.png"), 126, feet + 8)
    for t, x, dy in ((2, -6, -2), (4, 18, -2), (6, 44, -2), (1, 6, 6), (3, 32, 6), (5, 58, 6)):
        stand(img, mech_cell(t), x, feet + dy)
    stand(img, sprite("mech/nuclear.png", NUKE_CELL), 70, feet + 2)
    img.alpha_composite(sprite("fx/explosion_big.png", (40, 40), 2), (150, feet - 66))
    img.alpha_composite(sprite("fx/explosion_big.png", (40, 40), 3), (188, feet - 44))
    img.alpha_composite(sprite("fx/explosion.png", (24, 24), 2), (134, feet - 30))
    img.alpha_composite(upscale(title(), 2), (110, 3))
    save(img, "covers/landscape")


def portrait():
    w, h = 100, 150
    drop = 8
    feet = h - (FIELD_H - FEET) + drop
    img = field(w, h + drop).crop((0, 0, w, h))
    for x, y in ((62, 66), (80, 78), (70, 92)):
        img.alpha_composite(sprite("battlefield/enemy_drone_1.png"), (x, y))
    stand(img, sprite("battlefield/enemy_boss_1.png"), 54, feet - 6)
    stand(img, sprite("mech/nuclear.png", NUKE_CELL), -10, feet - 2)
    stand(img, mech_cell(5), -18, feet + 6)
    stand(img, sprite("battlefield/enemy_crawler_1.png"), 62, feet + 6)
    img.alpha_composite(sprite("fx/explosion_big.png", (40, 40), 2), (44, feet - 62))
    img.alpha_composite(sprite("fx/explosion.png", (24, 24), 2), (50, feet - 26))
    img.alpha_composite(upscale(title(), 2), (10, 16))
    save(img, "covers/portrait")


def square():
    w, h = 100, 100
    img = field(w, h + 40).crop((0, 0, w, h))
    for x, y in ((62, 4), (82, 14)):
        img.alpha_composite(sprite("battlefield/enemy_drone_1.png"), (x, y))
    img.alpha_composite(sprite("battlefield/enemy_boss_1.png"), (54, 8))
    img.alpha_composite(sprite("mech/nuclear.png", NUKE_CELL), (-10, 2))
    img.alpha_composite(sprite("fx/explosion_big.png", (40, 40), 2), (38, 14))
    img.alpha_composite(upscale(title(), 2), (10, 50))
    save(img, "covers/square")


def layers():
    save(upscale(title(), 2), "layers/title")
    save(field(240, 135), "layers/background")
    save(sprite("mech/nuclear.png", NUKE_CELL), "layers/nuclear_mech")
    save(sprite("battlefield/enemy_boss_1.png"), "layers/boss")
    save(sprite("fx/explosion_big.png", (40, 40), 2), "layers/explosion")
    save(sprite("fx/explosion.png", (24, 24), 2), "layers/explosion_small")
    for name in ("brute", "crawler", "drone"):
        save(sprite(f"battlefield/enemy_{name}_1.png"), f"layers/{name}")
    for t in range(1, 7):
        save(mech_cell(t), f"layers/mech_{t}")


if __name__ == "__main__":
    landscape()
    portrait()
    square()
    layers()

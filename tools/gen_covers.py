#!/usr/bin/env python3
import os

from PIL import Image

from gen_art import CELL, NUKE_CELL, PARALLAX, mech_cell, title, upscale

ART = "art"
OUT = "release/covers"
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
    os.makedirs(OUT, exist_ok=True)
    upscale(img, SCALE).save(os.path.join(OUT, name + ".png"))


def landscape():
    w, h = 240, 135
    feet = h - (FIELD_H - FEET)
    img = field(w, h)
    stand(img, sprite("battlefield/enemy_boss_1.png"), 166, feet)
    stand(img, sprite("mech/nuclear.png", NUKE_CELL), 92, feet)
    for t, x in ((1, 2), (3, 28), (5, 56)):
        stand(img, mech_cell(t), x, feet + 4)
    img.alpha_composite(sprite("fx/explosion_big.png", (40, 40), 2), (176, feet - 62))
    img.alpha_composite(upscale(title(), 2), (8, 6))
    save(img, "landscape")


def portrait():
    w, h = 100, 150
    feet = h - (FIELD_H - FEET)
    img = field(w, h)
    img.alpha_composite(upscale(title(), 2), (10, 4))
    stand(img, sprite("mech/nuclear.png", NUKE_CELL), 14, feet)
    save(img, "portrait")


def square():
    w, h = 100, 100
    img = field(w, h + 40).crop((0, 0, w, h))
    img.alpha_composite(sprite("mech/nuclear.png", NUKE_CELL), (14, 4))
    img.alpha_composite(upscale(title(), 2), (10, 50))
    save(img, "square")


if __name__ == "__main__":
    landscape()
    portrait()
    square()

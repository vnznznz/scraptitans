#!/usr/bin/env python3
import json
import math
import os
import random

from PIL import Image, ImageDraw

OUT = "art"


def _hex(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


PALETTE = [_hex(h) for h in (
    "be4a2f d77643 ead4aa e4a672 b86f50 733e39 3e2731 a22633 e43b44 f77622 feae34 fee761 63c74d 3e8948 265c42 193c3e "
    "124e89 0099db 2ce8f5 ffffff c0cbdc 8b9bb4 5a6988 3a4466 262b44 181425 ff0044 68386c b55088 f6757a e8b796 c28569"
).split()]
(RUST, RUST_L, CREAM, TAN, BROWN, BROWN_D, BROWN_K, RED_D, RED, ORANGE, GOLD, YELLOW,
 GREEN, GREEN_D, GREEN_K, TEAL_K, BLUE_D, BLUE, CYAN, WHITE, STEEL_L, STEEL, SLATE, SLATE_D, NAVY, INK,
 HOT, PURPLE, MAGENTA, PINK, SKIN, SKIN_D) = PALETTE
CLEAR = (0, 0, 0, 0)

R_RUST = (BROWN_D, RUST, RUST_L)
R_BROWN = (BROWN_K, BROWN_D, BROWN)
R_IRON = (SLATE_D, SLATE, STEEL)
R_STEEL = (SLATE, STEEL, STEEL_L)
R_DARK = (NAVY, SLATE_D, SLATE)
R_BLUE = (BLUE_D, BLUE, CYAN)
R_GOLD = (ORANGE, GOLD, YELLOW)
R_GREEN = (GREEN_K, GREEN_D, GREEN)
R_CERAMIC = (STEEL, CREAM, WHITE)
R_TAN = (BROWN_D, SKIN_D, TAN)
R_RED = (RED_D, RED, PINK)
R_PURPLE = (NAVY, PURPLE, MAGENTA)


def new(w, h):
    img = Image.new("RGBA", (w, h), CLEAR)
    return img, ImageDraw.Draw(img)


def save(img, path):
    full = os.path.join(OUT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    img.save(full)


def rect(d, x0, y0, x1, y1, c):
    if x1 >= x0 and y1 >= y0:
        d.rectangle([x0, y0, x1, y1], fill=c)


def px(d, x, y, c):
    d.point((x, y), fill=c)


def sbox(d, x0, y0, x1, y1, ramp, outline=INK):
    dark, mid, light = ramp
    if outline:
        rect(d, x0, y0, x1, y1, outline)
        x0, y0, x1, y1 = x0 + 1, y0 + 1, x1 - 1, y1 - 1
    rect(d, x0, y0, x1, y1, mid)
    if y1 > y0:
        rect(d, x0, y0, x1, y0, light)
    if y1 - y0 >= 2:
        rect(d, x0, y1, x1, y1, dark)
    if x1 - x0 >= 3 and y1 - y0 >= 2:
        rect(d, x1, y0 + 1, x1, y1, dark)


def blob(d, x0, y0, x1, y1, ramp, outline=INK):
    sbox(d, x0, y0, x1, y1, ramp, outline)
    for x, y in [(x0, y0), (x1, y0), (x0, y1), (x1, y1)]:
        px(d, x, y, CLEAR)


def disc(d, cx, cy, r, fill, outline=INK):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline)


def hazard(d, x0, y0, x1, y1, a=YELLOW, b=INK, step=2):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            px(d, x, y, a if ((x + y) // step) % 2 == 0 else b)


def outline(img, color=INK):
    src = img.copy().load()
    w, h = img.size
    out = img.load()
    for x in range(w):
        for y in range(h):
            if src[x, y][3]:
                continue
            for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] and src[nx, ny] != color:
                    out[x, y] = color
                    break


# Mechs: one cell per frame tier; frame sheets hold 4 walk frames, other parts one cell per frame tier.

CELL = (40, 48)
FRAME_GEOM = [
    (13, 10, 8, 3),
    (15, 10, 9, 3),
    (16, 11, 10, 4),
    (18, 12, 11, 4),
    (22, 14, 13, 5),
    (26, 16, 15, 6),
]
NUKE_CELL = (72, 88)
NUKE_GEOM = (40, 24, 24, 9)
WALK = [(0, 0, 0, 0, 0), (2, 0, -2, 1, 1), (0, 0, 0, 0, 0), (-2, 1, 2, 0, 1)]
FRAME_STYLE = [
    (R_RUST, R_BROWN),
    (R_IRON, R_DARK),
    (R_STEEL, R_IRON),
    (R_BLUE, R_DARK),
    (R_GOLD, R_DARK),
    (R_GREEN, (INK, NAVY, SLATE_D)),
]


def torso_box(cell, geom, bob=0):
    w, h = cell
    tw, th, lh, _ = geom
    cx = w // 2
    x0 = cx - tw // 2
    y1 = h - 1 - lh - bob
    return x0, y1 - th + 1, x0 + tw - 1, y1


def leg(d, hx, hip, lw, lh, ground, dx, lift, ramp, knee_fwd):
    knee = hip + lh // 2
    sbox(d, hx - 1, hip - 1, hx + lw, knee + 1, ramp)
    sx = hx + dx // 2
    sbox(d, sx - 1, knee, sx + lw, ground - 1 - lift, ramp)
    if knee_fwd:
        sbox(d, sx + lw - 1, knee - 1, sx + lw + 1, knee + 2, ramp)
    elif lw >= 4:
        sbox(d, sx, knee - 1, sx + lw - 1, knee + 1, (ramp[0], ramp[2], ramp[2]))
    fx = hx + dx
    sbox(d, fx - 2, ground - 2 - lift, fx + lw + 2, ground - lift, ramp)


def draw_frame(d, t, cell, geom, f):
    body, legs = FRAME_STYLE[t]
    tw, th, lh, lw = geom
    w, h = cell
    ground = h - 1
    dx_back, lift_back, dx_front, lift_front, bob = WALK[f]
    x0, y0, x1, y1 = torso_box(cell, geom, bob)
    hip = y1 - 1
    dark_legs = tuple(tuple(max(0, int(c * 0.72)) for c in col[:3]) + (255,) for col in legs)
    leg(d, x0 + 1, hip, lw, h - 1 - hip - bob, ground, dx_back, lift_back, dark_legs, t == 3)
    sbox(d, x0 + 2, y1 - 1, x1 - 2, y1 + 2, legs)
    leg(d, x1 - lw - 1, hip, lw, h - 1 - hip - bob, ground, dx_front, lift_front, legs, t == 3)

    if t == 4 or t == 5:
        for i, ex in enumerate([x0 + 1, x0 + 4]):
            top = y0 - 4 - i * 2 - t % 2
            sbox(d, ex, top, ex + 2, y0 + 1, R_DARK)
            if t == 5:
                rect(d, ex + 1, top - 1, ex + 1, top, YELLOW)
    if t == 3:
        sbox(d, x0, y0, x1, y1, body)
        for x in [x0, x1]:
            px(d, x, y1, CLEAR)
            px(d, x, y1 - 1, INK)
        px(d, x0 + 1, y1, INK)
        px(d, x1 - 1, y1, INK)
    elif t == 2:
        blob(d, x0, y0, x1, y1, body)
    else:
        sbox(d, x0, y0, x1, y1, body)
    dark, mid, light = body
    if t == 0:
        rect(d, x0 + 2, y0 + 3, x0 + 4, y1 - 2, SLATE)
        px(d, x0 + 3, y0 + 4, STEEL)
        rect(d, x1 - 4, y0 + 2, x1 - 2, y0 + 2, dark)
        for x in (x0 + 6, x1 - 2):
            px(d, x, y1 - 2, BROWN_K)
    elif t == 1:
        for x, y in [(x0 + 1, y0 + 1), (x1 - 1, y0 + 1), (x0 + 1, y1 - 1), (x1 - 1, y1 - 1)]:
            px(d, x, y, STEEL_L)
        rect(d, x0 + 1, (y0 + y1) // 2, x1 - 1, (y0 + y1) // 2, dark)
    elif t == 2:
        for i in range(3):
            rect(d, x0 + 4, y0 + 3 + i * 2, x1 - 4, y0 + 3 + i * 2, SLATE)
    elif t == 3:
        rect(d, x0 + 1, y0 + 3, x1 - 1, y0 + 4, BLUE_D)
        rect(d, x1 - 6, y0 + 3, x1 - 2, y0 + 3, CYAN)
        rect(d, x0 + 3, y1 - 3, x1 - 3, y1 - 3, BLUE_D)
    elif t == 4:
        hazard(d, x0 + 1, y1 - 3, x1 - 1, y1 - 1)
        for x in (x0 + 2, x1 - 2):
            px(d, x, y0 + 2, ORANGE)
            px(d, x, y0 + 6, ORANGE)
        rect(d, x0 + 6, y0 + 3, x1 - 6, y0 + 3, ORANGE)
    elif t == 5:
        cx, cy = (x0 + x1) // 2 + 1, (y0 + y1) // 2
        disc(d, cx, cy, 4, GREEN_K)
        disc(d, cx, cy, 2, YELLOW, outline=GREEN)
        px(d, cx, cy, WHITE)
        for y in range(y0 + 3, y1 - 1, 2):
            rect(d, x0 + 2, y, x0 + 5, y, GREEN_K)
            rect(d, x1 - 4, y, x1 - 2, y, GREEN_K)
        hazard(d, x0 + 1, y1 - 2, x1 - 1, y1 - 1, YELLOW, INK)


def head_size(c, t):
    bw = [8, 9, 9, 10, 10, 12][c]
    bh = [7, 6, 8, 7, 8, 9][c]
    if t == "nuke":
        return bw + 6, bh + 4
    return bw + [0, 0, 1, 1, 2, 3][t], bh + [0, 0, 0, 1, 1, 2][t]


def draw_core(d, c, anchor, size):
    ax, ay = anchor
    hw, hh = size
    x0 = ax - hw // 2
    x1 = x0 + hw - 1
    y1 = ay + 1
    y0 = y1 - hh + 1
    ex = x1 - max(2, hw // 4)
    ey = y0 + hh // 2 - 1
    if c == 0:
        sbox(d, x0, y0, x1, y1, R_RUST)
        rect(d, x0, y0, x0, y0, CLEAR)
        rect(d, x0 + 1, y1 - 2, x1 - 1, y1 - 2, BROWN_D)
        rect(d, ex - 1, ey, ex, ey + 1, RED)
        px(d, ex, ey, HOT)
        d.line([x0 + 2, y0 - 1, x0, y0 - 3], fill=INK)
        px(d, x0, y0 - 4, RED)
    elif c == 1:
        sbox(d, x0, y0, x1, y1, R_IRON)
        rect(d, x0 + 2, ey, x1 - 1, ey + 1, INK)
        px(d, ex, ey, GREEN)
        px(d, ex - 2, ey, GREEN)
        rect(d, x0 + 2, y0 - 3, x0 + 2, y0 - 1, INK)
        rect(d, x0 + 1, y0 - 5, x0 + 3, y0 - 3, RED)
        px(d, x0 + 1, y0 - 5, CLEAR)
        px(d, x0 + 3, y0 - 5, CLEAR)
        px(d, x0 + 2, y0 - 5, PINK)
    elif c == 2:
        mid = y0 + hh // 2
        sbox(d, x0, mid, x1, y1, R_STEEL)
        d.ellipse([x0 + 1, y0 - 1, x1 - 1, mid + 2], fill=(192, 203, 220, 255), outline=INK)
        rect(d, x0 + 1, mid + 1, x1 - 1, mid + 1, INK)
        cx = (x0 + x1) // 2
        rect(d, cx - 1, y0 + 2, cx + 1, mid, ORANGE)
        rect(d, cx, y0 + 2, cx, mid - 1, YELLOW)
        px(d, x0 + 3, y0 + 1, WHITE)
        rect(d, ex, mid + 2, x1 - 1, mid + 2, YELLOW)
    elif c == 3:
        blob(d, x0, y0, x1, y1, R_BLUE)
        rect(d, (x0 + x1) // 2, ey, x1, ey + 1, INK)
        rect(d, (x0 + x1) // 2 + 1, ey, x1 - 1, ey, CYAN)
        px(d, x0 + 2, y1 - 2, CYAN)
        px(d, x0 + 4, y1 - 2, CYAN)
        rect(d, x0 + 2, y0 - 2, x0 + 2, y0, INK)
    elif c == 4:
        sbox(d, x0, y0, x1, y1, R_GOLD)
        rect(d, x0, y0, x0, y0, CLEAR)
        rect(d, x1, y0, x1, y0, CLEAR)
        cx = (x0 + x1) // 2
        disc(d, cx, y0 - 3, 2, MAGENTA)
        px(d, cx - 1, y0 - 4, PINK)
        rect(d, cx, y0 - 1, cx, y0, PURPLE)
        rect(d, ex - 1, ey, x1 - 1, ey + 1, PURPLE)
        px(d, ex, ey, MAGENTA)
        rect(d, x0 + 1, y1 - 2, x1 - 1, y1 - 2, ORANGE)
    elif c == 5:
        sbox(d, x0, y0, x1, y1, (INK, NAVY, SLATE_D))
        for hx in (x0 + 1, x1 - 2):
            rect(d, hx, y0 - 3, hx + 1, y0 - 1, SLATE_D)
            px(d, hx + (0 if hx == x0 + 1 else 1), y0 - 4, STEEL)
        rect(d, ex - 3, ey, ex - 2, ey + 1, RED_D)
        rect(d, ex, ey, ex + 1, ey + 1, RED_D)
        px(d, ex - 2, ey, HOT)
        px(d, ex + 1, ey, HOT)
        for x in range(x0 + 3, x1, 2):
            px(d, x, y1 - 1, STEEL)


def draw_arms(d, a, shoulder, t):
    sx, sy = shoulder
    big = t == "nuke"
    ln = 10 if big else [0, 1, 2, 3, 4, 6][t]
    k = 2 if big else [0, 0, 0, 1, 1, 1][t]
    if a == 0:
        sbox(d, sx - 2, sy - 1, sx + 1, sy + 3, R_BROWN)
        end = sx + 8 + ln
        sbox(d, sx + 1, sy, end, sy + 2 + k, R_RUST)
        rect(d, end - 1, sy, end, sy + 2 + k, INK)
        px(d, sx + 4, sy + 1, BROWN_D)
        return end + 1, sy + 1 + k // 2
    if a == 1:
        sbox(d, sx - 2, sy - 2, sx + 2, sy + 3, R_DARK)
        end = sx + 7 + ln
        sbox(d, sx + 2, sy - 1, end, sy + 3 + k, R_IRON)
        sbox(d, end - 2, sy - 2, end + 1, sy + 4 + k, R_IRON)
        for x in range(sx + 4, end - 2, 3):
            px(d, x, sy, STEEL_L)
        return end + 2, sy + 1 + k // 2
    if a == 2:
        sbox(d, sx - 2, sy - 2, sx + 5, sy + 3 + k, R_STEEL)
        end = sx + 12 + ln
        for by in (sy - 1, sy + 2 + k):
            rect(d, sx + 6, by - 1, end, by + 1, INK)
            rect(d, sx + 6, by, end - 1, by, STEEL_L)
        disc(d, sx + 1, sy + 6 + k, 2 + k, SLATE_D)
        px(d, sx + 1, sy + 6 + k, STEEL)
        return end + 1, sy + k // 2
    if a == 3:
        pw, ph = 8 + k * 2, 7 + k * 2
        sbox(d, sx - 1, sy - 2, sx + 2, sy + 2, R_DARK)
        x0, y0 = sx + 1 + ln // 2, sy - ph + 2
        sbox(d, x0, y0, x0 + pw, y0 + ph, R_BLUE)
        for i in range(2):
            for j in range(2):
                tx, ty = x0 + pw - 1, y0 + 2 + j * (ph // 2 - 1)
                px(d, tx, ty, RED)
                px(d, tx, ty + 1, RED_D)
                px(d, tx + 1, ty, WHITE) if i == 0 else None
        rect(d, x0 + 1, y0 + ph // 2, x0 + pw - 2, y0 + ph // 2, BLUE_D)
        return x0 + pw + 2, y0 + ph // 2
    if a == 4:
        end = sx + 14 + ln
        sbox(d, sx - 2, sy - 2, sx + 4, sy + 4 + k, R_DARK)
        sbox(d, sx + 3, sy - 2, end, sy, R_GOLD)
        sbox(d, sx + 3, sy + 3 + k, end, sy + 5 + k, R_GOLD)
        rect(d, sx + 5, sy + 1, end - 1, sy + 2 + k, CYAN)
        rect(d, sx + 5, sy + 1, end - 1, sy + 1, WHITE)
        return end + 1, sy + 1 + k // 2
    # Atomic Missile launcher
    ml = (22 if big else 11 + ln)
    mh = (6 if big else 3 + k)
    y0 = sy - mh - 2
    sbox(d, sx - 2, sy - 2, sx + ml - 4, sy + 1, R_GREEN)
    bx0 = sx - 3
    tip = bx0 + ml
    sbox(d, bx0 + 2, y0, tip - 2, y0 + mh, (STEEL, STEEL_L, WHITE))
    d.polygon([(tip - 2, y0), (tip + 1, y0 + mh // 2), (tip + 1, y0 + (mh + 1) // 2), (tip - 2, y0 + mh)], fill=RED, outline=INK)
    rect(d, bx0 + 5, y0 + 1, bx0 + 6, y0 + mh - 1, YELLOW)
    d.polygon([(bx0 + 3, y0), (bx0, y0 - 2), (bx0, y0 + mh + 2), (bx0 + 3, y0 + mh)], fill=RED_D, outline=INK)
    rect(d, bx0 - 1, y0 + mh // 2 - 1, bx0, y0 + mh // 2 + 1, ORANGE) if big else None
    return tip + 1, y0 + mh // 2


def draw_plating(d, p, box, t):
    x0, y0, x1, y1 = box
    big = t == "nuke"
    s = 3 if big else [0, 0, 1, 1, 2, 2][t]
    cx = (x0 + x1) // 2
    if p == 0:
        sbox(d, x0 + 2, y0 + 2, cx + 1, y1 - 1, (SLATE, STEEL, STEEL_L))
        px(d, x0 + 3, y0 + 3, INK)
        px(d, cx, y1 - 2, INK)
        sbox(d, x1 - 4 - s, y0 - 1, x1 + 1, y0 + 2 + s, (SLATE, STEEL, STEEL_L))
    elif p == 1:
        sbox(d, x0 + 1, y0 + 2, x1 - 2, y1 - 1, R_BROWN)
        for x in range(x0 + 3, x1 - 2, 3):
            px(d, x, y0 + 4, TAN)
            px(d, x, y1 - 3, TAN)
        for sx in (x0 - 1, x1 - 4 - s):
            blob(d, sx, y0 - 1, sx + 5 + s, y0 + 3 + s, R_RUST)
    elif p == 2:
        sbox(d, x0 + 2, y1 - 4, x1 - 2, y1 + 1, R_STEEL)
        for sx in (x0 - 2, x1 - 5 - s):
            blob(d, sx, y0 - 2, sx + 7 + s, y0 + 4 + s, R_STEEL)
            px(d, sx + 2, y0, WHITE)
    elif p == 3:
        blob(d, x0 + 1, y0 + 2, x1 - 1, (y0 + y1) // 2 + 2, R_CERAMIC)
        rect(d, cx, y0 + 3, cx, (y0 + y1) // 2 + 1, STEEL)
        for sx in (x0 - 2, x1 - 5 - s):
            blob(d, sx, y0 - 2, sx + 7 + s, y0 + 5 + s, R_CERAMIC)
            rect(d, sx + 1, y0 + 2 + s, sx + 6 + s, y0 + 2 + s, SLATE)
    elif p == 4:
        for row in range(2):
            by = y0 + 2 + row * 4
            for bx in range(x0 + 1 + row * 2, x1 - 3, 5):
                sbox(d, bx, by, bx + 4, by + 3, R_TAN)
        for sx in (x0 - 3, x1 - 5 - s):
            sbox(d, sx, y0 - 3, sx + 8 + s, y0 + 1, R_TAN)
            sbox(d, sx, y0 + 1, sx + 8 + s, y0 + 4 + s, R_TAN)
            px(d, sx + 2, y0 - 1, CREAM)
    elif p == 5:
        slab = (SLATE_D, SLATE, STEEL)
        sbox(d, x0 + 1, y0 + 1, x1 - 1, (y0 + y1) // 2 + 2, slab)
        for sx in (x0 - 4, x1 - 5 - s):
            blob(d, sx, y0 - 3, sx + 9 + s, y0 + 5 + s, slab)
            hazard(d, sx + 1, y0 + 2 + s, sx + 8 + s, y0 + 4 + s)
        cy = (y0 + y1) // 2 - 1
        disc(d, cx, cy, 3 + s // 2, YELLOW)
        px(d, cx, cy, INK)
        for ddx, ddy in [(-1, -2), (1, -2), (-2, 1), (2, 1), (0, 2)][: 3 + s]:
            px(d, cx + ddx, cy + ddy, INK)


def draw_silo(d, x, top, bottom):
    sbox(d, x - 1, top + 8, x + 12, bottom, R_GREEN)
    hazard(d, x, bottom - 4, x + 11, bottom - 1)
    sbox(d, x + 2, top + 4, x + 9, top + 20, (STEEL, STEEL_L, WHITE))
    d.polygon([(x + 2, top + 4), (x + 5, top), (x + 6, top), (x + 9, top + 4)], fill=RED, outline=INK)
    rect(d, x + 3, top + 9, x + 8, top + 10, YELLOW)
    rect(d, x + 3, top + 13, x + 8, top + 13, INK)
    return x + 5, top


def rig_point(cell, x, y):
    return [x - cell[0] // 2, y - cell[1]]


def mech():
    rig = {"chest": [], "top": [], "muzzle": []}
    w, h = CELL
    for t in range(6):
        geom = FRAME_GEOM[t]
        sheet = Image.new("RGBA", (w * 4, h), CLEAR)
        for f in range(4):
            img, d = new(w, h)
            draw_frame(d, t, CELL, geom, f)
            sheet.paste(img, (f * w, 0))
        save(sheet, f"mech/frame_{t + 1}.png")
        x0, y0, x1, y1 = torso_box(CELL, geom)
        rig["chest"].append(rig_point(CELL, (x0 + x1) // 2, (y0 + y1) // 2))
        rig["top"].append(rig_point(CELL, (x0 + x1) // 2, y0 - 12 - t))
        rig["muzzle"].append([None] * 6)

    for kind in ("core", "arms", "plating"):
        for tier in range(6):
            sheet = Image.new("RGBA", (w * 6, h), CLEAR)
            for t in range(6):
                img, d = new(w, h)
                box = torso_box(CELL, FRAME_GEOM[t])
                x0, y0, x1, y1 = box
                if kind == "core":
                    draw_core(d, tier, ((x0 + x1) // 2, y0), head_size(tier, t))
                elif kind == "arms":
                    m = draw_arms(d, tier, (x1 - 1, y0 + 3), t)
                    rig["muzzle"][t][tier] = rig_point(CELL, *m)
                else:
                    draw_plating(d, tier, box, t)
                sheet.paste(img, (t * w, 0))
            save(sheet, f"mech/{kind}_{tier + 1}.png")

    nw, nh = NUKE_CELL
    sheet = Image.new("RGBA", (nw * 4, nh), CLEAR)
    for f in range(4):
        img, d = new(nw, nh)
        bob = WALK[f][4]
        box = torso_box(NUKE_CELL, NUKE_GEOM, bob)
        x0, y0, x1, y1 = box
        tip = draw_silo(d, x0 + 4, y0 - 30, y0 + 8)
        draw_frame(d, 5, NUKE_CELL, NUKE_GEOM, f)
        cx, cy = (x0 + x1) // 2 + 3, (y0 + y1) // 2 + 1
        disc(d, cx, cy, 6, GREEN_K)
        disc(d, cx, cy, 4, YELLOW, outline=GREEN)
        disc(d, cx, cy, 2, WHITE, outline=None)
        for sx in (x0 - 5, x1 - 9):
            blob(d, sx, y0 - 4, sx + 13, y0 + 7, R_GREEN)
            hazard(d, sx + 1, y0 + 3, sx + 12, y0 + 6)
        draw_core(d, 5, ((x0 + x1) // 2 + 2, y0), head_size(5, "nuke"))
        draw_arms(d, 4, (x1 - 3, y0 + 10), "nuke")
        if f == 0:
            rig["nuke_muzzle"] = rig_point(NUKE_CELL, *tip)
            rig["nuke_chest"] = rig_point(NUKE_CELL, cx, cy)
        sheet.paste(img, (f * nw, 0))
    save(sheet, "mech/nuclear.png")
    with open(os.path.join(OUT, "mech/rig.json"), "w") as fh:
        json.dump(rig, fh)
    crowd()


CROWD_CELL = (16, 24)


def crowd():
    w, h = CROWD_CELL
    sheet = Image.new("RGBA", (w * 2, h * 6), CLEAR)
    for t in range(6):
        ramp = FRAME_STYLE[t][0]
        tw, th, lh = 5 + t, 5 + t // 2, 4 + t
        for f in range(2):
            img, d = new(w, h)
            cx, ground = 7 - t // 3, h - 1
            top = ground - lh - th - f
            for lx, lift in ((cx - tw // 2 + 1, f), (cx + tw // 2 - 2, 0)):
                rect(d, lx, ground - lh - f, lx + 1, ground - lift, ramp[0])
            sbox(d, cx - tw // 2, top, cx + tw // 2, top + th, ramp)
            rect(d, cx - 1, top - 2, cx + 1, top, ramp[2])
            px(d, cx + 1, top - 1, YELLOW)
            rect(d, cx + tw // 2, top + 2, cx + tw // 2 + 3 + t // 2, top + 2 + t // 3, SLATE_D)
            outline(img)
            sheet.paste(img, (f * w, t * h))
    save(sheet, "mech/crowd.png")


def cloud(d, cx, cy, r, rnd, fill, shade=None, n=5):
    for _ in range(n):
        a = rnd.random() * math.tau
        dist = rnd.random() * r * 0.6
        rr = max(1, int(r * (0.45 + rnd.random() * 0.35)))
        x, y = cx + math.cos(a) * dist, cy + math.sin(a) * dist
        if shade:
            d.ellipse([x - rr, y - rr + 1, x + rr, y + rr + 1], fill=shade)
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=fill)


def explosion_sheet(size, path, seed):
    rnd = random.Random(seed)
    sheet = Image.new("RGBA", (size * 6, size), CLEAR)
    c = size / 2
    r = size / 2 - 1
    for f in range(6):
        img, d = new(size, size)
        if f == 0:
            disc(d, c, c, r * 0.35, YELLOW, outline=None)
            disc(d, c, c, r * 0.2, WHITE, outline=None)
        elif f == 1:
            cloud(d, c, c, r * 0.75, rnd, ORANGE, n=6)
            cloud(d, c, c, r * 0.5, rnd, YELLOW, n=4)
            disc(d, c, c, r * 0.2, WHITE, outline=None)
        elif f == 2:
            cloud(d, c, c - 1, r * 0.95, rnd, RUST, n=7)
            cloud(d, c, c - 1, r * 0.75, rnd, ORANGE, n=6)
            cloud(d, c, c - 2, r * 0.45, rnd, YELLOW, n=4)
        elif f == 3:
            cloud(d, c, c - 2, r * 0.95, rnd, SLATE_D, n=7)
            cloud(d, c, c - 2, r * 0.7, rnd, RUST, n=6)
            cloud(d, c, c - 3, r * 0.4, rnd, ORANGE, n=3)
        elif f == 4:
            cloud(d, c, c - 3, r * 0.9, rnd, SLATE_D, SLATE_D, n=6)
            cloud(d, c, c - 4, r * 0.6, rnd, SLATE, n=5)
            for _ in range(4):
                px(d, rnd.randint(2, size - 3), rnd.randint(2, size - 3), ORANGE)
        else:
            cloud(d, c, c - 5, r * 0.7, rnd, SLATE_D, n=4)
        sheet.paste(img, (f * size, 0))
    save(sheet, path)


def fx():
    img, d = new(3, 2)
    rect(d, 0, 0, 2, 1, GOLD)
    rect(d, 2, 0, 2, 1, YELLOW)
    px(d, 0, 0, ORANGE)
    save(img, "fx/shot_1.png")

    img, d = new(5, 3)
    rect(d, 1, 0, 3, 2, ORANGE)
    rect(d, 0, 1, 4, 1, GOLD)
    rect(d, 3, 1, 4, 1, YELLOW)
    px(d, 4, 1, WHITE)
    save(img, "fx/shot_2.png")

    img, d = new(8, 1)
    for x, c in enumerate([RUST, ORANGE, ORANGE, GOLD, GOLD, YELLOW, YELLOW, WHITE]):
        px(d, x, 0, c[:3] + (min(255, 60 + x * 40),))
    save(img, "fx/shot_3.png")

    img, d = new(9, 3)
    px(d, 0, 1, GOLD)
    px(d, 1, 1, YELLOW)
    rect(d, 2, 0, 6, 2, STEEL_L)
    rect(d, 2, 2, 6, 2, STEEL)
    rect(d, 7, 0, 7, 2, RED)
    px(d, 8, 1, RED)
    px(d, 2, 0, SLATE)
    px(d, 2, 2, SLATE)
    save(img, "fx/shot_4.png")

    img, d = new(1, 3)
    px(d, 0, 0, CYAN[:3] + (160,))
    px(d, 0, 1, WHITE)
    px(d, 0, 2, CYAN[:3] + (160,))
    save(img, "fx/beam.png")

    img, d = new(6, 6)
    d.polygon([(0, 2), (2, 0), (5, 2), (5, 3), (2, 5), (0, 3)], fill=GOLD)
    rect(d, 1, 2, 3, 3, YELLOW)
    px(d, 1, 2, WHITE)
    save(img, "fx/muzzle.png")

    img, d = new(10, 8)
    d.polygon([(0, 3), (3, 0), (5, 2), (9, 3), (9, 4), (5, 5), (3, 7), (0, 4)], fill=ORANGE)
    d.polygon([(1, 3), (3, 2), (7, 3), (7, 4), (3, 5), (1, 4)], fill=YELLOW)
    rect(d, 1, 3, 3, 4, WHITE)
    save(img, "fx/muzzle_big.png")

    img, d = new(5, 5)
    rect(d, 2, 0, 2, 4, YELLOW)
    rect(d, 0, 2, 4, 2, YELLOW)
    px(d, 2, 2, WHITE)
    save(img, "fx/hit.png")

    img, d = new(3, 3)
    rect(d, 0, 1, 2, 1, WHITE)
    rect(d, 1, 0, 1, 2, WHITE)
    save(img, "fx/smoke_small.png")

    img, d = new(16, 16)
    rnd = random.Random(5)
    cloud(d, 8, 8, 7, rnd, WHITE, STEEL_L, n=6)
    save(img, "fx/puff.png")

    img, d = new(2, 2)
    rect(d, 0, 0, 1, 1, WHITE)
    save(img, "fx/spark.png")

    img, d = new(4, 4)
    sbox(d, 0, 0, 3, 3, R_IRON)
    save(img, "fx/debris.png")

    img, d = new(8, 6)
    d.polygon([(0, 2), (3, 0), (7, 1), (6, 5), (1, 5)], fill=RUST, outline=INK)
    rect(d, 2, 2, 4, 2, RUST_L)
    save(img, "fx/debris_big.png")

    explosion_sheet(24, "fx/explosion.png", 21)
    explosion_sheet(40, "fx/explosion_big.png", 22)

    img, d = new(3, 3)
    rect(d, 0, 1, 2, 1, RED)
    rect(d, 1, 0, 1, 2, RED)
    px(d, 1, 1, PINK)
    save(img, "fx/enemy_shot_drone.png")

    img, d = new(5, 3)
    rect(d, 1, 0, 4, 2, RED)
    rect(d, 0, 1, 1, 1, ORANGE)
    rect(d, 1, 1, 3, 1, PINK)
    save(img, "fx/enemy_shot_crawler.png")

    img, d = new(6, 6)
    disc(d, 2.5, 2.5, 2.5, HOT, outline=None)
    rect(d, 2, 2, 3, 3, PINK)
    px(d, 2, 2, WHITE)
    save(img, "fx/enemy_shot_brute.png")


SKY_BANDS = [(0, NAVY), (30, PURPLE), (62, MAGENTA), (94, RUST_L)]
HORIZON = 110


def sky(d, w, top, bottom):
    for y in range(top, bottom):
        band = [c for start, c in SKY_BANDS if start <= y][-1]
        nxt = [(start, c) for start, c in SKY_BANDS if start > y]
        for x in range(w):
            c = band
            if nxt and nxt[0][0] - y <= 2 and (x + y) % (nxt[0][0] - y + 1) == 0:
                c = nxt[0][1]
            px(d, x, y, c)


# Battlefield: layers scroll left as the front advances (one step per cleared wave, see Battlefield.front_offset).
# A layer at parallax r is BG_W + TRAVEL * r wide; stages by the front offset at which a spot is mid-screen.

BG_W = 360
TRAVEL = 1080
STAGES = [250, 600, 880]
PARALLAX = {"far": 0.3, "near": 0.6, "ground": 1.0}


def stage_at(x, ratio, jitter=0):
    front = (x - BG_W / 2) / ratio + jitter
    return sum(1 for s in STAGES if front >= s)


def layer_w(ratio):
    return BG_W + int(TRAVEL * ratio)


def far_layer():
    r = PARALLAX["far"]
    w = layer_w(r)
    img, d = new(w, HORIZON)
    rnd = random.Random(31)
    x = -4
    while x < w:
        st = stage_at(x, r, rnd.randint(-40, 40))
        if st == 0:
            bw, bh = rnd.randint(10, 26), rnd.randint(10, 30)
        elif st == 1:
            bw, bh = rnd.randint(8, 18), rnd.randint(22, 50)
        elif st == 2:
            bw, bh = rnd.randint(14, 30), rnd.randint(12, 24)
        else:
            bw, bh = rnd.randint(18, 30), 24
        top = HORIZON - bh
        rect(d, x, top, x + bw, HORIZON, PURPLE)
        if st <= 1:
            for k in range(rnd.randint(1, 3)):
                cx = x + rnd.randint(0, bw)
                rect(d, cx, top - rnd.randint(1, 4), cx + rnd.randint(1, 3), top, PURPLE)
            for _ in range(rnd.randint(0, 3) + 2 * st):
                c = MAGENTA if st == 0 or rnd.random() < 0.6 else ORANGE
                px(d, x + rnd.randint(2, max(2, bw - 2)), top + rnd.randint(3, bh - 2), c)
        elif st == 2:
            if rnd.random() < 0.7:
                cx = x + rnd.randint(2, bw - 4)
                ch = rnd.randint(34, 58)
                rect(d, cx, HORIZON - ch, cx + rnd.randint(2, 3), HORIZON, PURPLE)
                px(d, cx + 1, HORIZON - ch, ORANGE)
            if rnd.random() < 0.4:
                tx = x + rnd.randint(0, bw)
                d.polygon([(tx, HORIZON), (tx + 3, HORIZON - 30), (tx + 15, HORIZON - 30), (tx + 18, HORIZON)], fill=PURPLE)
            for _ in range(rnd.randint(1, 3)):
                px(d, x + rnd.randint(2, max(2, bw - 2)), top + rnd.randint(2, bh - 2), ORANGE)
        else:
            for k in range(x, x + bw, 4):
                rect(d, k, top - 2, k + 1, top, PURPLE)
            tx = x + rnd.randint(0, bw - 8)
            th = rnd.randint(38, 52)
            rect(d, tx, HORIZON - th, tx + 8, HORIZON, PURPLE)
            rect(d, tx - 1, HORIZON - th, tx + 9, HORIZON - th + 1, PURPLE)
            px(d, tx + 4, HORIZON - th + 4, RED)
        x += bw + rnd.randint(-3, 2)
    save(img, "battlefield/far.png")


def tower(d, sx, sh):
    rect(d, sx, HORIZON - sh, sx + 5, HORIZON, NAVY)
    rect(d, sx - 1, HORIZON - sh, sx + 6, HORIZON - sh + 1, NAVY)
    px(d, sx + 2, HORIZON - sh + 6, ORANGE)


def ruin(d, rnd, bx, bw, bh, lit):
    top = HORIZON - bh
    rect(d, bx, top, bx + bw, HORIZON, NAVY)
    for k in range(0, bw, 6):
        rect(d, bx + k, top - rnd.randint(0, 3), bx + k + 3, top, NAVY)
    for _ in range(lit):
        px(d, bx + rnd.randint(2, bw - 2), top + rnd.randint(4, bh - 2), GOLD if rnd.random() < 0.4 else ORANGE)


def burning(d, rnd, bx, bw, bh):
    top = HORIZON - bh
    cut = rnd.randint(4, bh // 2)
    left = rnd.random() < 0.5
    cl, cr = (cut, 0) if left else (0, cut)
    d.polygon([(bx, HORIZON), (bx, top + cl), (bx + bw // 2, top), (bx + bw, top + cr), (bx + bw, HORIZON)], fill=NAVY)
    for wy in range(top + 4, HORIZON - 4, 5):
        for wx in range(bx + 3, bx + bw - 2, 4):
            if rnd.random() < 0.15 and wy > top + max(cl, cr) + 2:
                rect(d, wx, wy, wx + 1, wy + 1, ORANGE if rnd.random() < 0.6 else GOLD)
    for _ in range(rnd.randint(2, 4)):
        fx_ = bx + rnd.randint(1, bw // 2)
        px(d, fx_, top - 1, ORANGE)
        px(d, fx_, top - 2, YELLOW if rnd.random() < 0.5 else ORANGE)


def plant(d, rnd, bx, bw):
    kind = rnd.random()
    if kind < 0.35:
        r = rnd.randint(8, 12)
        d.ellipse([bx, HORIZON - 2 * r, bx + 2 * r, HORIZON + 2 * r], fill=NAVY)
        rect(d, bx + r - 1, HORIZON - 2 * r - 3, bx + r + 1, HORIZON - 2 * r, NAVY)
        px(d, bx + r, HORIZON - 2 * r - 3, RED)
    elif kind < 0.7:
        h = rnd.randint(20, 28)
        rect(d, bx, HORIZON - h, bx + bw, HORIZON, NAVY)
        for k in range(bx, bx + bw - 5, 7):
            d.polygon([(k, HORIZON - h), (k + 6, HORIZON - h - 5), (k + 6, HORIZON - h)], fill=NAVY)
        for _ in range(3):
            px(d, bx + rnd.randint(2, bw - 2), HORIZON - rnd.randint(4, h - 3), GOLD)
    else:
        h = rnd.randint(40, 56)
        rect(d, bx, HORIZON - h, bx + 4, HORIZON, NAVY)
        for k in range(HORIZON - h + 3, HORIZON - h + 12, 4):
            rect(d, bx, k, bx + 4, k + 1, RED_D)
        px(d, bx + 2, HORIZON - h - 1, ORANGE)
    py = HORIZON - rnd.randint(6, 10)
    rect(d, bx - 6, py, bx + bw + 6, py + 1, NAVY)
    for k in range(bx - 6, bx + bw + 6, 9):
        rect(d, k, py, k, HORIZON, NAVY)


def wall(d, rnd, bx, bw):
    top = HORIZON - 30
    rect(d, bx, top, bx + bw, HORIZON, NAVY)
    for k in range(bx, bx + bw, 5):
        rect(d, k, top - 3, k + 2, top, NAVY)
    for k in range(bx + 4, bx + bw - 3, 9):
        rect(d, k, top + 8, k + 2, top + 8, RED)


def citadel(d, cx):
    base = HORIZON
    rect(d, cx - 36, base - 52, cx + 36, base, NAVY)
    for k in range(cx - 36, cx + 36, 6):
        rect(d, k, base - 56, k + 3, base - 52, NAVY)
    rect(d, cx - 14, base - 84, cx + 14, base - 52, NAVY)
    d.polygon([(cx - 14, base - 84), (cx, base - 96), (cx + 14, base - 84)], fill=NAVY)
    rect(d, cx, base - 104, cx, base - 96, NAVY)
    px(d, cx, base - 105, RED)
    rect(d, cx - 6, base - 74, cx - 3, base - 72, RED)
    rect(d, cx + 3, base - 74, cx + 6, base - 72, RED)
    px(d, cx - 5, base - 73, HOT)
    px(d, cx + 4, base - 73, HOT)
    for k in (cx - 30, cx + 22):
        rect(d, k, base - 70, k + 8, base - 52, NAVY)
        px(d, k + 4, base - 66, RED)
    for k in range(cx - 30, cx + 30, 10):
        rect(d, k, base - 40, k + 2, base - 39, RED)
    rect(d, cx - 8, base - 22, cx + 8, base, INK)


def near_layer():
    r = PARALLAX["near"]
    w = layer_w(r)
    img, d = new(w, HORIZON)
    rnd = random.Random(32)
    for sx, sh in [(34, 52), (44, 44), (206, 58), (290, 40)]:
        tower(d, sx, sh)
    for bx, bw, bh in [(0, 30, 22), (58, 40, 16), (120, 24, 26), (170, 52, 18), (240, 34, 24), (318, 42, 20)]:
        ruin(d, rnd, bx, bw, bh, 3)
    d.line([130, HORIZON - 40, 130, HORIZON], fill=NAVY)
    d.line([130, HORIZON - 40, 156, HORIZON - 36], fill=NAVY)
    d.line([152, HORIZON - 36, 152, HORIZON - 28], fill=NAVY)
    end = w - 120
    x = BG_W + 4
    while x < end - 40:
        st = stage_at(x, r, rnd.randint(-30, 30))
        if st == 0:
            bw = rnd.randint(20, 40)
            ruin(d, rnd, x, bw, rnd.randint(14, 28), 3)
            if rnd.random() < 0.4:
                tower(d, x + rnd.randint(0, bw), rnd.randint(38, 56))
        elif st == 1:
            bw = rnd.randint(22, 40)
            burning(d, rnd, x, bw, rnd.randint(30, 62))
        elif st == 2:
            bw = rnd.randint(18, 34)
            plant(d, rnd, x, bw)
        else:
            bw = rnd.randint(30, 50)
            wall(d, rnd, x, bw)
        x += bw + (rnd.randint(4, 18) if st < 3 else 0)
    wall(d, rnd, end - 40, 160)
    citadel(d, end + 30)
    save(img, "battlefield/near.png")


def tank_trap(d, x, y):
    d.line([x, y, x + 4, y - 4], fill=SLATE_D)
    d.line([x, y - 4, x + 4, y], fill=SLATE_D)
    px(d, x + 2, y - 2, SLATE)


def wreck(d, x, y):
    sbox(d, x, y - 4, x + 14, y, R_DARK)
    rect(d, x + 4, y - 7, x + 9, y - 4, SLATE_D)
    rect(d, x + 9, y - 6, x + 15, y - 6, INK)
    px(d, x + 6, y - 8, ORANGE)


GROUND_TOP = 4


def ground_layer():
    w = layer_w(PARALLAX["ground"])
    t = GROUND_TOP
    h = 160 - HORIZON + t
    img, d = new(w, h)
    rnd = random.Random(33)
    rect(d, 0, t, w - 1, t + 1, BROWN_D)
    rect(d, 0, t + 2, w - 1, h - 1, BROWN_K)
    for y in range(2, 6):
        for x in range(w):
            if (x * 7 + y * 3) % (y + 1) == 0:
                px(d, x, t + y, BROWN_D)
    for x in range(0, w, 4):
        for _ in range(2):
            y = rnd.randint(t + 4, h - 1)
            scorched = stage_at(x, 1.0) == 3 and rnd.random() < 0.5
            px(d, x + rnd.randint(0, 3), y, INK if scorched or rnd.random() >= 0.7 else BROWN_D)
    for x in range(-10, w):
        if rnd.random() > 0.016:
            continue
        st = stage_at(x, 1.0, rnd.randint(-30, 30))
        cy = rnd.randint(t + 10, h - 4)
        r = rnd.randint(6, 10 + 2 * st)
        d.ellipse([x - r, cy - r // 3, x + r, cy + r // 3], fill=BROWN_D)
        d.ellipse([x - r + 1, cy - r // 3 + 1, x + r - 1, cy + r // 3], fill=INK)
    for x in range(w):
        if rnd.random() > 0.08:
            continue
        st = stage_at(x, 1.0, rnd.randint(-30, 30))
        y = rnd.randint(t + 6, h - 3)
        if st == 1 and rnd.random() < 0.5:
            rect(d, x, y, x + rnd.randint(5, 12), y + rnd.randint(0, 1), SLATE_D)
            px(d, x + 2, y - 1, INK)
        elif st == 2 and rnd.random() < 0.3:
            d.ellipse([x, y, x + rnd.randint(6, 12), y + 2], fill=INK)
            px(d, x + 2, y + 1, NAVY)
        else:
            rect(d, x, y, x + rnd.randint(1, 3), y + rnd.randint(0, 1), rnd.choice([SLATE_D, SLATE, BROWN, RUST]))
    for x in range(4, w, 58):
        st = stage_at(x, 1.0)
        if st == 0:
            rect(d, x, t - 3, x, t + 1, INK)
            d.line([x, t - 2, x + 29, t], fill=INK)
        elif st == 2:
            rect(d, x - 58, t + 3, x, t + 3, SLATE)
            rect(d, x - 58, t + 5, x, t + 5, SLATE)
            for k in range(x - 58, x, 4):
                px(d, k, t + 4, BROWN_D)
    for x in range(w):
        if stage_at(x, 1.0) == 3:
            px(d, x, t - 2 + (x // 2) % 2, SLATE_D if x % 3 else SLATE)
            if x % 23 == 0:
                rect(d, x, t - 4, x, t + 1, SLATE_D)
    for x in range(BG_W, w):
        if rnd.random() > 0.012:
            continue
        st = stage_at(x, 1.0, rnd.randint(-30, 30))
        y = rnd.randint(t + 8, t + 18)
        if st == 3:
            tank_trap(d, x, y)
        elif st >= 1 and rnd.random() < 0.4:
            wreck(d, x, y)
    save(img, "battlefield/ground.png")


GATE_CELL = 12
GATES = 5
DIGITS = ["010110010010111", "110001010100111", "110001010001110", "101101111001001", "111100110001110"]


def gates():
    w, h = 16, GATE_CELL * GATES + 4
    img, d = new(w, h)
    sbox(d, 0, 0, w - 1, h - 1, R_DARK)
    hazard(d, 1, 1, w - 2, 2)
    for i in range(GATES):
        top = h - (i + 1) * GATE_CELL
        rect(d, 1, top + 2, 9, top + 11, NAVY)
        for y in range(top + 3, top + 11, 2):
            rect(d, 2, y, 8, y, SLATE_D)
        rect(d, 0, top + 1, w - 1, top + 1, INK)
        px(d, 14, top + 6, SLATE)
    save(img, "battlefield/gate_wall.png")

    img, d = new(18, 10)
    sbox(d, 0, 0, 8, 9, R_IRON)
    for y in range(2, 9, 2):
        rect(d, 1, y, 7, y, SLATE_D)
    rect(d, 9, 0, 17, 9, INK)
    rect(d, 9, 0, 9, 9, SLATE_D)
    rect(d, 17, 0, 17, 9, SLATE_D)
    rect(d, 10, 8, 16, 9, BROWN_D)
    rect(d, 12, 3, 14, 7, NAVY)
    save(img, "battlefield/gate_door.png")

    img, d = new(3 * len(DIGITS), 5)
    for k, bits in enumerate(DIGITS):
        for j, bit in enumerate(bits):
            if bit == "1":
                px(d, k * 3 + j % 3, j // 3, INK)
    save(img, "battlefield/gate_digits.png")


def battlefield():
    img, d = new(BG_W, HORIZON)
    rnd = random.Random(3)
    sky(d, BG_W, 0, HORIZON)
    for _ in range(40):
        px(d, rnd.randint(0, BG_W - 1), rnd.randint(0, 40), rnd.choice([SLATE, STEEL, SLATE_D]))
    save(img, "battlefield/sky.png")
    far_layer()
    near_layer()
    ground_layer()
    gates()

    img, d = new(360, 48)
    rnd = random.Random(8)
    for _ in range(18):
        cx = rnd.randint(0, 359)
        cy = rnd.randint(12, 38)
        for k in range(4):
            r = rnd.randint(4, 9)
            x = cx + k * 7
            for ox in (0, -360):
                d.ellipse([x + ox - r, cy - r // 2, x + ox + r, cy + r // 2], fill=NAVY[:3] + (110,))
    save(img, "battlefield/smoke.png")

    for v in range(5):
        enemies(v)


ENEMY_RAMPS = [R_RED, (GREEN_K, GREEN_D, GREEN), R_BLUE, R_PURPLE, (INK, NAVY, SLATE_D)]


def eye(d, x, y, big=False):
    rect(d, x, y, x + (2 if big else 1), y + 1, HOT)
    px(d, x + (2 if big else 1), y, WHITE)


def flipped(img):
    return img.transpose(Image.FLIP_LEFT_RIGHT)


def enemies(v):
    ramp = ENEMY_RAMPS[v]
    trim = GOLD if v == 4 else STEEL

    w, h = 12 + 2 * v, 8 + v
    img, d = new(w + 6, h + 8)
    top = 4
    d.ellipse([2, top, w + 1, top + h - 1], fill=ramp[1], outline=INK)
    rect(d, 4, top + 1, w - 2, top + 1, ramp[2])
    rect(d, 4, top + h - 2, w - 1, top + h - 2, ramp[0])
    eye(d, w - 3, top + h // 2 - 1, v >= 2)
    rotors = [w // 2 + 1] if v < 4 else [5, w - 2]
    for rx in rotors:
        rect(d, rx, 1, rx, top, INK)
        rect(d, rx - 4 - v // 2, 0, rx + 4 + v // 2, 0, trim)
    if v >= 2:
        sbox(d, w // 2, top + h - 1, w // 2 + 4, top + h + 2, R_DARK)
        rect(d, w // 2 + 5, top + h + 1, w // 2 + 7, top + h + 1, INK)
    if v >= 3:
        for sx in (3, 5):
            px(d, sx, top + h, INK)
    save(flipped(img), f"battlefield/enemy_drone_{v + 1}.png")

    w, h = 20 + 3 * v, 13 + 2 * v
    img, d = new(w + 10, h + 2)
    tread_h = 5 + v // 2
    ty = h + 1 - tread_h
    blob(d, 1, ty, w, h + 1, R_DARK)
    for x in range(4, w - 1, 4):
        disc(d, x, ty + tread_h // 2, 1, SLATE, outline=None)
    hull_top = ty - 5 - v // 2
    sbox(d, 3, hull_top, w - 2, ty, ramp)
    tw = 8 + v
    tx = w // 2 - tw // 2
    tt = hull_top - 4 - v // 2
    blob(d, tx, tt, tx + tw, hull_top + 1, ramp)
    eye(d, tx + tw - 3, tt + 2)
    barrels = [tt + 2] if v < 3 else [tt + 1, tt + 4]
    for by in barrels:
        sbox(d, tx + tw, by, min(w + 9, tx + tw + 8 + v), by + 2, (SLATE_D, trim, WHITE))
    if v >= 2:
        hazard(d, 4, ty - 2, w - 3, ty - 1, trim, INK)
    if v == 4:
        for sx in range(6, w - 4, 5):
            d.polygon([(sx, hull_top), (sx + 1, hull_top - 3), (sx + 2, hull_top)], fill=GOLD, outline=INK)
    save(flipped(img), f"battlefield/enemy_crawler_{v + 1}.png")

    save(flipped(brute(v, ramp, trim, 30 + 6 * v, 38 + 6 * v)), f"battlefield/enemy_brute_{v + 1}.png")
    save(flipped(brute(v, ramp, trim, 58 + 6 * v, 66 + 6 * v, boss=True)), f"battlefield/enemy_boss_{v + 1}.png")


def brute(v, ramp, trim, w, h, boss=False):
    pad = 14 if boss else 0
    img, d = new(w + 12, h + 2 + pad)
    lw = 5 + v
    leg_h = h // 3
    base = h + 1 + pad
    for lx, shade in ((6, 0.75), (w - lw - 6, 1.0)):
        lr = tuple(tuple(int(c * shade) for c in col[:3]) + (255,) for col in R_DARK)
        sbox(d, lx, base - leg_h, lx + lw, base - 2, lr)
        sbox(d, lx - 2, base - 3, lx + lw + 3, base, lr)
    tt = base - leg_h - (h // 2)
    blob(d, 2, tt, w - 2, base - leg_h + 2, ramp)
    rect(d, 4, tt + 2, w - 4, tt + 2, ramp[2])
    for k in range(3 + v):
        bx = 5 + (k * 7) % max(8, w - 12)
        by = tt + 5 + (k * 5) % max(6, h // 2 - 8)
        sbox(d, bx, by, bx + 3, by + 3, R_RUST)
    hw = 10 + v * 2 + (8 if boss else 0)
    hx = w // 2 - 2
    ht = tt - 7 - v - (4 if boss else 0)
    blob(d, hx, ht, hx + hw, tt + 2, ramp)
    rect(d, hx + hw // 2, ht + 3, hx + hw - 1, ht + 5, INK)
    eye(d, hx + hw - 4, ht + 3, True)
    if v >= 2:
        for sx in (4, w - 8):
            d.polygon([(sx, tt + 1), (sx + 2, tt - 4 - v), (sx + 4, tt + 1)], fill=trim, outline=INK)
    if v == 4 or boss:
        for hx2 in (hx + 1, hx + hw - 3):
            d.polygon([(hx2, ht), (hx2 + 1, ht - 6), (hx2 + 3, ht)], fill=GOLD, outline=INK)
        cx, cy = w // 2 - 4, tt + (base - leg_h - tt) // 2 + 2
        disc(d, cx, cy, 4, RED_D)
        disc(d, cx, cy, 2, HOT, outline=None)
    ay = tt + 6
    sbox(d, w - 6, ay, w + 4 + v, ay + 5 + v // 2, R_IRON)
    sbox(d, w + 2, ay - 1, w + 11, ay + 3, (SLATE_D, trim, WHITE))
    cy = tt + (h // 3)
    sbox(d, w - 10, cy, w - 2, cy + 12 + v, R_DARK)
    d.polygon([(w - 2, cy + 10 + v), (w + 5, cy + 14 + v), (w - 2, cy + 16 + v)], fill=STEEL, outline=INK)
    if boss:
        top = ht - 13
        sbox(d, 6, top - 1, 16, tt + 2, R_IRON)
        sbox(d, 16, top, w - 4, top + 5, (SLATE_D, trim, WHITE))
        sbox(d, w - 4, top - 1, w, top + 6, R_DARK)
        hazard(d, 4, base - leg_h - 4, w - 4, base - leg_h - 2, trim, INK)
    return img


MUSHROOM = (168, 156)
MUSHROOM_COLORS = [
    (ORANGE, YELLOW, WHITE),
    (ORANGE, YELLOW, WHITE),
    (RUST, ORANGE, YELLOW),
    (RUST, ORANGE, YELLOW),
    (BROWN_D, RUST, ORANGE),
    (BROWN_D, RUST_L, TAN),
    (BROWN_K, BROWN, TAN),
    (BROWN_K, BROWN_D, SKIN_D),
]


def puffy(d, cx, cy, rx, ry, colors, rnd, n):
    dark, mid, light = colors
    blobs = []
    for _ in range(n):
        a = rnd.random() * math.tau
        k = math.sqrt(rnd.random())
        x = cx + math.cos(a) * rx * k * 0.75
        y = cy + math.sin(a) * ry * k * 0.75
        r = max(2, min(rx, ry) * (0.35 + rnd.random() * 0.3))
        blobs.append((x, y, r))
    for x, y, r in blobs:
        d.ellipse([x - r, y - r + 2, x + r, y + r + 2], fill=dark)
    for x, y, r in blobs:
        d.ellipse([x - r, y - r, x + r, y + r], fill=mid)
    for x, y, r in blobs:
        if y < cy:
            d.ellipse([x - r * 0.6, y - r * 0.8, x + r * 0.4, y - r * 0.1], fill=light)


def nuke_fx():
    w, h = MUSHROOM
    sheet = Image.new("RGBA", (w * 8, h), CLEAR)
    for f in range(8):
        img, d = new(w, h)
        rnd = random.Random(40 + f)
        p = f / 7.0
        e = 1 - (1 - p) ** 2
        cols = MUSHROOM_COLORS[f]
        cx = w // 2
        ground = h - 2
        if f == 0:
            puffy(d, cx, ground - 10, 16, 10, cols, rnd, 10)
            d.ellipse([cx - 6, ground - 16, cx + 6, ground - 4], fill=WHITE)
        else:
            cap_y = ground - 32 - e * 76
            rx = 16 + e * 58
            ry = 12 + e * 22
            base_rx = 12 + e * 70
            puffy(d, cx, ground - 5, base_rx, 5 + e * 8, cols, rnd, 14 + f * 2)
            sw = 5 + e * 9
            for y in range(int(cap_y), ground - 4, 3):
                wob = rnd.randint(-1, 1)
                d.ellipse([cx - sw + wob, y - 3, cx + sw + wob, y + 4], fill=cols[1])
                d.ellipse([cx - sw * 0.5 + wob, y - 2, cx + sw * 0.1 + wob, y + 2], fill=cols[2])
            if f >= 3:
                ring_y = cap_y + ry + 10
                d.ellipse([cx - sw - 8, ring_y - 3, cx + sw + 8, ring_y + 3], outline=STEEL_L if f < 6 else STEEL, width=2)
            puffy(d, cx, cap_y, rx, ry, cols, rnd, 16 + f * 3)
            if f <= 4:
                d.ellipse([cx - rx * 0.3, cap_y - ry * 0.3, cx + rx * 0.3, cap_y + ry * 0.4], fill=cols[2])
        sheet.paste(img, (f * w, 0))
    save(sheet, "fx/mushroom.png")

    img, d = new(12, 34)
    sbox(d, 3, 6, 8, 27, (STEEL, STEEL_L, WHITE))
    d.polygon([(3, 6), (5, 0), (6, 0), (8, 6)], fill=RED, outline=INK)
    rect(d, 4, 11, 7, 13, YELLOW)
    px(d, 5, 12, INK)
    px(d, 6, 12, INK)
    rect(d, 4, 18, 7, 18, INK)
    d.polygon([(3, 22), (0, 28), (0, 31), (3, 28)], fill=RED_D, outline=INK)
    d.polygon([(8, 22), (11, 28), (11, 31), (8, 28)], fill=RED_D, outline=INK)
    sbox(d, 4, 28, 7, 31, R_DARK)
    rect(d, 5, 32, 6, 33, YELLOW)
    save(img, "fx/missile.png")

    img, d = new(360, 28)
    for y in range(28):
        k = 1 - abs(y - 14) / 14
        c = WHITE if k > 0.85 else YELLOW if k > 0.65 else ORANGE if k > 0.4 else RUST
        rect(d, 0, y, 359, y, c[:3] + (int(255 * min(1, k * 1.6)),))
    rnd = random.Random(12)
    for _ in range(160):
        x, y = rnd.randint(0, 359), rnd.choice([rnd.randint(0, 7), rnd.randint(20, 27)])
        rect(d, x, y, x + rnd.randint(0, 2), y, rnd.choice([BROWN_D, RUST, TAN]))
    save(img, "fx/shockwave.png")


MACHINE = (80, 56)
TIERS = 6
TIER_RAMPS = [style[0] for style in FRAME_STYLE]
CORE_RAMPS = TIER_RAMPS[:5] + [R_RED]
PLATE_RAMPS = [R_STEEL, R_RUST, R_STEEL, R_CERAMIC, R_TAN, R_IRON]


def back_wall(d, x0, x1):
    w, h = MACHINE
    rect(d, x0, 10, x1, h - 1, NAVY)
    for x in range(x0 + 7, x1, 12):
        rect(d, x, 12, x, h - 3, SLATE_D)
    rect(d, x0, h - 2, x1, h - 1, SLATE_D)


def lamp(d, x, y, on, color):
    sbox(d, x - 1, y - 1, x + 2, y + 2, (INK, color if on else SLATE_D, WHITE if on else SLATE))


def tier_lamps(d, x, y, t):
    rect(d, x - 1, y - 1, x + 2, y + TIERS * 3 - 1, INK)
    for k in range(TIERS):
        ly = y + (TIERS - 1 - k) * 3
        rect(d, x, ly, x + 1, ly + 1, TIER_RAMPS[t][2] if k <= t else NAVY)


def top_beam(d, ramp=R_DARK):
    w, _ = MACHINE
    sbox(d, 0, 0, w - 1, 11, ramp)


def machine_frame(d, f, t):
    w, h = MACHINE
    back_wall(d, 8, 71)
    for x0 in (0, 72):
        sbox(d, x0, 8, x0 + 7, h - 1, R_IRON)
        rect(d, x0 + 3, 12, x0 + 4, h - 10, SLATE_D)
        hazard(d, x0 + 1, h - 8, x0 + 6, h - 2)
    top_beam(d)
    drop = [0, 6, 4][f]
    for cx in [(15, 58), (15, 36, 58), (15, 29, 44, 58)][t // 2]:
        sbox(d, cx, 11, cx + 6, 20, R_STEEL)
        rect(d, cx + 2, 21, cx + 4, 22 + drop, STEEL_L)
    thick = 4 + t // 4
    sbox(d, 14, 22 + drop, 65, 22 + thick + drop, TIER_RAMPS[t])
    rect(d, 20, 23 + thick + drop, 59, 23 + thick + drop, INK)
    lamp(d, 3, 14, f > 0, YELLOW if f == 1 else ORANGE)
    tier_lamps(d, 3, 21, t)
    if f > 0:
        for x, y in [(24, 30), (38, 31), (52, 29), (30, 33), (46, 34)][f - 1::2]:
            px(d, x, y + drop + thick - 4, WHITE)
            px(d, x + 1, y + drop + thick - 5, YELLOW)
            px(d, x - 1, y + drop + thick - 3, ORANGE)


def machine_core(d, f, t):
    w, h = MACHINE
    ramp = CORE_RAMPS[t]
    back_wall(d, 4, 75)
    glass = CYAN[:3] + ((90 if f else 45),)
    d.ellipse([3, 4, 76, 70], fill=glass)
    d.ellipse([3, 4, 76, 70], outline=STEEL_L, width=2)
    d.ellipse([5, 6, 74, 68], outline=SLATE, width=1)
    rect(d, 0, 38, w - 1, h - 1, CLEAR)
    rect(d, 5, 38, 74, h - 1, NAVY)
    rect(d, 5, 38, 74, 39, glass)
    for x in range(10, 74, 12):
        rect(d, x, 42, x, h - 3, SLATE_D)
    rect(d, 5, h - 2, 74, h - 1, SLATE_D)
    for x0 in (1, 75):
        sbox(d, x0, 30, x0 + 3, h - 1, R_PURPLE)
    d.line([12, 14, 18, 10], fill=WHITE)
    d.line([10, 20, 12, 18], fill=WHITE)
    top_beam(d, R_PURPLE)
    rings = 1 + t // 2
    rect(d, 39, 12, 40, 15 + 4 * (rings - 1), INK)
    for k in range(rings):
        box = [27 + 2 * k, 15 + 4 * k, 52 - 2 * k, 21 + 4 * k]
        d.ellipse(box, fill=INK if k else None, outline=INK, width=1)
        d.ellipse([box[0] + 1, box[1] + 1, box[2] - 1, box[3] - 1], outline=ramp[2] if f else ramp[1], width=1)
    if f:
        top = 21 + 4 * (rings - 1)
        for k, x in enumerate([31, 40, 48] if f == 1 else [34, 44]):
            y = top
            while y < 34:
                nx = x + (1 if (y + k + f) % 4 < 2 else -1)
                d.line([x, y, nx, y + 2], fill=WHITE if y % 3 else ramp[1])
                x, y = nx, y + 2
    lamp(d, 76, 26, f > 0, MAGENTA if f == 1 else PINK)
    tier_lamps(d, 2, 34, t)


def rack_gun(d, y, t):
    rect(d, 2, y - 2, 3, y + 3, INK)
    if t == 0:
        sbox(d, 2, y, 10, y + 2, R_RUST)
        rect(d, 10, y, 16, y + 2, INK)
        rect(d, 11, y + 1, 15, y + 1, STEEL)
    elif t == 1:
        sbox(d, 2, y, 12, y + 2, R_IRON)
        sbox(d, 11, y - 1, 16, y + 3, R_IRON)
    elif t == 2:
        sbox(d, 2, y - 1, 9, y + 3, R_STEEL)
        sbox(d, 9, y, 19, y + 2, R_STEEL)
        px(d, 19, y + 1, INK)
    elif t == 3:
        sbox(d, 4, y - 2, 16, y + 3, R_BLUE)
        for x in (9, 13):
            px(d, x, y - 1, RED)
            px(d, x, y + 1, RED)
    elif t == 4:
        rect(d, 2, y - 2, 19, y + 3, INK)
        rect(d, 3, y - 1, 18, y - 1, YELLOW)
        rect(d, 3, y + 2, 18, y + 2, GOLD)
        rect(d, 5, y, 18, y + 1, CYAN)
        rect(d, 5, y, 18, y, WHITE)
        rect(d, 3, y, 4, y + 1, ORANGE)
    else:
        sbox(d, 3, y - 1, 15, y + 2, (STEEL, STEEL_L, WHITE))
        d.polygon([(15, y - 1), (18, y), (18, y + 1), (15, y + 2)], fill=RED, outline=INK)
        rect(d, 7, y, 8, y + 1, YELLOW)
        rect(d, 3, y - 2, 4, y + 3, RED_D)


def machine_arms(d, f, t):
    w, h = MACHINE
    back_wall(d, 4, 75)
    top_beam(d)
    sbox(d, 0, 8, 13, h - 1, R_DARK)
    for y in (16, 27, 38):
        rack_gun(d, y, t)
    sbox(d, 64, 46, 79, h - 1, R_GOLD)
    hazard(d, 65, 52, 78, 54)
    sbox(d, 70, 14, 75, 46, R_IRON)
    ex, ey = 72, 15
    cx, cy = [(52, 20), (46, 30), (48, 28)][f]
    d.line([ex, ey, cx, cy], fill=INK, width=5)
    d.line([ex, ey, cx, cy], fill=GOLD, width=3)
    d.line([ex, ey - 1, cx, cy - 1], fill=YELLOW, width=1)
    disc(d, ex, ey, 3, ORANGE)
    disc(d, cx, cy, 2, SLATE)
    rect(d, cx - 4, cy + 2, cx - 3, cy + 5, INK)
    rect(d, cx + 1, cy + 2, cx + 2, cy + 5, INK)
    if f:
        for dx, dy, c in [(-1, 7, WHITE), (-3, 8, YELLOW), (1, 8, YELLOW), (-2, 10, ORANGE), (2, 9, ORANGE)][: 3 + f]:
            px(d, cx + dx, cy + dy, c)
    lamp(d, 67, 42, f > 0, ORANGE if f == 1 else YELLOW)
    tier_lamps(d, 72, 24, t)


def roller(d, cx, cy, r, f, hub=GREEN):
    disc(d, cx, cy, r, SLATE)
    disc(d, cx, cy, r - 2, STEEL, outline=SLATE_D)
    a = f * math.pi / 4
    for k in range(2):
        t = a + k * math.pi / 2
        d.line([cx - math.cos(t) * (r - 2), cy - math.sin(t) * (r - 2), cx + math.cos(t) * (r - 2), cy + math.sin(t) * (r - 2)], fill=SLATE_D)
    disc(d, cx, cy, 1, hub, outline=None)


def machine_plating(d, f, t):
    w, h = MACHINE
    ramp = PLATE_RAMPS[t]
    back_wall(d, 10, 69)
    top_beam(d, R_GREEN)
    sheet = [5, 9, 13][f]
    for x0 in (0, 67):
        sbox(d, x0, 8, x0 + 12, h - 1, R_IRON)
        rect(d, x0 + 1, h - 6, x0 + 11, h - 5, GREEN_D)
    roller(d, 12, 20, 7, f)
    roller(d, 67, 20, 7, f)
    roller(d, 8, 38, 5, f + 1)
    roller(d, 71, 38, 5, f + 1)
    sbox(d, 19, 14, 60, 16, R_STEEL)
    half = 12 + t
    if t >= 4:
        sbox(d, 42 - half, 18, 37 + half, 20 + sheet, ramp)
    sbox(d, 40 - half, 16, 39 + half, 16 + sheet, ramp)
    rect(d, 41 - half, 16 + sheet, 38 + half, 16 + sheet, WHITE if f else ramp[0])
    if t == 5:
        hazard(d, 41 - half, 18, 38 + half, 19)
    if t >= 2:
        roller(d, 22, 15, 3, f + 1)
        roller(d, 57, 15, 3, f + 1)
    lamp(d, 39, 12, f > 0, GREEN if f == 1 else YELLOW)
    tier_lamps(d, 1, 27, t)


def line():
    w, h = MACHINE
    for kind, draw in [("frame", machine_frame), ("core", machine_core), ("arms", machine_arms), ("plating", machine_plating)]:
        for f in range(3):
            sheet, _ = new(w * TIERS, h)
            for t in range(TIERS):
                img, d = new(w, h)
                draw(d, f, t)
                sheet.paste(img, (t * w, 0))
            save(sheet, f"line/machine_{kind}_{f}.png")

    img, d = new(72, 8)
    sbox(d, 0, 0, 71, 7, R_DARK)
    hazard(d, 1, 1, 8, 6)
    hazard(d, 63, 1, 70, 6)
    for x in (16, 35, 54):
        px(d, x, 3, INK)
        px(d, x + 1, 4, SLATE)
    save(img, "line/pad.png")

    img, d = new(16, 8)
    rect(d, 0, 0, 15, 7, INK)
    rect(d, 0, 1, 15, 3, SLATE_D)
    rect(d, 0, 1, 15, 1, SLATE)
    for x in (2, 10):
        rect(d, x, 2, x + 3, 2, NAVY)
    rect(d, 0, 4, 15, 6, NAVY)
    for x in (3, 11):
        disc(d, x, 5, 1, SLATE, outline=None)
    save(img, "line/belt.png")

    img, d = new(80, 22)
    rnd = random.Random(11)
    d.polygon([(0, 21), (10, 10), (24, 12), (38, 3), (52, 8), (66, 6), (79, 21)], fill=BROWN_K, outline=INK)
    for _ in range(40):
        x = rnd.randint(6, 72)
        y = rnd.randint(8, 19)
        if img.getpixel((x, y))[3] and img.getpixel((x, y)) != INK:
            sbox(d, x, y, x + rnd.randint(2, 6), y + rnd.randint(1, 3), rnd.choice([R_IRON, R_RUST, R_DARK, R_BROWN]))
    d.line([20, 12, 30, 2], fill=INK, width=2)
    d.line([56, 8, 62, 0], fill=SLATE, width=2)
    save(img, "line/rubble.png")


def worker(d, x, y, flip=False):
    sbox(d, x + 3, y, x + 7, y + 2, R_GOLD)
    rect(d, x + 2, y + 2, x + 8, y + 2, GOLD)
    rect(d, x + 4, y + 3, x + 6, y + 5, SKIN)
    px(d, x + 6, y + 4, INK)
    sbox(d, x + 2, y + 6, x + 7, y + 10, R_BLUE)
    rect(d, x + 4, y + 7, x + 5, y + 7, CYAN)
    rect(d, x + 3, y + 11, x + 3, y + 12, BLUE_D)
    rect(d, x + 6, y + 11, x + 6, y + 12, BLUE_D)
    rect(d, x + 2, y + 13, x + 3, y + 13, INK)
    rect(d, x + 6, y + 13, x + 7, y + 13, INK)


def workers():
    img, d = new(10, 14)
    worker(d, 0, 0)
    rect(d, 8, 6, 8, 9, STEEL)
    rect(d, 7, 5, 9, 5, STEEL_L)
    save(img, "line/worker.png")

    img, d = new(10, 14)
    worker(d, 0, 0)
    d.line([8, 3, 8, 10], fill=BROWN)
    sbox(d, 7, 10, 9, 13, R_STEEL, outline=None)
    save(img, "yard/worker.png")

    img, d = new(16, 16)
    worker(d, 2, 1)
    rect(d, 12, 9, 14, 13, GREEN)
    rect(d, 11, 10, 15, 12, GREEN)
    rect(d, 13, 10, 13, 12, WHITE)
    rect(d, 12, 11, 14, 11, WHITE)
    save(img, "ui/worker.png")


def yard():
    rnd = random.Random(7)
    colors = [R_IRON, R_RUST, R_DARK, R_BROWN, R_STEEL, R_GOLD]
    for level, (hw, hh) in enumerate([(38, 30), (46, 42), (54, 54)]):
        img, d = new(112, 64)
        cx, base = 56, 63
        pts = [(cx - hw, base), (cx - hw * 0.6, base - hh * 0.55), (cx - hw * 0.2, base - hh), (cx + hw * 0.15, base - hh * 0.9),
               (cx + hw * 0.55, base - hh * 0.5), (cx + hw, base)]
        d.polygon(pts, fill=BROWN_K, outline=INK)
        for _ in range(40 + level * 50):
            x = rnd.randint(cx - hw + 4, cx + hw - 6)
            y = rnd.randint(base - hh, base - 3)
            if not img.getpixel((x, y))[3] or img.getpixel((x, y)) == INK:
                continue
            sbox(d, x, y, x + rnd.randint(2, 6), y + rnd.randint(2, 4), rnd.choice(colors))
        if level:
            disc(d, cx + 10, base - hh * 0.6, 3, SLATE)
            px(d, cx + 10, base - hh * 0.6, INK)
            d.line([cx - 12, base - hh * 0.7, cx - 4, base - hh * 0.95], fill=RUST_L, width=2)
        save(img, f"yard/pile_{level + 1}.png")


CREDIT_TIERS = [(ORANGE, GOLD, YELLOW), (GREEN_D, GREEN, WHITE), (PURPLE, MAGENTA, PINK)]
SCRAP_TIERS = [(SLATE, STEEL, STEEL_L), (BLUE_D, BLUE, CYAN), (RUST, ORANGE, YELLOW)]


def coin(size, ramp):
    img, d = new(size, size)
    dark, mid, light = ramp
    e = size - 1
    d.ellipse([0, 0, e, e], fill=dark, outline=INK)
    d.ellipse([1, 1, e - 2, e - 2], fill=mid)
    if size >= 8:
        d.ellipse([2, 1, e - 4, e - 5], fill=light) if size > 10 else px(d, 2, 2, light)
        m = size // 2
        rect(d, m - 1, 3, m - 1 + (1 if size > 10 else 0), e - 3, dark)
    return img


def nut(size, ramp):
    img, d = new(size, size)
    dark, mid, light = ramp
    c = size // 3
    e = size - 1
    d.polygon([(c, 0), (e - c, 0), (e, c), (e, e - c), (e - c, e), (c, e), (0, e - c), (0, c)], fill=mid, outline=INK)
    rect(d, c, 1, e - c, 1, light)
    rect(d, c, e - 1, e - c, e - 1, dark)
    if size >= 8:
        m = size // 2
        h = 1 if size < 12 else 2
        rect(d, m - h, m - h, m + h - 1, m + h - 1, INK)
    return img


def nine(face, light, dark, path, outline=INK):
    img, d = new(12, 12)
    rect(d, 0, 0, 11, 11, outline)
    rect(d, 1, 1, 10, 10, face)
    rect(d, 1, 1, 10, 1, light)
    rect(d, 1, 10, 10, 10, dark)
    for x, y in [(0, 0), (11, 0), (0, 11), (11, 11)]:
        px(d, x, y, CLEAR)
    save(img, path)


def rail_icons():
    img, d = new(12, 12)
    for flip in (False, True):
        f = (lambda x: 11 - x) if flip else (lambda x: x)
        for i in range(1, 7):
            px(d, f(i), i, STEEL_L)
        for x, y in [(8, 6), (7, 7), (6, 8)] if not flip else [(3, 6), (4, 7), (5, 8)]:
            px(d, x, y, GOLD)
        px(d, f(8), 8, BROWN)
        px(d, f(9), 9, BROWN)
        px(d, f(10), 10, GOLD)
    outline(img)
    save(img, "ui/rail_field.png")

    save(nut(12, SCRAP_TIERS[0]), "ui/rail_yard.png")

    img, d = new(12, 12)
    rect(d, 3, 1, 8, 3, RED)
    rect(d, 3, 1, 8, 1, PINK)
    rect(d, 4, 4, 7, 4, RED_D)
    rect(d, 2, 5, 9, 6, RED)
    rect(d, 2, 5, 9, 5, PINK)
    rect(d, 5, 7, 5, 10, STEEL_L)
    rect(d, 6, 7, 6, 9, STEEL)
    outline(img)
    save(img, "ui/pin.png")

    img, d = new(12, 8)
    for k in range(5):
        rect(d, 5 - k, 1 + k, 6 + k, 1 + k, WHITE)
    outline(img)
    save(img, "ui/arrow_up.png")
    save(img.transpose(Image.FLIP_TOP_BOTTOM), "ui/arrow_down.png")


def ui():
    save(coin(16, CREDIT_TIERS[0]), "ui/credits.png")
    save(nut(16, SCRAP_TIERS[0]), "ui/scrap.png")
    save(coin(12, CREDIT_TIERS[0]), "ui/credits_s.png")
    save(nut(12, SCRAP_TIERS[0]), "ui/scrap_s.png")
    for i in range(3):
        save(coin(10, CREDIT_TIERS[i]), f"fx/disc_credits_{i + 1}.png")
        save(nut(10, SCRAP_TIERS[i]), f"fx/disc_scrap_{i + 1}.png")
        save(coin(6, CREDIT_TIERS[i]), f"fx/disc_credits_{i + 1}_s.png")
        save(nut(6, SCRAP_TIERS[i]), f"fx/disc_scrap_{i + 1}_s.png")

    nine(SLATE_D, SLATE, NAVY, "ui/button.png")
    nine(SLATE, STEEL, SLATE_D, "ui/button_hover.png")
    nine(NAVY, INK, SLATE_D, "ui/button_pressed.png")
    nine(NAVY, SLATE_D, NAVY, "ui/button_disabled.png")
    nine(GREEN_D, GREEN, GREEN_K, "ui/button_lit.png")
    img, d = new(12, 12)
    rect(d, 0, 0, 11, 11, INK)
    rect(d, 1, 1, 10, 10, SLATE_D)
    rect(d, 2, 2, 9, 9, NAVY)
    save(img, "ui/panel.png")

    img, d = new(6, 6)
    rect(d, 0, 0, 5, 5, INK)
    rect(d, 1, 1, 4, 4, NAVY)
    save(img, "ui/bar_under.png")
    img, d = new(14, 6)
    rect(d, 5, 0, 8, 5, INK)
    rect(d, 6, 0, 7, 5, NAVY)
    save(img, "ui/groove.png")
    for name, ramp in [("bar_fill", R_GREEN), ("hp_fill", R_RED)]:
        img, d = new(6, 6)
        rect(d, 0, 0, 5, 5, INK)
        rect(d, 1, 1, 4, 4, ramp[1])
        rect(d, 1, 1, 4, 1, ramp[2])
        rect(d, 1, 4, 4, 4, ramp[0])
        save(img, f"ui/{name}.png")

    img, d = new(16, 16)
    sbox(d, 5, 1, 10, 5, R_STEEL)
    rect(d, 8, 3, 9, 3, CYAN)
    sbox(d, 3, 6, 12, 10, R_IRON)
    sbox(d, 11, 7, 15, 9, R_DARK)
    sbox(d, 3, 11, 6, 15, R_DARK)
    sbox(d, 9, 11, 12, 15, R_DARK)
    save(img, "ui/mech.png")

    img, d = new(16, 16)
    d.ellipse([1, 1, 14, 14], fill=SLATE_D, outline=INK)
    d.ellipse([2, 2, 13, 13], outline=STEEL)
    rect(d, 7, 4, 8, 5, WHITE)
    rect(d, 7, 7, 8, 11, WHITE)
    save(img, "ui/info.png")

    img, d = new(16, 16)
    for k in range(8):
        a = k * math.tau / 8
        x, y = 7.5 + math.cos(a) * 6, 7.5 + math.sin(a) * 6
        d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=STEEL)
    d.ellipse([3, 3, 12, 12], fill=STEEL, outline=None)
    d.ellipse([4, 3, 11, 9], fill=STEEL_L)
    d.ellipse([6, 6, 9, 9], fill=INK)
    save(img, "ui/gear.png")

    for name, on in [("sound_on", True), ("sound_off", False)]:
        img, d = new(16, 16)
        d.polygon([(1, 5), (4, 5), (8, 1), (8, 14), (4, 10), (1, 10)], fill=STEEL, outline=INK)
        rect(d, 2, 6, 3, 6, STEEL_L)
        d.line([5, 5, 7, 3], fill=STEEL_L)
        if on:
            rect(d, 10, 6, 10, 9, WHITE)
            px(d, 12, 3, STEEL_L)
            px(d, 13, 4, STEEL_L)
            rect(d, 14, 5, 14, 10, STEEL_L)
            px(d, 13, 11, STEEL_L)
            px(d, 12, 12, STEEL_L)
        else:
            d.line([10, 5, 14, 9], fill=RED)
            d.line([10, 9, 14, 5], fill=RED)
            d.line([10, 6, 13, 9], fill=RED_D)
            d.line([10, 10, 14, 6], fill=RED_D)
        save(img, f"ui/{name}.png")

    for name, glyph in [("stall_scrap", "nut"), ("stall_blocked", "bar")]:
        img, d = new(12, 12)
        blob(d, 0, 0, 11, 11, R_RED)
        if glyph == "nut":
            d.polygon([(4, 2), (7, 2), (9, 4), (9, 7), (7, 9), (4, 9), (2, 7), (2, 4)], fill=STEEL_L, outline=INK)
            rect(d, 5, 5, 6, 6, INK)
        else:
            rect(d, 2, 5, 9, 6, WHITE)
        save(img, f"ui/{name}.png")

    img, d = new(16, 16)
    sbox(d, 3, 2, 6, 13, (STEEL, WHITE, WHITE))
    sbox(d, 9, 2, 12, 13, (STEEL, WHITE, WHITE))
    save(img, "ui/pause.png")
    img, d = new(16, 16)
    d.polygon([(4, 2), (13, 8), (4, 13)], fill=GREEN, outline=INK)
    rect(d, 5, 5, 5, 9, WHITE)
    save(img, "ui/play.png")
    img, d = new(8, 12)
    for k in range(3):
        rect(d, 3 - k, 1 + k, 4 + k, 1 + k, WHITE)
    rect(d, 3, 4, 4, 10, WHITE)
    outline(img)
    save(img, "ui/up_s.png")

    img, d = new(16, 16)
    sbox(d, 3, 1, 12, 2, R_STEEL, outline=None)
    sbox(d, 3, 13, 12, 14, R_STEEL, outline=None)
    d.polygon([(4, 3), (11, 3), (8, 7), (8, 8), (11, 12), (4, 12), (7, 8), (7, 7)], fill=(44, 232, 245, 110), outline=INK)
    rect(d, 5, 10, 10, 11, GOLD)
    px(d, 7, 9, GOLD)
    px(d, 6, 4, GOLD)
    rect(d, 5, 4, 9, 4, GOLD)
    save(img, "ui/life.png")

    img, d = new(16, 16)
    d.polygon([(9, 0), (3, 9), (7, 9), (5, 15), (13, 5), (9, 5), (11, 0)], fill=ORANGE, outline=INK)
    d.line([9, 2, 6, 7], fill=YELLOW)
    save(img, "ui/damage.png")

    rail_icons()

    img, d = new(40, 36)
    rnd = random.Random(3)
    rect(d, 17, 16, 22, 31, RUST_L)
    rect(d, 19, 16, 20, 31, TAN)
    puffy(d, 20, 32, 16, 3, (BROWN_D, RUST, ORANGE), rnd, 10)
    puffy(d, 20, 11, 17, 9, (RUST, ORANGE, YELLOW), rnd, 18)
    d.ellipse([12, 19, 28, 23], outline=STEEL_L)
    save(img, "ui/nuke.png")


if __name__ == "__main__":
    ui()
    line()
    workers()
    yard()
    mech()
    fx()
    battlefield()
    nuke_fx()

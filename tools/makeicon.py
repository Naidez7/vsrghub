#!/usr/bin/env python3
"""VSRG Hub's icon: four arrow lanes (left, down, up, right, as in Etterna's 4K) with arrows falling
onto their receptors, one of them a hold, on the violet-to-pink rounded square.

    python3 tools/makeicon.py            # writes every size the project uses

Writes media/icon/vsrghub-{1024,256,64}.png, media/icon/vsrghub.ico, media/icon/winres/icon*.png,
cmd/triwheel/assets/launcher-icon.png and the themes' "Common window icon.png". (The .syso with the
exe's icon is made from media/icon/winres with go-winres.)"""
import io, math, os
import cairo
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# the arrow pointing down, in a 1 x 1 box centred on 0, 0 (y grows downwards)
ARROW = [(0, 0.47), (0.47, 0.0), (0.29, -0.15), (0.115, 0.03), (0.115, -0.47),
         (-0.115, -0.47), (-0.115, 0.03), (-0.29, -0.15), (-0.47, 0.0)]
# Etterna's 4K columns: left, down, up, right (angle the down arrow is turned by)
TURN = [math.pi / 2, 0, math.pi, -math.pi / 2]


def arrow_path(cr, x, y, size, turn):
    c, s = math.cos(turn), math.sin(turn)
    for i, (px, py) in enumerate(ARROW):
        px, py = px * size, py * size
        rx, ry = x + px * c - py * s, y + px * s + py * c
        (cr.move_to if i == 0 else cr.line_to)(rx, ry)
    cr.close_path()


def rounded_rect(cr, x, y, w, h, r):
    cr.new_sub_path()
    cr.arc(x + w - r, y + r, r, -math.pi / 2, 0)
    cr.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
    cr.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
    cr.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2)
    cr.close_path()


def draw(n, small=False):
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, n, n)
    cr = cairo.Context(surf)
    cr.scale(n, n)  # everything below in 0..1
    cr.set_line_join(cairo.LINE_JOIN_ROUND)
    cr.set_line_cap(cairo.LINE_CAP_ROUND)
    m = 0.035 if n >= 48 else 0.0
    # the tile: deep violet at the top left to pink at the bottom right, a soft light along the top
    rounded_rect(cr, m, m, 1 - 2 * m, 1 - 2 * m, 0.22)
    g = cairo.LinearGradient(0.1, 0.05, 0.9, 1.0)
    g.add_color_stop_rgb(0, 0.17, 0.07, 0.33)
    g.add_color_stop_rgb(0.55, 0.37, 0.12, 0.53)
    g.add_color_stop_rgb(1, 0.87, 0.28, 0.59)
    cr.set_source(g)
    cr.fill_preserve()
    cr.save()
    cr.clip()
    hl = cairo.RadialGradient(0.25, 0.0, 0.05, 0.25, 0.0, 0.75)
    hl.add_color_stop_rgba(0, 1, 1, 1, 0.16)
    hl.add_color_stop_rgba(1, 1, 1, 1, 0)
    cr.set_source(hl)
    cr.paint()
    cr.restore()
    rounded_rect(cr, m, m, 1 - 2 * m, 1 - 2 * m, 0.22)
    cr.set_source_rgba(1, 1, 1, 0.14)
    cr.set_line_width(0.008 if n >= 48 else 0.03)
    cr.stroke()

    if small == "one":
        return draw_one(n, surf, cr)
    cols = [0.23, 0.41, 0.59, 0.77]
    size = 0.145 if not small else 0.16
    if small:
        cols = [0.17, 0.39, 0.61, 0.83]
    recY = 0.775 if not small else 0.72
    # the lanes
    if not small:
        for x in cols:
            rounded_rect(cr, x - 0.07, 0.11, 0.14, 0.78, 0.06)
            lg = cairo.LinearGradient(0, 0.12, 0, 0.88)
            lg.add_color_stop_rgba(0, 1, 1, 1, 0.0)
            lg.add_color_stop_rgba(1, 1, 1, 1, 0.08)
            cr.set_source(lg)
            cr.fill()

    # the hold in the right lane: its body first, then its arrow over it (the arrow covers the body,
    # the body never shows through it)
    holdTop, holdHead = (0.17, 0.50) if not small else (0.14, 0.40)
    x = cols[3]
    w = size * 0.42
    rounded_rect(cr, x - w / 2, holdTop, w, holdHead - holdTop, w / 2)
    bg = cairo.LinearGradient(0, holdTop, 0, holdHead)
    bg.add_color_stop_rgba(0, 1, 0.75, 0.9, 0.25)
    bg.add_color_stop_rgba(1, 1, 0.85, 0.95, 0.7)
    cr.set_source(bg)
    cr.fill()

    # the receptors: arrow outlines along the bottom
    for i, x in enumerate(cols):
        arrow_path(cr, x, recY, size, TURN[i])
        cr.set_source_rgba(1, 1, 1, 0.85 if not small else 0.9)
        cr.set_line_width(min(0.045, 0.022 * max(1, 128 / n) ** 0.5))
        cr.stroke()

    # falling arrows (white, faintly pink at the bottom, with a soft shadow)
    falling = [(0, 0.56), (1, 0.38), (2, 0.225), (3, holdHead)] if not small else [(0, 0.42), (3, holdHead)]
    for i, y in falling:
        x = cols[i]
        if n >= 48:
            for k, a in ((0.02, 0.10), (0.012, 0.12)):
                arrow_path(cr, x, y + k, size, TURN[i])
                cr.set_source_rgba(0.2, 0.0, 0.25, a)
                cr.set_line_width(0.03)
                cr.stroke_preserve()
                cr.fill()
        arrow_path(cr, x, y, size, TURN[i])
        fg = cairo.LinearGradient(0, y - size / 2, 0, y + size / 2)
        fg.add_color_stop_rgb(0, 1, 1, 1)
        fg.add_color_stop_rgb(1, 1, 0.84, 0.93)
        cr.set_source(fg)
        cr.set_line_width(min(0.04, 0.018 * max(1, 128 / n) ** 0.5))
        cr.stroke_preserve()
        cr.fill()
    return to_image(surf)


def to_image(surf):
    buf = io.BytesIO()
    surf.write_to_png(buf)
    return Image.open(io.BytesIO(buf.getvalue())).convert("RGBA")


# the smallest sizes (16, 32): the tile and one big arrow over its receptor's outline, readable there
def draw_one(n, surf, cr):
    """The icon at every size: the four arrows of a 4K chart (left, down, up, right) as on a dance
    pad, pointing out from the middle. The same picture from the taskbar's 16 pixels to the
    launcher's header, so they all match."""
    big = n >= 48
    sz = 0.215 if big else 0.235
    gap = 0.197 if big else 0.215
    y = 0.5
    # (each: where, which way it points; the down arrow shape turned): left, down, up, right
    arrows = [(0.5 + (i - 1.5) * gap, y, t) for i, t in enumerate(TURN)]
    tint = [(1, 0.80, 0.91), (0.88, 0.82, 1), (0.88, 0.82, 1), (1, 0.80, 0.91)]
    if big:
        glow = cairo.RadialGradient(0.5, 0.5, 0.02, 0.5, 0.5, 0.48)
        glow.add_color_stop_rgba(0, 1, 0.8, 0.95, 0.22)
        glow.add_color_stop_rgba(1, 1, 0.8, 0.95, 0)
        cr.set_source(glow)
        cr.paint()
        for x, y, t in arrows:
            for k, a in ((0.022, 0.10), (0.012, 0.14)):
                arrow_path(cr, x, y + k, sz, t)
                cr.set_source_rgba(0.2, 0.0, 0.25, a)
                cr.set_line_width(0.04)
                cr.stroke_preserve()
                cr.fill()
    for (x, y, t), c in zip(arrows, tint):
        # (the gradient runs from the arrow's tail, white, to its tip, tinted)
        tx, ty = x - math.sin(-t) * 0 , y
        g = cairo.LinearGradient(x + math.sin(t) * sz / 2, y - math.cos(t) * sz / 2, x - math.sin(t) * sz / 2, y + math.cos(t) * sz / 2)
        g.add_color_stop_rgb(0, 1, 1, 1)
        g.add_color_stop_rgb(1, *(c if big else (1, 0.95, 0.98)))
        arrow_path(cr, x, y, sz, t)
        cr.set_source(g)
        cr.set_line_width(0.03 if big else 0.05)
        cr.stroke_preserve()
        cr.fill()
    return to_image(surf)


def main():
    # (one picture at every size, so the window, the taskbar, the desktop and the launcher match)
    big = {s: draw(s) for s in (1024, 256, 64, 48)}
    tiny = {s: draw(s) for s in (32, 16)}
    ic = os.path.join(ROOT, "media", "icon")
    big[1024].save(os.path.join(ic, "vsrghub-1024.png"))
    big[256].save(os.path.join(ic, "vsrghub-256.png"))
    big[64].save(os.path.join(ic, "vsrghub-64.png"))
    for s, im in ((256, big[256]), (48, big[48]), (32, tiny[32]), (16, tiny[16])):
        im.save(os.path.join(ic, "winres", "icon%d.png" % s))
    # (the .ico: each size drawn for itself)
    big[256].save(os.path.join(ic, "vsrghub.ico"), sizes=[(256, 256), (48, 48), (32, 32), (16, 16)],
                  append_images=[big[48], tiny[32], tiny[16]])
    big[256].save(os.path.join(ROOT, "cmd", "triwheel", "assets", "launcher-icon.png"))
    big[64].save(os.path.join(ROOT, "theme", "VSRG Hub osu!", "Graphics", "Common window icon.png"))
    # a preview of every size side by side
    pv = Image.new("RGBA", (256 + 64 + 48 + 32 + 16 + 60, 256), (24, 20, 32, 255))
    x = 0
    for im in (big[256], big[64], big[48], tiny[32], tiny[16]):
        pv.alpha_composite(im, (x, (256 - im.height) // 2))
        x += im.width + 12
    pv.save(os.path.join(ic, "preview.png"))


if __name__ == "__main__":
    main()

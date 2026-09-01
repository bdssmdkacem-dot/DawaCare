"""Generates DawaCare's launcher icon assets.

Produces:
  assets/icon/app_icon.png            -- full icon incl. background (1024x1024)
  assets/icon/app_icon_foreground.png -- transparent glyph only, for Android
                                          adaptive icons (flutter_launcher_icons)

Design: a rounded capsule/pill split into two tones of the brand palette,
tilted 45°, centered on a soft rounded-square background. Simple enough to
read clearly at 48dp launcher size.
"""

import math
from PIL import Image, ImageDraw

SIZE = 1024
PRIMARY = (13, 110, 110, 255)       # AppColors.primary   #0D6E6E
PRIMARY_DARK = (8, 72, 74, 255)     # AppColors.primaryDark
ACCENT = (242, 166, 90, 255)        # AppColors.accent    #F2A65A
BG_LIGHT = (246, 250, 249, 255)     # AppColors.backgroundLight

SS = 4  # supersample factor for smooth edges


def rounded_square(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def draw_pill(img_size):
    """Draws the capsule glyph centered in a transparent square, at img_size*SS."""
    S = img_size * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    # Capsule dimensions (before rotation), centered at origin conceptually.
    capsule_w = int(S * 0.62)
    capsule_h = int(S * 0.30)
    cx, cy = S // 2, S // 2

    capsule_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cdraw = ImageDraw.Draw(capsule_layer)
    left = cx - capsule_w // 2
    top = cy - capsule_h // 2
    right = cx + capsule_w // 2
    bottom = cy + capsule_h // 2
    radius = capsule_h // 2

    # Full capsule outline (white halo for contrast on busy wallpapers)
    halo_pad = int(S * 0.018)
    cdraw.rounded_rectangle(
        [left - halo_pad, top - halo_pad, right + halo_pad, bottom + halo_pad],
        radius=radius + halo_pad,
        fill=(255, 255, 255, 235),
    )
    # Two-tone fill: amber half + teal half
    cdraw.rounded_rectangle([left, top, right, bottom], radius=radius, fill=ACCENT)
    half_mask = Image.new("L", (S, S), 0)
    hdraw = ImageDraw.Draw(half_mask)
    hdraw.rectangle([cx, top - halo_pad * 2, right + halo_pad * 2, bottom + halo_pad * 2], fill=255)
    # second half in off-white (not the background teal) so both halves of
    # the capsule stay legible against the teal background at small sizes
    light_half = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ldraw = ImageDraw.Draw(light_half)
    ldraw.rounded_rectangle([left, top, right, bottom], radius=radius, fill=BG_LIGHT)
    capsule_layer.paste(light_half, (0, 0), Image.composite(light_half, Image.new("RGBA", (S, S), (0,0,0,0)), half_mask))

    # thin dividing seam
    cdraw.line([(cx, top + 4), (cx, bottom - 4)], fill=PRIMARY_DARK[:3] + (140,), width=max(2, S // 220))

    rotated = capsule_layer.rotate(-45, resample=Image.BICUBIC, center=(cx, cy))
    return rotated


def make_foreground():
    glyph = draw_pill(SIZE)
    return glyph.resize((SIZE, SIZE), Image.LANCZOS)


def make_full_icon():
    S = SIZE * SS
    bg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(bg)
    margin = int(S * 0.06)
    rounded_square(draw, [margin, margin, S - margin, S - margin], radius=int(S * 0.22), fill=PRIMARY_DARK)
    # subtle inner rounded panel for depth
    inset = int(S * 0.10)
    rounded_square(draw, [inset, inset, S - inset, S - inset], radius=int(S * 0.20), fill=PRIMARY)

    glyph = draw_pill(SIZE)  # already at S = SIZE*SS
    bg = Image.alpha_composite(bg, glyph)
    return bg.resize((SIZE, SIZE), Image.LANCZOS)


if __name__ == "__main__":
    import os
    os.makedirs("assets/icon", exist_ok=True)

    full_icon = make_full_icon()
    full_icon.save("assets/icon/app_icon.png")

    foreground = make_foreground()
    # pad foreground so it sits correctly within Android's adaptive-icon safe zone
    padded = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    scale = 0.66
    small = foreground.resize((int(SIZE * scale), int(SIZE * scale)), Image.LANCZOS)
    off = ((SIZE - small.width) // 2, (SIZE - small.height) // 2)
    padded.paste(small, off, small)
    padded.save("assets/icon/app_icon_foreground.png")

    print("Icons written to assets/icon/")

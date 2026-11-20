# SPDX-License-Identifier: GPL-3.0-or-later
# WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
# Draws WalkMap's window looks (Stone, Wood, Leather) as TGA files.
# Usage: python3 gen_skins.py <WalkMap folder>
# Every image is procedural (noise, gradients, simple shapes): no game art.
import sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(sys.argv[1] if len(sys.argv) > 1 else ".", "Skins")
rng = np.random.default_rng(1306)

def periodic_noise(size, cutoff):
    """Seamless noise: low-pass filtered white noise via FFT (wraps around)."""
    w = rng.standard_normal((size, size))
    f = np.fft.fft2(w)
    ky = np.fft.fftfreq(size)[:, None]; kx = np.fft.fftfreq(size)[None, :]
    k = np.sqrt(kx * kx + ky * ky)
    f *= np.exp(-(k / cutoff) ** 2)
    n = np.real(np.fft.ifft2(f))
    n -= n.min(); n /= max(n.max(), 1e-9)
    return n

def to_img(rgb, alpha=None):
    rgb = np.clip(rgb, 0, 255).astype(np.uint8)
    a = np.full(rgb.shape[:2], 255, np.uint8) if alpha is None else np.clip(alpha, 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb, a]), "RGBA")

S = 128
def material(kind):
    if kind == "stone":
        n = 0.6 * periodic_noise(S, 0.06) + 0.4 * periodic_noise(S, 0.25)
        base = np.array([40, 40, 47.0])
        return base * (0.72 + 0.56 * n[..., None])
    if kind == "wood":
        n = periodic_noise(S, 0.05); fine = periodic_noise(S, 0.3)
        y = np.arange(S)[:, None] * np.ones((1, S))
        grain = np.sin(2 * np.pi * 6 * y / S + n * 7) * 0.5 + 0.5
        base = np.array([88, 55, 30.0])
        return base * (0.72 + 0.28 * grain[..., None] * (0.75 + 0.25 * fine[..., None]))
    if kind == "leather":
        pores = periodic_noise(S, 0.45); broad = periodic_noise(S, 0.05)
        base = np.array([86, 30, 25.0])
        return base * (0.68 + 0.22 * pores[..., None] + 0.3 * broad[..., None])
    raise ValueError(kind)

METALS = {  # dark, mid, light
    "stone": ((92, 64, 16), (198, 152, 52), (255, 228, 140)),     # gold
    "wood": ((72, 50, 22), (172, 122, 58), (240, 202, 132)),      # brass
    "leather": ((62, 36, 18), (152, 94, 50), (224, 168, 108)),    # bronze
}

def bevel_frame(size, width, metal, inner_shadow=True):
    """Square frame: a bevelled metal band of `width` px, transparent inside."""
    dk, md, lt = [np.array(c, float) for c in metal]
    img = np.zeros((size, size, 4))
    yy, xx = np.mgrid[0:size, 0:size]
    d = np.minimum(np.minimum(xx, size - 1 - xx), np.minimum(yy, size - 1 - yy)).astype(float)
    band = d < width
    t = d / max(width - 1, 1)
    # light ridge a third of the way in, dark at both edges
    shade = np.clip(1 - np.abs(t - 0.38) / 0.62, 0, 1)
    col = dk[None, None, :] * (1 - shade[..., None]) + lt[None, None, :] * shade[..., None]
    col = col * 0.75 + md[None, None, :] * 0.25
    # top/left edges a bit lighter, bottom/right darker (light from top-left)
    side = np.where((xx < size / 2) & (xx <= yy) | (yy < size / 2) & (yy < xx), 1.08, 0.86)
    side = np.where((yy < size / 2) & (yy <= xx) & (xx < size - 1 - yy), 1.1, side)
    col *= side[..., None]
    img[..., :3] = col
    img[..., 3] = np.where(band, 255, 0)
    if inner_shadow:
        sh = (d >= width) & (d < width + 5)
        img[..., 3] = np.where(sh, 150 * (1 - (d - width) / 5), img[..., 3])
        img[..., :3] = np.where(sh[..., None], 0, img[..., :3])
    return img

def ornament(draw, kind, cx, cy, r, metal):
    dk, md, lt = metal
    if kind == "diamond":
        draw.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=dk + (255,))
        draw.polygon([(cx, cy - r + 3), (cx + r - 3, cy), (cx, cy + r - 3), (cx - r + 3, cy)], fill=md + (255,))
        draw.polygon([(cx, cy - r + 3), (cx + r - 3, cy), (cx, cy)], fill=lt + (255,))
    else:
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=dk + (255,))
        draw.ellipse([cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2], fill=md + (255,))
        draw.ellipse([cx - r + 4, cy - r + 4, cx, cy], fill=lt + (255,))

def frame_tex(skin, size=128, width=15, corner=32, orn="diamond"):
    arr = bevel_frame(size, width, METALS[skin])
    img = to_img(arr[..., :3], arr[..., 3])
    d = ImageDraw.Draw(img)
    # dark outline outside and a dark groove inside the metal band, so the
    # frame reads as a solid border against any background
    d.rectangle([0, 0, size - 1, size - 1], outline=(12, 8, 4, 255))
    d.rectangle([width - 2, width - 2, size - width + 1, size - width + 1], outline=(10, 7, 4, 255), width=2)
    d.rectangle([5, 5, size - 6, size - 6], outline=METALS[skin][0] + (255,))
    # No corner ornaments: the border is drawn over the window's content, and
    # round studs looked odd against square buttons and map edges.
    return img

def inset_tex(skin, size=64):
    dk, md, lt = METALS[skin]
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, size - 1, size - 1], outline=dk + (255,))
    d.rectangle([1, 1, size - 2, size - 2], outline=md + (200,))
    d.line([(2, 2), (size - 3, 2)], fill=(0, 0, 0, 160)); d.line([(2, 2), (2, size - 3)], fill=(0, 0, 0, 160))
    return img

def header_tex(skin, w=128, h=32):
    mat = material("wood" if skin == "wood" else "stone")[:h, :w]
    if skin == "leather":
        mat = material("leather")[:h, :w] * 0.55
    elif skin == "stone":
        mat = mat * 0.55
    grad = np.linspace(1.25, 0.7, h)[:, None, None]
    rgb = mat * grad
    alpha = np.full((h, w), 235.0)
    img = to_img(rgb, alpha)
    d = ImageDraw.Draw(img)
    dk, md, lt = METALS[skin]
    d.line([(0, h - 2), (w, h - 2)], fill=md + (255,)); d.line([(0, h - 1), (w, h - 1)], fill=dk + (255,))
    return img

def button_tex(skin, w=128, h=32):
    mat = material(skin)[:h, :w]
    if skin == "stone":
        mat = mat * 1.05
    # darker face than the window, so light labels stay easy to read
    grad = np.linspace(1.15, 0.6, h)[:, None, None]
    rgb = mat * grad * (0.62 if skin != "stone" else 0.8)
    arr = np.dstack([rgb, np.full((h, w), 255.0)])
    img = to_img(arr[..., :3], arr[..., 3])
    d = ImageDraw.Draw(img)
    dk, md, lt = METALS[skin]
    d.rectangle([0, 0, w - 1, h - 1], outline=dk + (255,))
    d.rectangle([1, 1, w - 2, h - 2], outline=lt + (255,))
    d.rectangle([2, 2, w - 3, h - 3], outline=md + (255,))
    d.line([(3, 3), (w - 4, 3)], fill=lt + (120,))          # top shine
    d.line([(3, h - 4), (w - 4, h - 4)], fill=(0, 0, 0, 130))  # bottom shade
    return img

def close_tex(skin, size=32):
    """Square close button: dark material, metal edge and a light X."""
    mat = material(skin)[:size, :size] * np.linspace(1.05, 0.6, size)[:, None, None] * 0.7
    img = to_img(mat)
    d = ImageDraw.Draw(img)
    dk, md, lt = METALS[skin]
    d.rectangle([0, 0, size - 1, size - 1], outline=(10, 7, 4, 255))
    d.rectangle([1, 1, size - 2, size - 2], outline=md + (255,), width=2)
    d.line([(3, 3), (size - 4, 3)], fill=lt + (200,))
    m = 9
    for off, col in ((1, (0, 0, 0, 220)), (0, (255, 236, 190, 255))):
        d.line([(m + off, m + off), (size - 1 - m + off, size - 1 - m + off)], fill=col, width=3)
        d.line([(size - 1 - m + off, m + off), (m + off, size - 1 - m + off)], fill=col, width=3)
    return img

def glow_tex(w=128, h=32):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([5, 5, w - 6, h - 6], radius=6, outline=(255, 214, 90, 255), width=6)
    img = img.filter(ImageFilter.GaussianBlur(2.2))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([7, 7, w - 8, h - 8], radius=3, outline=(255, 238, 160, 255), width=1)
    return img

def scroll_track_tex(skin, w=16, h=64):
    """Scroll bar groove: dark, sunk into the window, with a metal rim."""
    mat = material(skin)[:h, :w] * 0.38
    img = to_img(mat)
    d = ImageDraw.Draw(img)
    dk, md, lt = METALS[skin]
    d.rectangle([0, 0, w - 1, h - 1], outline=(8, 6, 3, 255))
    d.rectangle([1, 1, w - 2, h - 2], outline=md + (170,))
    d.line([(2, 2), (2, h - 3)], fill=(0, 0, 0, 170)); d.line([(2, 2), (w - 3, 2)], fill=(0, 0, 0, 170))
    return img

def scroll_thumb_tex(skin, w=16, h=64):
    """Scroll bar thumb: a bevelled metal bar (caps 8 px top and bottom)."""
    dk, md, lt = [np.array(c, float) for c in METALS[skin]]
    x = np.arange(w)[None, :] * np.ones((h, 1))
    t = x / (w - 1)
    shade = np.clip(1 - np.abs(t - 0.35) / 0.65, 0, 1)
    rgb = dk[None, None, :] * (1 - shade[..., None]) + lt[None, None, :] * shade[..., None]
    rgb = rgb * 0.7 + md[None, None, :] * 0.3
    img = to_img(rgb)
    # Rounded ends: clear the four corners.
    a = np.array(img)
    for (cx, cy) in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        for dy in range(3):
            for dx in range(3 - dy):
                a[abs(cy - dy), abs(cx - dx), 3] = 0
    img = Image.fromarray(a, "RGBA")
    d = ImageDraw.Draw(img)
    d.line([(3, 0), (w - 4, 0)], fill=(10, 7, 4, 255)); d.line([(3, h - 1), (w - 4, h - 1)], fill=(10, 7, 4, 255))
    d.line([(0, 3), (0, h - 4)], fill=(10, 7, 4, 255)); d.line([(w - 1, 3), (w - 1, h - 4)], fill=(10, 7, 4, 255))
    d.line([(3, 1), (w - 4, 1)], fill=tuple(int(c) for c in lt) + (200,))
    # No grip lines: the middle stretches with the page length.
    return img

def scroll_arrow_tex(skin, size=16):
    """Up arrow (flipped for down): a metal triangle with a dark outline."""
    dk, md, lt = METALS[skin]
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(size / 2 - 0.5, 2), (size - 2, size - 4), (1, size - 4)], fill=(10, 7, 4, 255))
    d.polygon([(size / 2 - 0.5, 4), (size - 4, size - 5), (3, size - 5)], fill=md + (255,))
    d.polygon([(size / 2 - 0.5, 4), (size / 2 - 0.5, size - 5), (3, size - 5)], fill=lt + (255,))
    return img

def main():
    os.makedirs(OUT, exist_ok=True)
    glow_tex().save(os.path.join(OUT, "glow.tga"))
    orn = {"stone": "diamond", "wood": "stud", "leather": "stud"}
    for skin in ("stone", "wood", "leather"):
        folder = os.path.join(OUT, skin); os.makedirs(folder, exist_ok=True)
        to_img(material(skin)).save(os.path.join(folder, "bg.tga"))
        frame_tex(skin, orn=orn[skin]).save(os.path.join(folder, "frame.tga"))
        inset_tex(skin).save(os.path.join(folder, "inset.tga"))
        header_tex(skin).save(os.path.join(folder, "header.tga"))
        button_tex(skin).save(os.path.join(folder, "button.tga"))
        close_tex(skin).save(os.path.join(folder, "close.tga"))
    # Added in 1.14.9, after the others with their own seed, so the files
    # above come out exactly as before.
    global rng
    rng = np.random.default_rng(1149)
    for skin in ("stone", "wood", "leather"):
        folder = os.path.join(OUT, skin)
        scroll_track_tex(skin).save(os.path.join(folder, "scrolltrack.tga"))
        scroll_thumb_tex(skin).save(os.path.join(folder, "scrollthumb.tga"))
        scroll_arrow_tex(skin).save(os.path.join(folder, "scrollarrow.tga"))
    print("skins written to", OUT)

if __name__ == "__main__":
    main()

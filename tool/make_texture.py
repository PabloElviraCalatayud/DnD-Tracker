#!/usr/bin/env python3
"""Genera assets/images/parchment_dark.png: textura oscura procedural (obra
propia, dominio público / CC0). El ruido se calcula sobre una rejilla
repetida 3×3 y se recorta el centro, así el mosaico no tiene costuras."""
import os
import numpy as np
from PIL import Image, ImageFilter

SIZE = 512
rng = np.random.default_rng(20)


def tileable_noise(cells):
    small = rng.random((cells, cells))
    tiled = np.tile(small, (3, 3))
    img = Image.fromarray((tiled * 255).astype('uint8')).resize((SIZE * 3, SIZE * 3), Image.BICUBIC)
    arr = np.asarray(img, dtype=np.float32) / 255
    return arr[SIZE:2 * SIZE, SIZE:2 * SIZE]


base = 0.5 * tileable_noise(6) + 0.3 * tileable_noise(24) + 0.2 * tileable_noise(96)
grain = rng.random((SIZE, SIZE)).astype(np.float32)
v = 0.88 * base + 0.12 * grain
v = (v - v.min()) / (v.max() - v.min())
r = 19 + v * 12
g = 16 + v * 10
b = 15 + v * 7
rgb = np.stack([r, g, b], axis=-1).clip(0, 255).astype('uint8')
img = Image.fromarray(rgb, 'RGB').filter(ImageFilter.GaussianBlur(0.5))
out = os.path.join(os.path.dirname(__file__), '..', 'assets', 'images', 'parchment_dark.png')
img.save(out, optimize=True)
print('ok', os.path.getsize(out))

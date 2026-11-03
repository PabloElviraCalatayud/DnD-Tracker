#!/usr/bin/env python3
"""Genera assets/images/parchment_dark.png: textura oscura procedural (obra
propia, dominio público / CC0). Ruido suave y repetible en mosaico."""
import os
import numpy as np
from PIL import Image, ImageFilter

SIZE = 512
rng = np.random.default_rng(20)

def tileable_noise(scale):
    # Ruido de baja frecuencia repetible: se genera pequeño y se amplía con wrap.
    small = rng.random((SIZE // scale, SIZE // scale))
    img = Image.fromarray((small * 255).astype('uint8')).resize((SIZE, SIZE), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255

base = 0.55 * tileable_noise(64) + 0.3 * tileable_noise(16) + 0.15 * tileable_noise(4)
grain = rng.random((SIZE, SIZE)).astype(np.float32)
v = 0.85 * base + 0.15 * grain
v = (v - v.min()) / (v.max() - v.min())
# Tonos tinta/cuero muy oscuros.
r = 20 + v * 14
g = 17 + v * 11
b = 15 + v * 8
rgb = np.stack([r, g, b], axis=-1).clip(0, 255).astype('uint8')
img = Image.fromarray(rgb, 'RGB').filter(ImageFilter.GaussianBlur(0.6))
out = os.path.join(os.path.dirname(__file__), '..', 'assets', 'images', 'parchment_dark.png')
img.save(out, optimize=True)
print('ok', os.path.getsize(out))

#!/usr/bin/env python3
"""Genera las texturas de fondo (obra propia, dominio público / CC0).

  assets/images/texture_grain.png  fondo de la app: grano de cuero/papel, en gris,
                                   que cada tema tiñe con su color (multiplicar).

Es un mosaico sin costuras de 1024 px: el ruido se calcula sobre una
rejilla repetida 3×3 y se recorta el centro.
"""
import os

import numpy as np
from PIL import Image, ImageFilter

SIZE = 1024
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'images')
rng = np.random.default_rng(20)


def tileable_noise(cells, size=SIZE):
    small = rng.random((cells, cells))
    tiled = np.tile(small, (3, 3))
    img = Image.fromarray((tiled * 255).astype('uint8')).resize((size * 3, size * 3), Image.BICUBIC)
    arr = np.asarray(img, dtype=np.float32) / 255
    return arr[size:2 * size, size:2 * size]


def fbm(octaves):
    total, weight = 0, 0
    for cells, w in octaves:
        total = total + w * tileable_noise(cells)
        weight += w
    return total / weight


def normalize(a):
    return (a - a.min()) / (a.max() - a.min())


def save(name, arr):
    img = Image.fromarray((arr.clip(0, 1) * 255).astype('uint8'), 'L')
    path = os.path.join(OUT, name)
    img.save(path, optimize=True)
    print(name, os.path.getsize(path) // 1024, 'KB')


def grain():
    base = fbm([(4, 0.45), (12, 0.3), (40, 0.15), (160, 0.1)])
    # Fibras: ruido estirado en dos direcciones.
    fib_a = np.asarray(Image.fromarray((tileable_noise(256) * 255).astype('uint8')).resize((SIZE, SIZE)))
    fibers = np.asarray(
        Image.fromarray(fib_a).filter(ImageFilter.GaussianBlur(radius=(6, 0.6))), dtype=np.float32) / 255
    speck = rng.random((SIZE, SIZE)).astype(np.float32)
    v = 0.7 * normalize(base) + 0.18 * normalize(fibers) + 0.12 * speck
    v = normalize(v)
    # Manchas suaves más oscuras.
    stains = normalize(fbm([(3, 0.6), (7, 0.4)]))
    v = v * (0.85 + 0.15 * stains)
    v = normalize(v)
    return 0.80 + 0.20 * v


save('texture_grain.png', grain())

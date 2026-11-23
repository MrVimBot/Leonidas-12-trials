#!/usr/bin/env python3
"""Arte PROVISIONAL de la pantalla de Continuar del menú principal, sacado de la maqueta JPG
de la artista (docs/reference/menu/continuar_con_partida.jpg, una captura a ×4: cada píxel de
arte son 4×4 píxeles de la imagen, empezando en (1, 3)).

Muestrea el centro de cada bloque (mediana de los 2×2 de dentro, para quitar el ruido del JPG),
borra (sin reducir la paleta: con una paleta corta el retrato y los laureles perdían
sus colores) lo que escribe o dibuja el juego (textos, corazones, moneda),
rellenando cada fila entre los píxeles de pergamino de los lados. Salida en
assets/ui/provisional/continuar/: fondo.png (268×149), volver.png / volver_encendido.png y
moneda.png. Sustituir por el .aseprite de la artista cuando llegue.

    python3 tools/menu_continuar/recortar_maqueta.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
MAQUETA = RAIZ / "docs/reference/menu/continuar_con_partida.jpg"
SALIDA = RAIZ / "assets/ui/provisional/continuar"
ESCALA = 4
ORIGEN = (1, 3)

# Rectángulos (x0, y0, x1, y1, ambos incluidos) en píxeles de arte que se borran del fondo.
BORRAR = [
	(56, 20, 126, 40),   # «Partida 1» y «Tiempo jugado:»
	(140, 18, 180, 31),  # corazones
	(140, 38, 152, 50),  # moneda
	(15, 64, 41, 73),    # «Jefes»
	(152, 64, 199, 73),  # «Inventario»
]
MONEDA = (141, 39, 151, 49)
VOLVER = (2, 125, 35, 147)


def muestrear() -> np.ndarray:
	a = np.asarray(Image.open(MAQUETA).convert("RGB")).astype(float)
	ox, oy = ORIGEN
	ancho = (a.shape[1] - ox) // ESCALA
	alto = (a.shape[0] - oy) // ESCALA
	out = np.zeros((alto, ancho, 3), np.uint8)
	for j in range(alto):
		for i in range(ancho):
			y, x = oy + ESCALA * j, ox + ESCALA * i
			out[j, i] = np.median(a[y + 1:y + 3, x + 1:x + 3].reshape(-1, 3), 0)
	return out


def borrar(img: np.ndarray, x0: int, y0: int, x1: int, y1: int) -> None:
	for y in range(y0, y1 + 1):
		izq = img[y, x0 - 1].astype(float)
		der = img[y, x1 + 1].astype(float)
		for x in range(x0, x1 + 1):
			t = (x - x0 + 1) / (x1 - x0 + 2)
			# Mitad y mitad: el pergamino tiene franjas horizontales, no degradados.
			img[y, x] = izq if t < 0.5 else der


def recorte(img: np.ndarray, r) -> Image.Image:
	x0, y0, x1, y1 = r
	return Image.fromarray(img[y0:y1 + 1, x0:x1 + 1])


def main() -> None:
	SALIDA.mkdir(parents=True, exist_ok=True)
	img = muestrear()
	limpio = img.copy()
	for r in BORRAR:
		borrar(limpio, *r)
	Image.fromarray(limpio).save(SALIDA / "fondo.png")

	volver = recorte(img, VOLVER)
	volver.save(SALIDA / "volver.png")
	# Encendido: el dorado más claro (lo oscuro, borde y flecha, se queda igual).
	v = np.asarray(volver).astype(float)
	claro = v.mean(2) > 110
	v[claro] = np.minimum(255, v[claro] * 1.18 + 12)
	Image.fromarray(v.astype(np.uint8)).save(SALIDA / "volver_encendido.png")

	# Moneda: fuera el pergamino (lo que no es dorado ni su borde oscuro).
	m = np.asarray(recorte(img, MONEDA).convert("RGBA")).copy()
	r, g, b = (m[..., k].astype(int) for k in range(3))
	pergamino = (abs(r - 186) < 22) & (abs(g - 148) < 22) & (abs(b - 117) < 22)
	m[pergamino, 3] = 0
	Image.fromarray(m).save(SALIDA / "moneda.png")
	print("Hecho:", ", ".join(p.name for p in sorted(SALIDA.glob("*.png"))))


if __name__ == "__main__":
	main()

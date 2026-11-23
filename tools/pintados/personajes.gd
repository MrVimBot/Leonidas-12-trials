extends RefCounted
## Tabla de los personajes PINTADOS de los niveles 2 y 3 (estilo "lineless", Guión p. 22): fotogramas
## sueltos a 1280×720 renderizados desde un rig, NO pixel art. La lee tools/pintados/normalizar.gd.
##
## Por personaje:
##   fuente      carpeta dentro de fuente/ (nivel2/<personaje>: la copia tools/pintados/copiar_fuente.sh;
##               nivel3/minotauro: copiada a mano de la entrega del 2026-11-22)
##   alto        alto en píxeles de MUNDO (480×270) de la animación `parado`. Leonidas mide ~25.
##               Es lo que fija la escala: cambiarlo y regenerar.
##   ancla       punto de apoyo en los PNG originales (px de 1280×720), medido en `parado`:
##               x = centro del cuerpo, y = línea donde apoya en el suelo. Pasa a ser la
##               posición del nodo (como los pies de Leonidas). Las animaciones de un mismo
##               personaje comparten cámara, así que una sola ancla vale para todas.
##   mira        hacia dónde mira el dibujo: "izquierda" (el animador espeja para la derecha)
##               o "frente".
##   animaciones nombre en el juego -> { carpeta, loop, fps (opcional, si no FPS) }
##
## Nombres de animación como en el resto del juego: parado, caminar, atacar, correr.

## Fotogramas por segundo de los renders (24, confirmado por Esteban el 2026-11-17).
const FPS := 24

## Píxeles de textura por píxel de mundo. Con 2, a 1920×1080 (×4) cada píxel de textura ocupa
## 2×2 de pantalla: algo suave, pero el estilo pintado lo aguanta. Con 4 se ve nítido pero
## Medusa sola ocuparía ~100 MB de memoria de vídeo (demasiado para la web).
const DENSIDAD := 2

const PERSONAJES := {
	"gamba": {
		"fuente": "nivel2/gamba",
		"alto": 28,
		"ancla": Vector2(665, 662),
		"mira": "izquierda",
		"animaciones": {
			"parado": {"carpeta": "idle", "loop": true},
			"caminar": {"carpeta": "caminando", "loop": true},
			"atacar": {"carpeta": "atacar", "loop": false},
		},
	},
	"pez_espada": {
		"fuente": "nivel2/pez_espada",
		"alto": 26,
		"ancla": Vector2(690, 537),
		"mira": "izquierda",
		"animaciones": {
			"parado": {"carpeta": "idle", "loop": true},
			"caminar": {"carpeta": "caminar", "loop": true},
			"correr": {"carpeta": "correr", "loop": true},
			"atacar": {"carpeta": "atacar", "loop": false},
		},
	},
	# La entrega la llama "serpiente": es el CÍCLOPE SERPIENTE (Guión p. 36, enemigo de la
	# cueva; tiene ataque). El comerciante de mapas (otra serpiente, p. 31) sería otro sprite.
	"ciclope_serpiente": {
		"fuente": "nivel2/serpiente",
		"alto": 34,
		"ancla": Vector2(667, 613),
		"mira": "izquierda",
		"animaciones": {
			"parado": {"carpeta": "idle", "loop": true},
			"caminar": {"carpeta": "caminando", "loop": true},
			"atacar": {"carpeta": "ataque", "loop": false},
		},
	},
	# Parado y caminar de frente; el ataque gira hacia la izquierda.
	"medusa": {
		"fuente": "nivel2/medusa",
		"alto": 96,
		"ancla": Vector2(648, 670),
		"mira": "frente",
		"animaciones": {
			"parado": {"carpeta": "idle", "loop": true},
			"caminar": {"carpeta": "caminar", "loop": true},
			"atacar": {"carpeta": "ataque", "loop": false},
		},
	},
	# Nivel 3 (PROVISIONAL, entrega del 2026-11-22): fotogramas de 2031×1142. Dibujado de frente
	# con la espada a SU izquierda (a la derecha de la pantalla): el animador lo espeja para mirar
	# a la izquierda (`lado_mira = DERECHA` en minotauro.tscn). Ancla medida en `idle`: centro
	# entre las pezuñas (x 336–397 y 570–628) y su fila más baja (1012). `atacar` a 30 fps: a 24
	# el golpe completo (140 fotogramas) duraba casi 6 s.
	"minotauro": {
		"fuente": "nivel3/minotauro",
		"alto": 60,
		"ancla": Vector2(483, 1010),
		"mira": "frente",
		"animaciones": {
			"parado": {"carpeta": "idle", "loop": true},
			"caminar": {"carpeta": "caminar", "loop": true},
			"atacar": {"carpeta": "atacar", "loop": false, "fps": 30},
		},
	},
}

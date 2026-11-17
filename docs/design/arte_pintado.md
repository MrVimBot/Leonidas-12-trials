# Arte pintado del nivel 2 ("lineless") — pipeline y uso

> Estado: 2026-11-17. Primera entrega de la artista: **gamba, pez espada, cíclope serpiente y
> Medusa**. El nivel 2 cambia de estilo (Guión p. 22): ilustración sin líneas, con textura,
> animada con rig. **No es pixel art**: no se pinta a 480×270 ni con filtro Nearest.

## Qué entregó la artista

Fotogramas PNG sueltos, 1280×720, RGBA (fondo transparente con RGB negro), uno por carpeta de
animación. Todas las animaciones de un personaje comparten cámara (están "en el sitio", sin
desplazamiento) y no hay fotogramas repetidos ni recortados por el borde.

| Personaje (juego) | Carpeta de la entrega | Animaciones (fotogramas) | Mira hacia |
|---|---|---|---|
| `gamba` | `gamba` | parado 47 (`idle`), caminar 47 (`caminando`), atacar 31 | izquierda |
| `pez_espada` | `pez espada` | parado 47, caminar 35, correr 12, atacar 29 | izquierda |
| `ciclope_serpiente` | `serpiente` | parado 35, caminar 53 (`caminando`), atacar 53 (`ataque`) | izquierda |
| `medusa` | `medusa` | parado 29, caminar 29, atacar 60 (`ataque`) | parado/caminar de **frente**; el ataque gira a la izquierda |

Solo hay **una vista** por personaje: el resto de direcciones se resuelve espejando
(`AnimadorDireccional.espejar_sin_direccion = true`, como la flor falsa y el tiburón).
No hay animaciones de daño ni de muerte (se usan parpadeo y `ComponenteMuerte`).

## Dónde está cada cosa

| Qué | Dónde | ¿En git? |
|---|---|---|
| Originales copiados (≈160 MB) | `fuente/nivel2/<personaje>/<anim>/*.png` (con `.gdignore`: Godot no los importa) | **No** (`.gitignore`) |
| Tabla de personajes (escala, ancla, animaciones) | `tools/pintados/personajes.gd` | sí |
| Hojas normalizadas + manifiesto | `assets/sprites/pintados/<personaje>/{<anim>.png, <personaje>.json}` (≈6 MB en total) | sí |
| SpriteFrames | `resources/sprite_frames/{gamba,pez_espada,ciclope_serpiente,medusa}.tres` | sí |
| Vista previa (escala junto a Leonidas) | `tools/pintados/vista_previa.tscn` (F6; J cambia de animación, Espacio espeja) | sí |

## Regenerar (si la artista entrega de nuevo o se cambia la escala)

```bash
tools/pintados/copiar_fuente.sh "/ruta/a/Assets nivel 2"
```

```bash
tools/pintados/normalizar.sh
```

(`normalizar.sh medusa` para uno solo.) Mejor con el editor **cerrado**. Si está abierto:
ejecutar solo `godot --headless --path . --script res://tools/pintados/normalizar.gd`, dejar
que el editor importe (o `filesystem_manage scan` por MCP), poner `mipmaps/generate=true` en los
`.import` de `assets/sprites/pintados/` y reimportar, y luego
`godot --headless --path . --script res://tools/pintados/construir_sprite_frames.gd`.

Un personaje nuevo: añadir su entrada a `tools/pintados/personajes.gd` (medir el `ancla` en
un fotograma de `parado`: x = centro del cuerpo, y = fila donde apoya) y regenerar.

## Cómo se normaliza (por qué así)

1. **Un lienzo por personaje**: la unión de todos sus fotogramas de todas las animaciones,
   simétrica alrededor del ancla. Todas las animaciones usan el mismo recorte y la misma escala
   → no "salta" al cambiar de animación y `flip_h` espeja sobre el ancla.
2. **Escala**: `alto` (px de mundo de `parado`) × `DENSIDAD` / alto real de `parado`.
   `DENSIDAD = 2` → 2 píxeles de textura por píxel de mundo (a 1920×1080, ×4, cada texel ocupa
   2×2 px de pantalla). Con 4 se vería más nítido pero Medusa sola gastaría ~100 MB de vídeo.
3. **Escalado con alfa premultiplicado** (Lanczos): los transparentes son negros y sin
   premultiplicar saldría un halo oscuro en los bordes.
4. **Recorte por animación + `AtlasTexture.margin`**: cada hoja guarda solo lo que usa esa
   animación; el margen devuelve a cada fotograma el tamaño del lienzo (como el "trim" de los
   empaquetadores de texturas). 2 texels de separación entre celdas (filtro lineal + mipmaps).
5. **Importación**: filtro lineal y **mipmaps activados** en los `.import` (para ventanas
   pequeñas). Sin compresión (Lossless): a esta densidad cabe todo en ~35 MB.

Resultado con la escala actual (confirmada por Esteban el 2026-11-17):

| Personaje | `alto` | Lienzo en mundo | `offset` | Memoria (sin mipmaps) |
|---|---|---|---|---|
| gamba | 28 | 47×30 | (0, −25.5) | 2,5 MB |
| pez_espada | 26 | 75×36 | (0, −16) | 4,1 MB |
| ciclope_serpiente | 34 | 65×40 | (0, −38.5) | 3,6 MB |
| medusa | 96 | 132×108 | (0, −92) | 20,1 MB |

## Cómo usarlo en una escena

```
AnimatedSprite2D "Sprite"
  sprite_frames  = res://resources/sprite_frames/<personaje>.tres
  centered       = true            (por defecto)
  offset         = meta "offset" del SpriteFrames   (la tabla de arriba)
  scale          = (0.5, 0.5)      (meta "escala" = 1 / DENSIDAD)
  texture_filter = Linear Mipmap   (TEXTURE_FILTER_LINEAR_WITH_MIPMAPS = 4)
```

Así la **posición del nodo es el punto de apoyo** (como los pies de Leonidas) y el orden por Y
funciona igual que con el resto. Metadatos del `.tres`: `offset`, `escala`, `densidad`,
`lienzo`, `ancla`, `mira`, `alto_mundo`.

**Ojo:** quien anime la escala del sprite (p. ej. `ComponenteMuerte`, que aplasta el `visual`
a (1.3, 0.3)) debe multiplicar la escala que ya tiene, o apuntar a un nodo padre `Visual` con
escala 1. Ver `docs/plan/nivel2/02_base_enemigo_pintado.md`.

## Modo de dibujo

En el modo normal del juego (`viewport` de 480×270) todo se rasteriza a 480×270 y el arte
pintado se ve borroso/pixelado. En la vista previa se usa `Pantalla.modo_pintura(self, true)`
(CANVAS_ITEMS, como el libro y la cinemática): el arte pintado se dibuja a la resolución de la
ventana y el pixel art sigue nítido (Nearest a ×4). Las zonas del nivel 2 tendrán que dibujarse
así: plan `docs/plan/nivel2/01_modo_pintado.md`.

## Fotogramas clave medidos (para las hitbox)

Medidos sobre el avance del dibujo (índices desde 0, a 24 fps):

| Animación | Fases |
|---|---|
| medusa `atacar` (60) | 0–23 levanta la espada (arriba del todo en 16) · **24–27 golpe al suelo** (alcance máximo en 25) · 28–47 espada clavada (ventana para atacarla) · 48–59 recupera |
| gamba `atacar` (31) | 0–11 se prepara · **12–15 mordisco** (alcance máximo en 14) · 16–30 vuelve |
| pez_espada `atacar` (29) | **8–10 primera estocada** · 11–17 se recoge · **19–24 segunda estocada** · 25–28 vuelve |
| ciclope_serpiente `atacar` (53) | 0–11 se yergue · **12–28 baja la cabeza hacia delante** (el rayo sale hacia el 13) · 29–52 vuelve |

## Decisiones y pendiente

- Decidido el 2026-11-17: 24 fps, la escala de la tabla, y Leonidas **sigue en pixel art** en el
  nivel 2 (no habrá versión lineless).
- Sin arte todavía: el rayo del cíclope, los trozos de estatua de Medusa, la barra de vida de
  la jefa (5 corazones, Guión p. 38), animaciones de daño/derrota/súplica de Medusa, fondos y
  tiles del nivel 2, gran pinza, sirena, comerciante de mapas, escudo, coco.

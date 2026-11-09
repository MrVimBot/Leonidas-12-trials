# Las casi 12 pruebas de Leonidas — contexto del proyecto

RPG 2D top-down (cámara cenital) de mitología griega. Estilo de referencia: *Zelda: Minish Cap* y *Pokémon BW*.
Proyecto universitario. **Un solo programador** (Esteban, Godot + código); el arte (sprites en Aseprite) lo hace otra persona del equipo; otras compañeras hacen testing y guion.
Idioma del equipo y de los textos del juego: **español**. Responde en español.

## Stack
- Godot **4.7.2** (renderer GL Compatibility), lenguaje **GDScript**.
- Addons ya instalados: **Godot AI** (MCP, servidor local) y **Aseprite Wizard**.
- Aseprite compilado localmente en `/Users/mrrobote05/Developer/aseprite/build/bin/aseprite` (alias `aseprite`). Es una compilación personal: la licencia **prohíbe redistribuirlo**. Nunca lo agregues al repo.
- Repo: `git@github.com:MrVimBot/Leonidas-12-trials.git` (privado, rama `main`, remoto por SSH).
- Para controlar el editor en vivo usa las herramientas MCP de Godot AI; prefiérelas a editar `project.godot` o `.tscn` a mano mientras el editor está abierto (el editor puede sobrescribir los cambios).

## Decisiones de diseño técnico (acordadas)
- Resolución base **480×270** (16:9), escala entera ×4 a 1920×1080. Aplicado: `stretch/mode=viewport`, `aspect=keep`, `scale_mode=integer`, ventana 1920×1080.
- Filtro de texturas por defecto: **Nearest** (pixel art). Aplicado.
- Tiles de 16 px. Leonidas mide ~25 px de alto.
- Fuente de diálogos: `assets/fonts/perfect_dos_vga_437.ttf` (pixel, tipo DOS).
- Movimiento en 8 direcciones. La animación lateral se **espeja** para izquierda/derecha.

## Alcance de la entrega (plazo: ~1 mes desde el 2026-10-26)
1. **Nivel 1 completo:** cinemática del cuarto → casa → pueblo (zona segura, tutorial integrado, NPC, mercader, sabios que dan la espada y la misión) → bosque (primer combate) → playa → minijuego de barco.
2. **Nivel 2:** isla de Medusa con su jefe (Medusa).
Los niveles 3+ (Khymera, Aracne, Hidra, Minotauro, Ares...) existen en el guion pero **no están en alcance**.

## Mecánicas (resumen; detalle en `docs/design/`)
- Movimiento libre 8 direcciones, cámara sigue al jugador. Pantallas por zona con carga al salir.
- Ataque con arma base (la espada, se obtiene con los sabios). Voltereta ("roll"/pirueta) que consume estamina. Agarrar y lanzar objetos (despejar caminos, romper, atacar a distancia). Cortar arbustos (dan monedas/corazones).
- Vida en **corazones**; sin vida = game over / reinicio en el último punto de control. HUD: corazones, objeto equipado, bolsa/inventario, contador de monedas.
- NPC con 3 tipos de interacción: diálogo normal, misión, tienda. Mercader: gasta monedas en consumibles.
- Consumible del nivel 1: manzanas (se obtienen golpeando árboles; el árbol se resetea al cambiar de bioma).
- Enemigos del nivel 1: **seta bomba**, **falsa flor**, **montón Tocotón** (tanque que bloquea caminos).
- Barco: solo movimiento, esquivar obstáculos; sin ataque.
- Diálogos: cuadro con pestaña de nombre y flecha de "continuar" (`assets/ui/dialog_box.png`, `dialog_continue_arrow.png`; ambos comparten el mismo lienzo, la flecha va abajo a la derecha).

## Cinemática inicial (referencia en `docs/design/guion_primera_cinematica.md` y `docs/reference/`)
Un prototipo previo en **Unity 6** mostró: ilustración con confeti (cumpleaños) → cuarto en pixel art con diálogo → carta de los sabios → exterior pintado. La madre aparece con el nombre **Kathita** en el cuadro de diálogo. No hay que portar código de Unity, solo el diseño.

## Estructura de carpetas
```
assets/{sprites,ui,fonts,backgrounds/cinematica,audio/{music,sfx}}
scenes/{player,npcs,enemies,levels,ui,cinematics,items}
scripts/{player,npcs,enemies,systems,ui}
autoload/  resources/{sprite_frames,dialogues}  tools/  docs/{design,reference}
```
Convención: nombres de archivo en `snake_case`, sin espacios ni acentos; escenas y scripts con el mismo nombre base.

## Estado de los sprites (IMPORTANTE)
Los `.aseprite` de `assets/sprites/` ya están en snake_case (renombrados desde el MCP de Godot; `leonidas mini (1)` → `leonidas_mini.aseprite`). `leonidas.aseprite` es otro archivo y lo usa `scenes/character_body_2d.tscn`.

En `leonidas_mini.aseprite` (100×310 px, 16 frames, sin tags) las animaciones son una **rejilla**: 3 columnas (frente / lado / espalda; el barco va lado / frente / espalda) × filas por acción. El "lado" mira a la **izquierda** (derecha = `flip_h`). Hallazgos: la mayoría son ciclos de **8 frames** (8–15 repiten 0–7); `parado*` y `barco_quieto*` son un único frame; la paleta de la artista está dentro de `parado normal` (x 24–27).
Pendiente con la artista: la fila `Layer 17` (y 226–255) no tiene nombre (¿recibir daño?); se exporta como `fila_17_*`.

**Pipeline de sprites (hecho):**
- `tools/sprite_layouts/<nombre>.lua`: tabla con la rejilla de cada `.aseprite` (columnas, filas, línea de pies, loop).
- `tools/export_strips.lua`: script de la CLI de Aseprite; exporta una tira PNG por animación + JSON a `assets/sprites/strips/<nombre>/` (detecta frames repetidos/vacíos y el periodo del ciclo).
- `tools/sprite_frames_builder.gd` + `tools/build_sprite_frames.gd`: construyen `resources/sprite_frames/<nombre>.tres` usando solo los frames del periodo.
- Todo con un comando: `tools/export_sprites.sh [nombre]` (trabaja sobre una copia temporal; no toca los originales).
- Celda 40×40 con los pies en (20, 34): en un `AnimatedSprite2D` usar `offset = (0, -14)` para que la posición del nodo sean los pies.
- Para añadir otro sprite (seta_bomba, flor_falsa, npc_burro, npc_zorro…): crear su layout en `tools/sprite_layouts/` y ejecutar el script.

## Assets que faltan o no se vieron
Recibir daño y morir (Leonidas), monedas, arbustos, enemigo Tocotón, ítem de la espada, árbol de manzanas, tiles del pueblo/bosque/playa, obstáculos del mar (el barco con Leonidas sí está en `leonidas_mini`), jefe Medusa. Puede que parte esté en `todos_los_assets.aseprite` (1000×600, un solo frame).

## Reglas del repo
- GitHub rechaza archivos >100 MB. **Fuera del repo** (están en la carpeta externa `Leonidas_12_pruebas/Assets_guion_todo`): el PDF "Guión Multimedia" (146 MB), el video del prototipo (110 MB), `playa entero.png` (16 MB) y los 360 PNG de "Fondo con puesta sol" (~430 MB). Si hacen falta, usar Git LFS.
- No subir el binario de Aseprite ni nada de `.godot/`.
- Commits pequeños y en español; avisar al usuario antes de reescribir historial ya subido.

## Documentos de diseño
`docs/design/`: `jugabilidad_primera_parte.md` (el más claro), `guion_primera_cinematica.md`, `jugabilidad_laminas.txt` y `guion_multimedia_laminas.txt` (texto extraído de PDFs de láminas; tiene ruido de maquetación, y las imágenes de las láminas no están incluidas).

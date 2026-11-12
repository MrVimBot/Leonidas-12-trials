# Plan: mapa completo del juego (provisional y jugable)

> **Para quién es:** un modelo (Opus/Sonnet) o persona que va a implementarlo sin más contexto.
> **Antes de empezar:** lee `CLAUDE.md` entero (arquitectura, zonas, tiles, reglas del repo). Responde y escribe en español.
> **Escrito el 2026-11-10** a partir del boceto a mano de Esteban (flujo de niveles).

## 1. Objetivo y alcance

Dejar **todas las zonas del boceto como escenas jugables y conectadas**: se puede caminar de la ciudad hasta la sala de Medusa y volver, con fundido entre zonas. Los trazados son **provisionales** (improvisados aquí) y se usa el arte que ya existe; lo que falta se sustituye por arte provisional generado por script.

```
            casa_arbol
                ↑ (puerta norte)
             pueblo ──→ este: "Inaccesible en la demo" (cartel, sin salida)
                ↓ (puerta sur)
             bosque
                ↓
   playa  (boceto: "Orilla del mar")
                ↓ (muelle)
    mar   (boceto: "Barquito")
                ↓
 isla_orilla  (boceto: "Orilla de isla")
                ↓
   isla   (boceto: "Isla entera") ──→ cueva_medusa ──→ cueva_jefe
```

**Dentro del alcance:** escenas de zona, suelo, decorados, colisiones, entradas/salidas, límites, arte provisional, un verificador automático, actualizar `CLAUDE.md`.

**Fuera del alcance (NO hacer):** controles o mecánicas nuevas (modo barco, mecanismo de la cueva, cofres), Medusa, enemigos nuevos, NPC nuevos con guion, cambios en `Game`, `Jugador`, HUD o diálogos. En `mar` Leonidas **camina** sobre agua provisional; el minijuego del barco será otra tarea.

### Decisiones ya tomadas (no volver a discutirlas)
1. **El bosque pasa al sur del pueblo** (el boceto y el guion p. 8 dicen "ve al sur"). Hoy la puerta norte lleva al bosque y la sur está cerrada: se invierte. La puerta norte pasa a llevar a `casa_arbol`.
2. `bosque.tscn` actual (32×20, de prueba) **se sustituye** por el generado. Conserva sus enemigos (setas y flores).
3. Las zonas nuevas las **genera un script** (como `tools/build_pueblo.gd`), no se pintan a mano: es reproducible y verificable. `pueblo.tscn` **no se regenera** (tiene retoques a mano): se edita su texto.
4. Nivel 2 (isla y cuevas) se hace con el pixel art actual aunque el guion pida otra estética (p. 22): es provisional.
5. Todo el arte provisional va en carpetas `provisional/` para sustituirlo fácil.

## 2. Datos que necesitas

**Pantalla:** 480×270 px = 30×17 tiles de 16 px. Ninguna zona puede ser menor que eso.

**Tiles de `resources/tilesets/naturaleza.tres`** (fuente 0; coordenadas columna,fila):

| Tile | Qué es | Sólido |
|---|---|---|
| (0,0) | pasto (el `VariadorPasto` reparte 1–3,0 después) | no |
| (12,0) | seto oscuro: sirve de borde de bosque | **sí** |
| (16,0) | agua de estanque | **sí** |
| (19,0) | mar | **sí** |
| (0,1) | mar con orilla **abajo** (mar arriba, tierra abajo) | **sí** |
| (3,1) | arena / camino de tierra (`CAMINO`) | no |
| (1,1) | arena con piedras (`CAMINO_PIEDRAS`, variante al 10–15 %) | no |
| (6,1) | baldosa | no |

No hay tiles de cueva, de mar navegable, de muelle ni transición arena↔pasto: se resuelven con el tileset provisional (fase 1) y bordes rectos.

**Decorados disponibles** (`assets/sprites/entorno/*.png`, se usan con `scenes/entorno/decorado.tscn`): `pino`, `cipres`, `cipres_dorado`, `arbol_naranja`, `manzano_1..4`, `arbusto_1`, `arbusto_2`, `arbusto_verde`, `arbusto_dorado`, `roca`, `roca_grande`, `tronco`, `troncos_apilados`, `columna_1..3`, `columna_rota_1..3`, `arco_ruinas`, `estatua`, `pedestal`, `cartel`, `casa_tocon` (279×237, la "casa árbol"), `macizo_flores_1..2`, `girasol`. Con `sombra = false` en: rocas, troncos, arbustos 1 y 2, macizos, estatua, casas.

**Ilustraciones grandes** (`assets/sprites/environment/`, NO son pixel art): `palmera.png` (2432×3061), `mini_palmera.png` (1261×1207), `roca_1..3.png` (~600×400). Se reducen en la fase 1.

**Enemigos:** `scenes/enemies/seta_bomba.tscn`, `scenes/enemies/flor_falsa.tscn` (solo en el bosque).

**Colisión del jugador:** rectángulo 10×6 centrado en (0, −3) respecto a los pies; máscara 65 (capas 1 mundo + 7 obstáculo bajo).

**Convenciones de este plan**
- Rectángulos de tiles: `[col0, fila0, col1, fila1]`, **inclusivos**.
- Tile → píxel del centro: `(col*16 + 8, fila*16 + 8)`.
- Salida en un borde: `SalidaZona` de 16 px de grosor pegada al borde; su entrada de vuelta va **≥ 40 px hacia dentro** (si se solapan, el jugador rebota entre zonas).
- Toda zona tiene además la entrada `inicio` (misma posición que la primera entrada de su tabla) para poder probarla con `zona_inicial`.

## 3. Preparación (fase 0)

1. `git status` debe estar limpio. Trabaja en `main` salvo que Esteban diga otra cosa. **No hagas push.** Haz un commit pequeño en español al final de cada fase solo si Esteban lo autorizó al encargarte el trabajo; si no, deja los cambios sin confirmar y dilo.
2. **Pide a Esteban que cierre el editor de Godot** antes de ejecutar scripts `--headless` (con el editor abierto, este no recarga lo regenerado y puede sobrescribir escenas o borrar autoloads de `project.godot`). Si no puede cerrarlo, sigue, pero no abras en el editor las escenas que generas hasta terminar y al final pide "Proyecto → Recargar proyecto actual".
3. Comprueba `godot --version` → `4.7.2`. Todos los comandos se ejecutan desde la raíz del repo.
4. Lee `tools/build_pueblo.gd` completo: los generadores nuevos copian su estilo (`extends SceneTree`, `_initialize()`, `owner = raíz`, `PackedScene.pack`, conservar UID con `ResourceSaver.set_uid`, cargar scripts con `load()` y asignar propiedades con `set()`).

## 4. Fase 1 — Arte provisional

Crea `tools/build_arte_provisional.gd` (`extends SceneTree`; usa la clase `Image`; guarda con `save_png`). Carga los PNG de origen con `Image.load_from_file(ProjectSettings.globalize_path(ruta))`.

### 4.1 `assets/tilesets/tiles_provisional.png` (144×16, 9 tiles de 16×16 **sin separación**)

| Col | Nombre | Dibujo | Sólido |
|---|---|---|---|
| 0 | `SUELO_CUEVA` | liso `#4a4458` | no |
| 1 | `SUELO_CUEVA_B` | como el 0 con 4–5 píxeles sueltos `#3b3648` | no |
| 2 | `PARED_CUEVA` | `#2a2438` con una línea superior de 2 px `#3d3550` | **sí** |
| 3 | `VACIO` | liso `#0b0a12` | **sí** |
| 4 | `MAR_NAV` | liso `#3f8fa8` | no |
| 5 | `MAR_NAV_OLA` | como el 4 con 2 rayas horizontales cortas `#7cc4d0` | no |
| 6 | `LOSA_JEFE` | `#6a5f78` con borde de 1 px `#574d65` | no |
| 7 | `MUELLE` | madera `#8a5a32` con rayas horizontales `#6b4425` cada 4 px | no |
| 8 | `ARRECIFE` | `#1f5f78` con 3 píxeles `#2f7f98` | **sí** |

### 4.2 Sprites en `assets/sprites/entorno/provisional/`

| Archivo | Origen | Tamaño final |
|---|---|---|
| `palmera.png` | `environment/palmera.png` | 56×70 |
| `mini_palmera.png` | `environment/mini_palmera.png` | 40×38 |
| `roca_mar_1.png` / `_2` / `_3` | `environment/roca_1..3.png` | 48×32 / 56×31 / 44×31 |
| `entrada_cueva.png` | dibujado | 64×56 |

Reducción: `resize(w, h, Image.INTERPOLATE_LANCZOS)` y luego **umbral de alfa** (alfa < 128 → 0; si no → 255) para que los bordes queden duros. `entrada_cueva.png`: montículo (media elipse apoyada abajo) `#6b6257` con sombra `#514a42` en el tercio inferior, y un arco negro `#0b0a12` de 24×30 centrado abajo.

### 4.3 TileSet provisional

En `tools/build_tilesets.gd` añade un segundo elemento a `TILESETS`:
`textura = res://assets/tilesets/tiles_provisional.png`, `salida = res://resources/tilesets/provisional.tres`, `tamano = (16,16)`, `separacion = (0,0)`, `tiles = [[0, 0, 8]]`, `solidos = [(2,0), (3,0), (8,0)]`, sin `volteables` ni `transformables`.

### 4.4 Ejecutar

```bash
godot --headless --path . --script res://tools/build_arte_provisional.gd
godot --headless --path . --import
godot --headless --path . --script res://tools/build_tilesets.gd
```

**Hecho cuando:** existen los 6 PNG + el de tiles + sus `.import`, y `provisional.tres`; `git diff resources/tilesets/naturaleza.tres` no cambia nada relevante (mismo UID). Abre los PNG con la herramienta de lectura de imágenes y comprueba que se reconocen (palmera con silueta limpia, sin halo).

Comprueba también que `tools/export_sprites.sh` / `tools/export_recortes.lua` no borran la subcarpeta `provisional/` (léelos; si limpian `entorno/`, mueve lo provisional a `assets/sprites/provisional/` y ajusta las rutas de este plan).

## 5. Fase 2 — Constructor de zonas y verificador

### 5.1 `tools/zonas/constructor_zona.gd` (`extends RefCounted`, sin `class_name`)

Los generadores lo cargan con `const Constructor := preload("res://tools/zonas/constructor_zona.gd")`. Encapsula lo que `build_pueblo.gd` hace a mano. API mínima:

| Método | Qué hace |
|---|---|
| `_init(nodo: String, nombre_zona: String, ancho: int, alto: int, semilla: int)` | Crea la raíz `Node2D` (y_sort, script `zona.gd`), `Suelo` (TileMapLayer, `naturaleza.tres`, z −1), `SueloProvisional` (TileMapLayer, `provisional.tres`, z −1, **después** de `Suelo`), `Objetos` (y_sort), `Entradas`, `Limites` (StaticBody2D, capa 1, máscara 0). Asigna `suelo = Suelo` y **`limites_camara = Rect2i(0, 0, ancho*16, alto*16)`**. |
| `rect(r, tile, prov := false, variante := Vector2i(-1,-1), prob := 0.0)` | Pinta un rectángulo. Con `prov = true` pinta en `SueloProvisional` **y borra** esas celdas de `Suelo` (y al revés), para que nunca quede un tile sólido escondido debajo. `variante`/`prob`: sustituye al azar. Recorta al mapa. |
| `elipse(centro: Vector2i, radios: Vector2, tile, prov := false)` | Rellena las celdas con `((c-cx)/rx)² + ((f-cy)/ry)² ≤ 1`. |
| `marco(grosor: int, tile, prov := false)` | Anillo en el borde del mapa. |
| `deco(grupo: String, textura: String, pos: Vector2, op := {}) -> Node2D` | Instancia `decorado.tscn` bajo `Objetos/<grupo>` (lo crea con y_sort si no existe). `textura` = ruta relativa a `assets/sprites/entorno/` sin `.png` (admite `provisional/palmera`). `op`: `solido`, `sombra`, `base`, `desplazamiento_base`. |
| `dispersar(grupo, texturas: Array, r_tiles, paso: Vector2, op := {})` | Rejilla al tresbolillo con desplazamiento aleatorio (±8, ±5 px), como `_poner_bosquecillos`. **Se salta** una posición si: el tile bajo ella (o 40 px por encima, o ±16 px a los lados) es camino/arena de camino, agua, mar o cualquier tile provisional; o está a < 48 px de una entrada, salida u objeto registrado con `reservar()`. |
| `reservar(pos: Vector2, radio: float)` | Marca una zona donde `dispersar` no pone nada (claros, estatuas, enemigos). |
| `instancia(grupo, ruta_escena, pos) -> Node` | Instancia una escena (enemigos) con `GEN_EDIT_STATE_INSTANCE`. Llama a `reservar(pos, 40)`. |
| `entrada(nombre, pos)` | `Marker2D` en `Entradas`. La primera llamada crea también `inicio` en el mismo sitio. |
| `salida(nombre, centro, tamano, zona_destino, entrada_destino)` | `Area2D` con `salida_zona.gd` + `CollisionShape2D` "Forma" (RectangleShape2D). `zona_destino` = nombre corto (`"playa"` → `res://scenes/levels/playa.tscn`). |
| `limite(nombre, r: Rect2)` | Pared invisible (CollisionShape2D en `Limites`). |
| `cartel(pos, ruta_dialogo)` | Decorado `cartel` + `ZonaDialogo` (copia `_poner_cartel` de `build_pueblo.gd`). |
| `marcador(nombre, pos)` | `Marker2D` hijo de la raíz (puntos para tareas futuras). |
| `guardar(ruta)` | Añade `VariadorPasto` (`capa = Suelo`, `semilla`, llama a `variar`) solo si `Suelo` tiene celdas; empaqueta; guarda **conservando el UID** si el archivo existía; libera la raíz. Devuelve `Error`. |

Todo nodo creado lleva `owner = raíz` (si no, no se guarda). Usa un `RandomNumberGenerator` con la semilla dada: el resultado debe ser idéntico en cada ejecución.

### 5.2 `tools/build_zonas.gd` (`extends SceneTree`)

Una función por zona (`_bosque()`, `_playa()`…) y un diccionario nombre → función. Sin argumentos construye todas; con nombres (`-- bosque playa`, leídos con `OS.get_cmdline_user_args()`) solo esas. Cabecera con el aviso **"⚠ SOBRESCRIBE las escenas; si una zona se retoca a mano, quítala de aquí"**.

```bash
godot --headless --path . --script res://tools/build_zonas.gd            # todas
godot --headless --path . --script res://tools/build_zonas.gd -- bosque  # una
```

### 5.3 `tools/verificar_zonas.gd` (`extends SceneTree`) — la prueba de aceptación

Para cada `.tscn` de `scenes/levels/`:
1. **Enlaces:** cada `SalidaZona` tiene `zona_destino` existente y esa escena tiene `Entradas/<entrada_destino>`.
2. **Entradas libres:** en cada `Marker2D` de `Entradas`, la forma del jugador (rectángulo 10×6 en (0, −3), máscara `1 | 64`) no choca con nada, y la entrada está a ≥ 24 px del rectángulo de cualquier `SalidaZona`.
3. **Se puede caminar:** añade la zona al árbol, espera 2 `physics_frame`, y haz una búsqueda en anchura sobre una rejilla de **8 px** dentro de `limites_camara` (4 vecinos), consultando `direct_space_state.intersect_shape` con la forma del jugador. Desde **cada** entrada debe alcanzarse **cada** salida de la zona (alguna celda dentro de su rectángulo).
4. **Grafo:** partiendo de `pueblo`/`inicio` y siguiendo salidas se visitan las 9 zonas, y desde `cueva_jefe` se vuelve a `pueblo`.

Imprime una tabla (zona, entradas, salidas, OK/FALLO con el motivo) y termina con código 1 si algo falla. Si al instanciar zonas los enemigos o NPC dan errores por faltar autoloads en modo `--script`, quita los `CharacterBody2D` de la copia instanciada antes de la búsqueda (no cuentan como obstáculo fijo).

```bash
godot --headless --path . --script res://tools/verificar_zonas.gd
```

**Hecho cuando:** el verificador corre sobre `pueblo` + `bosque` actuales sin fallar por errores propios (antes de cambiar nada, los dos deben salir OK en los puntos 1–3).

## 6. Fase 3 — Las zonas (una por una: construir → verificar → mirar)

Tras cada zona: ejecutar `build_zonas.gd -- <zona>`, luego el verificador, y corregir los datos hasta que pase. Las posiciones de abajo son el punto de partida; puedes moverlas si el verificador o la captura lo piden, **sin cambiar los nombres de entradas/salidas ni el tamaño de las aberturas**.

Nombres de tiles: `PASTO (0,0)`, `SETO (12,0)`, `AGUA (16,0)`, `MAR (19,0)`, `MAR_ORILLA (0,1)`, `ARENA (3,1)` con variante `(1,1)` al 12 %; provisionales según 4.1.

### 6.1 `bosque` — 64×56 tiles (1024×896 px). Semilla 21

Suelo, en este orden:
1. Todo `PASTO`. `marco(2, SETO)`.
2. Aberturas (pintar `ARENA`): arriba `[30,0,33,1]`; abajo `[44,54,47,55]`.
3. Camino `ARENA` de 2 de ancho: `[31,0,32,12]`, `[14,11,32,12]`, `[14,11,15,30]`, `[14,29,46,30]`, `[45,29,46,55]`.
4. Estanque `AGUA`: `[36,14,47,21]`.

Objetos:
- Claro de combate: `reservar` el rectángulo `[18,32,42,40]` (centro y radio amplio, o varias llamadas).
- Arboledas **sólidas** con `dispersar("Arboles", ["pino","cipres","pino","arbol_naranja","cipres_dorado"], r, Vector2(54, 36))` en: `[4,4,26,9]`, `[36,4,59,10]`, `[20,15,32,26]`, `[4,14,10,40]`, `[50,24,59,50]`, `[4,43,40,51]`.
- Sobre el marco de seto, árboles **sin colisión** (`solido = false`) con paso (46, 34), para que el borde parezca bosque y no un muro: franjas `[0,0,63,2]`, `[0,53,63,55]`, `[0,0,2,55]`, `[61,0,63,55]` (se saltan solas las aberturas por la regla del camino).
- Manzanos (sólidos) en tiles (18,33) `manzano_1`, (41,39) `manzano_2`, (27,41) `manzano_3`.
- Sueltos en el claro: `roca` (22,35), `tronco` (33,38), `arbusto_verde` (25,39) y (38,33), `roca_grande` (30,33). Rocas y tronco con `sombra = false`.
- Enemigos (`instancia("Enemigos", …)`): `seta_bomba` en tiles (24,31), (38,36), (30,38); `flor_falsa` en (20,36), (36,33), (42,31).

| Entrada | Posición px | | Salida | Centro px | Tamaño | Destino |
|---|---|---|---|---|---|---|
| `desde_pueblo` | (512, 40) | | `SalidaPueblo` | (512, 8) | 64×16 | `pueblo` / `desde_bosque` |
| `desde_playa` | (736, 856) | | `SalidaPlaya` | (736, 888) | 64×16 | `playa` / `desde_bosque` |

### 6.2 `playa` — 60×34 tiles (960×544 px). Semilla 22. Boceto: árboles arriba, mar y barca abajo

Suelo:
1. Filas 0–9 `PASTO`; filas 10–27 `ARENA`; filas 28–33 `MAR`.
2. `SETO`: `[0,0,59,1]`, `[0,2,1,9]`, `[58,2,59,9]`. Abertura arriba: `[28,0,31,1]` → `ARENA`.
3. Camino `ARENA`: `[29,0,30,9]`.
4. Muelle (provisional, `MUELLE`, `prov = true`): `[28,26,31,33]` (entra en el mar; al pintar en provisional se borra el `MAR` sólido de debajo).

Objetos y límites:
- `limite("Oeste", Rect2(-16, 160, 32, 290))` y `limite("Este", Rect2(944, 160, 32, 290))`; delante, `roca_grande` (sólida, sin sombra) cada 40 px en x = 20 y x = 940, de y = 180 a y = 440.
- Árboles sin colisión sobre los setos (como en el bosque) y arboleda sólida `dispersar` en `[3,3,25,8]` y `[35,3,56,8]`.
- Palmeras: `provisional/palmera` en tiles (8,13), (20,12), (42,13), (53,12), (14,20), (48,21); `provisional/mini_palmera` en (25,15), (37,16), (6,24), (55,24). Base sólida pequeña: `base = Vector2(12, 6)`.
- `roca` (17,17) y (45,23); `tronco` (36,22); `troncos_apilados` (24,24).
- Cartel junto al muelle: `cartel(Vector2(432, 420), "res://resources/dialogues/cartel_muelle.tres")`.

| Entrada | Posición px | | Salida | Centro px | Tamaño | Destino |
|---|---|---|---|---|---|---|
| `desde_bosque` | (480, 40) | | `SalidaBosque` | (480, 8) | 64×16 | `bosque` / `desde_playa` |
| `desde_mar` | (480, 472) | | `SalidaMar` | (480, 536) | 48×16 | `mar` / `desde_playa` |

### 6.3 `mar` — 48×90 tiles (768×1440 px). Semilla 23. Boceto: "Barquito" (travesía hacia el sur)

> **Actualizado (2026-11-10):** ahora es el minijuego del barco (`modo_barco = true`, muelles `[22,0,25,1]` / `[22,88,25,89]`, entradas (384,96)/(384,1344), salidas (384,40)/(384,1400), 6 remolinos y 4 tiburones en `Objetos/Peligros`, sin `PuntoBarco`, sin `MAR_NAV_OLA`: las olas las dibuja el shader). Detalle en `plan_minijuego_barco.md`; lo de abajo es el trazado original.

Todo en `SueloProvisional` (`Suelo` queda vacío):
1. Todo `MAR_NAV` con variante `MAR_NAV_OLA` al 12 %.
2. `ARRECIFE` (sólido): `[0,0,2,89]`, `[45,0,47,89]`, `[0,0,47,1]`, `[0,88,47,89]`.
3. Muelles `MUELLE`: arriba `[22,0,25,3]`; abajo `[22,86,25,89]`.

Obstáculos (decorados sólidos, `sombra = false`, alternando `provisional/roca_mar_1/2/3`), en tiles:
(10,10) (30,12) (38,18) (18,20) (8,28) (26,30) (36,34) (14,40) (28,44) (40,48) (8,52) (22,56) (34,60) (12,66) (26,70) (38,74) (16,80) (30,82).
Debe quedar siempre un paso de ≥ 48 px; no pongas nada a menos de 6 tiles de los muelles.

Añade `marcador("PuntoBarco", Vector2(384, 100))` (para la tarea futura del minijuego).

| Entrada | Posición px | | Salida | Centro px | Tamaño | Destino |
|---|---|---|---|---|---|---|
| `desde_playa` | (384, 56) | | `SalidaPlaya` | (384, 8) | 64×16 | `playa` / `desde_mar` |
| `desde_isla` | (384, 1384) | | `SalidaIsla` | (384, 1432) | 64×16 | `isla_orilla` / `desde_mar` |

### 6.4 `isla_orilla` — 60×34 tiles (960×544 px). Semilla 24. Boceto: palmeras grandes y línea de costa

Es la playa al revés (se llega desde el norte por mar):
1. Filas 0–5 `MAR`; fila 6 `MAR_ORILLA`; filas 7–24 `ARENA`; filas 25–33 `PASTO`.
2. `SETO`: `[0,32,59,33]`, `[0,25,1,31]`, `[58,25,59,31]`. Abertura abajo: `[28,32,31,33]` → `ARENA`. Camino `ARENA` `[29,25,30,33]`.
3. Muelle `MUELLE` (`prov = true`): `[28,0,31,8]`.

Objetos y límites:
- `limite("Oeste", Rect2(-16, 96, 32, 320))`, `limite("Este", Rect2(944, 96, 32, 320))` + `roca_grande` cada 40 px en x = 20 y x = 940, de y = 120 a y = 390.
- Muchas palmeras (es lo que destaca en el boceto): `provisional/palmera` en tiles (6,11), (16,10), (24,13), (38,12), (46,10), (55,12), (10,19), (21,21), (40,20), (51,21); `provisional/mini_palmera` en (13,15), (33,17), (44,16), (27,22), (5,23), (56,22). `base = Vector2(12, 6)`.
- `columna_rota_1` (19,16), `columna_rota_2` (43,23), `roca` (35,22): primer aviso de ruinas.
- Árboles sin colisión sobre los setos de abajo.

| Entrada | Posición px | | Salida | Centro px | Tamaño | Destino |
|---|---|---|---|---|---|---|
| `desde_mar` | (480, 56) | | `SalidaMar` | (480, 8) | 48×16 | `mar` / `desde_isla` |
| `desde_isla` | (480, 504) | | `SalidaIsla` | (480, 536) | 64×16 | `isla` / `desde_orilla` |

### 6.5 `isla` — 72×56 tiles (1152×896 px). Semilla 25. Boceto: isla ovalada con palmeras y una cueva a la derecha

Suelo:
1. Todo `MAR` (sólido: es el borde natural).
2. `elipse((34,30), (28,20), ARENA)`; lengua de arena al norte: `elipse((36,8), (5,9), ARENA)` y `rect([34,0,37,6], ARENA)`.
3. `elipse((32,30), (22,15), PASTO)` (interior verde).
4. Camino `ARENA` del norte a la cueva, 2 de ancho: `[35,6,36,20]`, `[26,19,36,20]`, `[26,19,27,37]`, `[26,36,50,37]`, `[49,30,50,37]`, `[49,30,54,31]`.

Objetos:
- **Rastro de estatuas** (guion p. 23 y 39: se sigue a las estatuas hasta la cueva), sólidas, `sombra = false`, pegadas al camino: `estatua` en tiles (33,14), (24,24), (30,39), (47,34); `pedestal` (38,18), (29,30); `columna_rota_3` (40,39); `arco_ruinas` (32,27) con `base = Vector2(110, 14)`. Llama a `reservar` en cada una.
- Cueva: `deco("Cueva", "provisional/entrada_cueva", Vector2(904, 480), {"solido": false, "sombra": false})`; `roca_grande` a los lados en (866, 484) y (942, 484); `limite("TrasCueva", Rect2(872, 436, 64, 30))` para no pasar por detrás.
- Palmeras: `dispersar("Palmeras", ["provisional/palmera", "provisional/mini_palmera", "provisional/palmera"], [12,17,52,43], Vector2(80, 56), {"base": Vector2(12, 6)})`.
- `roca` y `roca_grande` sueltas en la arena: tiles (12,30), (20,44), (44,46), (58,24), (50,14).
- `marcador("PuntoControlIsla", Vector2(576, 120))`.

| Entrada | Posición px | | Salida | Centro px | Tamaño | Destino |
|---|---|---|---|---|---|---|
| `desde_orilla` | (576, 40) | | `SalidaOrilla` | (576, 8) | 64×16 | `isla_orilla` / `desde_isla` |
| `desde_cueva` | (904, 512) | | `SalidaCueva` | (904, 474) | 24×12 | `cueva_medusa` / `desde_isla` |

### 6.6 `cueva_medusa` — 72×30 tiles (1152×480 px). Semilla 26. Boceto: "Cueva N1", pasillo horizontal con puerta a cada lado

Todo en `SueloProvisional`:
1. Todo `VACIO`. 2. `rect([2,5,69,24], PARED_CUEVA)`. 3. Suelo `rect([3,6,68,23], SUELO_CUEVA)` con variante `SUELO_CUEVA_B` al 15 %.
4. Puertas (suelo hasta el borde): izquierda `[0,14,2,15]`; derecha `[69,14,71,15]`.
5. Pilares `PARED_CUEVA` que obligan a zigzaguear: `[14,6,16,17]`, `[26,12,28,23]`, `[38,6,40,17]`, `[50,12,52,23]`, `[60,6,61,11]`.

Objetos: `columna_rota_1/2/3` en tiles (8,9), (21,20), (33,9), (45,20), (57,19); `roca` (10,21), (44,8), (64,21); `estatua` (20,9) y (56,9). Sin sombra.
`marcador("PuntoMecanismo", Vector2(1032, 152))` y `marcador("PuntoPuerta", Vector2(1104, 240))` (el mecanismo que abre la puerta es tarea futura, guion p. 25).

| Entrada | Posición px | | Salida | Centro px | Tamaño | Destino |
|---|---|---|---|---|---|---|
| `desde_isla` | (56, 240) | | `SalidaIsla` | (8, 240) | 16×32 | `isla` / `desde_cueva` |
| `desde_jefe` | (1096, 240) | | `SalidaJefe` | (1144, 240) | 16×32 | `cueva_jefe` / `desde_cueva` |

### 6.7 `cueva_jefe` — 34×26 tiles (544×416 px). Semilla 27. Boceto: sala con Medusa en el centro y figuras alrededor

Todo en `SueloProvisional`:
1. Todo `VACIO`. 2. `elipse((17,11), (14,10), PARED_CUEVA)`. 3. `elipse((17,11), (13,9), LOSA_JEFE)`.
4. Pasillo de entrada (abajo): `rect([15,19,18,25], PARED_CUEVA)` y encima `rect([16,19,17,25], SUELO_CUEVA)`.

Objetos: 6 `estatua` (personas petrificadas, sin sombra) en tiles (8,8), (26,8), (6,13), (28,13), (10,17), (24,17); `columna_rota_2` (12,5) y (22,5).
`marcador("PuntoJefe", Vector2(272, 150))`: aquí irá Medusa. **No** pongas ningún jefe.

| Entrada | Posición px | | Salida | Centro px | Tamaño | Destino |
|---|---|---|---|---|---|---|
| `desde_cueva` | (272, 376) | | `SalidaCueva` | (272, 408) | 32×16 | `cueva_medusa` / `desde_jefe` |

### 6.8 `casa_arbol` — 40×30 tiles (640×480 px). Semilla 28. Boceto: claro con la casa-tocón ("si se termina")

Suelo: todo `PASTO`; `marco(2, SETO)`; abertura abajo `[18,28,21,29]` → `ARENA`; camino `ARENA` `[19,18,20,29]`.

Objetos:
- `deco("Casa", "casa_tocon", Vector2(320, 272), {"sombra": false, "base": Vector2(200, 60)})`.
- `manzano_1..4` en tiles (7,12), (32,11), (9,21), (31,22); `macizo_flores_1` (14,19), `macizo_flores_2` (26,19) sin sombra; `tronco` (12,24); `arbusto_verde` (28,25).
- Arboleda sólida `dispersar` en `[3,3,36,6]` y árboles sin colisión sobre el marco.
- `cartel(Vector2(360, 300), "res://resources/dialogues/cartel_casa_arbol.tres")`.
- `marcador("PuertaCasa", Vector2(320, 276))` (el interior es tarea futura).

| Entrada | Posición px | | Salida | Centro px | Tamaño | Destino |
|---|---|---|---|---|---|---|
| `desde_pueblo` | (320, 440) | | `SalidaPueblo` | (320, 472) | 64×16 | `pueblo` / `desde_casa_arbol` |

### 6.9 Diálogos de los carteles (PROVISIONALES)

Crea, copiando el formato exacto de `resources/dialogues/cartel_pueblo.tres` (**sin comillas `"` dentro del texto**, renglones ≤ 26 letras, tildes solo en minúsculas):
- `cartel_muelle.tres`: `Cartel: Muelle del sur.` / `La barca espera a quien` / `tenga una mision.`
- `cartel_casa_arbol.tres`: `Cartel: Casa del arbol.` / `Cerrada por ahora.`
- `cartel_camino_cerrado.tres`: `Cartel: Camino del este.` / `Cerrado por derrumbe.`

(Mira cómo parte las líneas `Dialogo`: una línea del archivo = un cuadro; si prefieres un solo cuadro, junta el texto en una línea.)

## 7. Fase 4 — Conectar el pueblo (editar `scenes/levels/pueblo.tscn` como texto)

Con el **editor cerrado**. No ejecutes `build_pueblo.gd`. Cambios exactos:

1. **Puerta norte → casa árbol.** Nodo `SalidaBosque` (posición (920, −4)): renómbralo a `SalidaCasaArbol`, `zona_destino = "res://scenes/levels/casa_arbol.tscn"`, `entrada_destino = "desde_pueblo"`. Su hijo `Forma` cambia de `parent="SalidaBosque"` a `parent="SalidaCasaArbol"`.
2. **Entrada norte.** `Entradas/desde_bosque` (920, 40): renómbrala a `desde_casa_arbol`.
3. **Abrir la puerta sur.** Borra el nodo `Limites/PuertaSurCerrada` y su `sub_resource` (`RectangleShape2D_74p3n`, 80×104).
4. **Paredes del camino sur** (fuera de la muralla los árboles no tienen colisión). Añade dos `sub_resource` `RectangleShape2D` de `size = Vector2(300, 121)` y dos `CollisionShape2D` hijos de `Limites`: `CaminoSurOeste` en (734, 1475.5) y `CaminoSurEste` en (1106, 1475.5).
5. **Salida sur.** Nuevo `sub_resource` `RectangleShape2D` `size = Vector2(72, 16)`; nuevo nodo `SalidaBosque` (Area2D, mismo `script = ExtResource(...)` que usaba la salida norte) en (920, 1464) con `zona_destino = "res://scenes/levels/bosque.tscn"`, `entrada_destino = "desde_pueblo"` y un hijo `Forma`.
6. **Entrada sur.** Nuevo `Marker2D` `Entradas/desde_bosque` en (920, 1428).
7. **"Inaccesible en la demo" (este).** Duplica el bloque del nodo `Objetos/Cartel` (con sus hijos `ZonaDialogo` y `Forma`) como `Objetos/CartelEste` en (1716, 700), y apunta su `dialogo` a un `ext_resource` nuevo para `res://resources/dialogues/cartel_camino_cerrado.tres`. No hay salida: la muralla ya cierra el paso.

Reglas al editar el `.tscn`: ids de `sub_resource`/`ext_resource` nuevos y únicos; los `sub_resource` van antes del primer `[node]`; no hace falta `unique_id` en nodos nuevos; no toques nada más.

Después: `godot --headless --path . --import` y el verificador. Si el verificador dice que no se llega de `inicio` a `SalidaBosque`, mira qué tapa la puerta sur (colisión alta de los muros vecinos o un árbol) y corrige solo eso.

## 8. Fase 5 — Verificación final

1. `godot --headless --path . --script res://tools/verificar_zonas.gd` → las 9 zonas OK, grafo completo.
2. `git diff project.godot`: no debe haber cambios (si el editor quitó autoloads `EstadoJuego`/`Dialogos`/`Tienda`, restáuralo con `git checkout project.godot`).
3. Pide a Esteban que abra el editor. Con las herramientas MCP de Godot AI: abre cada escena de `scenes/levels/` y toma una captura del editor (`scene_open` + `editor_screenshot`); revisa que no haya árboles tapando caminos, objetos sobre el agua ni huecos en los bordes. Corrige los **datos del generador** (no la escena) y regenera.
4. Prueba real: ejecuta `game.tscn` (F6 / `project_run`) y recorre pueblo → bosque → playa → mar → isla_orilla → isla → cueva_medusa → cueva_jefe y vuelve. Para ir rápido, cambia `zona_inicial` de `Game` en el Inspector zona por zona **sin guardar ese cambio** (`git diff game.tscn` debe quedar vacío al final).
5. Comprueba en cada zona: la cámara no enseña fuera del mapa, el fundido funciona en los dos sentidos, no hay rebote al entrar, el jugador se ordena bien con los decorados (pasa por delante y por detrás).
6. Actualiza `CLAUDE.md`, sección "Mundo": lista de zonas y conexiones, `tools/build_zonas.gd` + `constructor_zona.gd` + `verificar_zonas.gd`, tileset y sprites provisionales, y la nota de que el bosque ahora está al sur. Quita la frase "Zonas actuales: `pueblo.tscn` ↔ `bosque.tscn` (32×20…)" y corrige la del Pueblo ("Puerta norte → … `SalidaBosque`", "puerta sur cerrada").

## 9. Entregables

```
tools/build_arte_provisional.gd
tools/build_zonas.gd
tools/verificar_zonas.gd
tools/zonas/constructor_zona.gd
tools/build_tilesets.gd                      (un TileSet más)
assets/tilesets/tiles_provisional.png
assets/sprites/entorno/provisional/*.png     (6)
resources/tilesets/provisional.tres
resources/dialogues/cartel_{muelle,casa_arbol,camino_cerrado}.tres
scenes/levels/{bosque,playa,mar,isla_orilla,isla,cueva_medusa,cueva_jefe,casa_arbol}.tscn
scenes/levels/pueblo.tscn                    (solo los 7 cambios de la fase 4)
CLAUDE.md                                    (sección Mundo)
```

## 10. Errores típicos (léelo si algo falla)

- **El nodo no aparece en la escena guardada:** le falta `owner = raíz`.
- **"invalid UID" al abrir zonas:** se regeneró un recurso sin conservar el UID, o el editor estaba abierto → Proyecto → Recargar proyecto actual.
- **No carga un PNG recién creado:** falta `godot --headless --path . --import`.
- **El jugador no puede cruzar el muelle:** quedó `MAR` sólido en `Suelo` debajo del tile provisional (`rect` con `prov = true` debe borrar la otra capa).
- **Rebote infinito entre zonas:** la entrada está dentro del rectángulo de la salida.
- **Un `Area2D` no detecta `StaticBody2D`** con `get_overlapping_bodies()`: en el verificador usa consultas directas al espacio físico.
- **`class_name` no encontrado en modo `--script`:** carga los scripts con `load("res://…")`, como hace `build_pueblo.gd`.
- **La flor falsa no reaparece:** necesita celdas en `Zona.suelo`; por eso solo va en el bosque (con `Suelo` de naturaleza).

## 11. Pendiente para después (no es parte de este plan)

- **Hecho después:** las puertas norte y sur del pueblo tienen una `BarreraMision` (Zeus no deja salir hasta que los sabios den la misión, `EstadoJuego.mision_recibida`). No afecta a `verificar_zonas.gd` (son Area2D).

Minijuego del barco (sprites `barco_*` de `leonidas_mini`, `remolino.aseprite`, `tiburon.aseprite` ya existen), NPC de la playa que explica el barco, sabios y entrega de la espada, mecanismo y cíclopes de la cueva, Medusa, interior de la casa árbol, Tocotón. Pedir a la artista: tiles de cueva, mar navegable, muelle, transiciones arena↔pasto y orillas, palmeras y rocas en pixel art, boca de la cueva.

# Plan: minijuego del barco (zona `mar`) con micrófono y agua animada

> **Para quién es:** un modelo (Sonnet/Opus) o persona que lo implementa sin más contexto.
> **Antes de empezar:** lee `CLAUDE.md` entero (arquitectura por composición, zonas, tiles, sprites, reglas del repo). Responde y escribe en español.
> **Escrito el 2026-11-10.** Los números de línea y nombres citados son de ese día (commit `7e8b06d`); si no coinciden, busca por nombre.
> **Godot 4.7.2:** las API de audio/TileSet citadas aquí son las de Godot 4.x; **compruébalas en la ayuda del editor** (o con `godot --doctool`) antes de darlas por buenas. Donde hay duda está marcado con ⚠.

## 1. Objetivo

Hoy la zona `mar` (`scenes/levels/mar.tscn`, 768×1440 px) es agua provisional por la que **Leonidas camina**. Hay que convertirla en el **minijuego del barco** que une la playa con la isla de Medusa:

1. Al entrar en `mar` Leonidas va **en barco** (sprites `barco_*` que ya están en `resources/sprite_frames/leonidas_mini.tres`).
2. **Dirección** con el movimiento normal (WASD / flechas / mando). **Velocidad soplando al micrófono**: cuanto más fuerte se sopla, más rápido va.
3. Sin ataque. Hay que esquivar rocas, **remolinos** y **tiburones**, que quitan vida **al barco** (Jugabilidad p. 9, Guión p. 18: "llegar con toda la salud posible").
4. Al llegar al otro muelle se pasa a la zona siguiente; se puede volver.
5. **Agua animada** en todas las zonas (mar, playa, orilla de la isla, estanques del pueblo).

### Sobre "entre el bosque y la playa"
El mapa acordado (`docs/design/plan_mapa_mundo.md`, guion p. 10–11) es:

```
bosque → playa → (muelle) → mar [MINIJUEGO] → isla_orilla → isla → …
```

El barco sale del muelle de la **playa**, así que este plan pone el minijuego en `mar`, entre `playa` e `isla_orilla`. La cadena completa bosque → playa → barco → isla queda conectada. **No muevas el minijuego entre bosque y playa**; si Esteban lo quisiera literalmente ahí, bastaría con cambiar `zona_destino`/`entrada_destino` de las salidas (sección 8.3), no la mecánica.

### Fuera de alcance (NO hacer)
NPC del barquero con guion (no hay sprite ni texto; solo se actualiza el cartel del muelle), música/sonidos, pantalla de game over, guardar partida, cambios en el pueblo/bosque/cuevas, rehacer el arte provisional del mar, tocar `jugador.gd` más de lo indicado.

## 2. Decisiones de diseño (ya tomadas; no reabrir)

| Tema | Decisión |
|---|---|
| Entidad | El barco es una **entidad nueva** (`Barco`, cerebro + componentes), no un estado de `Jugador`. Mientras se navega, el `Jugador` queda oculto y desactivado. |
| Quién lo crea | `Game`, cuando la zona cargada tiene `modo_barco = true`. La zona no contiene el barco (aparece en la entrada por la que se llegó). |
| Micrófono | Autoload nuevo **`Microfono`** que publica `nivel` (0..1). El barco solo lee ese número. |
| Sin micrófono | Siempre hay alternativa: **mantener Espacio/K** (acción `pirueta`, que en el barco no se usa) equivale a soplar al máximo. Además el barco avanza despacio solo con la dirección (`velocidad_remo`), para que nunca quede bloqueado. |
| Vida | El barco tiene su propio `ComponenteVida` (12 cuartos = 3 corazones). El HUD de corazones muestra la del barco mientras se navega. La vida de Leonidas no cambia. |
| Hundirse | Vida 0 → fundido → se recarga `mar` por la misma entrada, barco con vida llena. |
| Agua | **Shader** por tile (`TileData.material`) que dibuja olas de 1 px sobre los píxeles de color agua. No necesita arte nuevo y sirve para los dos tilesets. |
| Estilo | Todo se mueve en píxeles enteros; velocidades múltiplos de 30 px/s (física a 120 ticks/s). |

## 3. Datos que necesitas

**Sprites del barco** (ya exportados, celda 48×40, origen (24, 34) → `offset = (0, -14)`): animaciones `barco_moviendo_{frente,lado,espalda}` (ciclo de 8 frames) y `barco_quieto_{frente,lado,espalda}` (1 frame). El lado mira a la izquierda. Con `AnimadorDireccional.reproducir(&"barco_moviendo")` se elige sola la dirección y el espejo.

**`assets/sprites/remolino.aseprite`:** 20×20, 4 frames a 100 ms, una capa (`Layer 1`). Sin layout todavía.

**`assets/sprites/tiburon.aseprite`:** 90×90, 8 frames a 100 ms, 3 capas visibles a la vez (no se solapan):
- `Layer 1` (x 3–58, y 4–23): **dos** tiburones lado a lado mirando a la izquierda (izquierdo con la boca abierta y dientes; derecho con la boca cerrada), nadando.
- `Layer 2` (x 4–59, y 33–53): otra fila igual (variante del ciclo de nado).
- `Layer 3` (x 3–35, y 60–83): **un** tiburón, 8 frames: salta, abre la boca y se sumerge → es la **mordida**.
Antes de escribir el layout, expórtalo a una hoja y míralo (`aseprite -b tiburon.aseprite --scale 4 --sheet /ruta/scratchpad/tiburon.png`, sobre una **copia** en el scratchpad) para fijar el `x`/`w` de cada tiburón dentro de las capas 1 y 2.

**Zona `mar` actual** (`tools/build_zonas.gd`, función `_mar()`): 48×90 tiles, todo en `SueloProvisional` (`MAR_NAV` (4,0), `MAR_NAV_OLA` (5,0), `ARRECIFE` (8,0) sólido en los 4 bordes, `MUELLE` (7,0) arriba `[22,0,25,3]` y abajo `[22,86,25,89]`), 18 rocas sólidas de la artista (`roca_barco_{pequena,alta,grande}`, `ROCAS_BARCO`), entradas `desde_playa` (384,56) y `desde_isla` (384,1384), salidas `SalidaPlaya` (384,8) y `SalidaIsla` (384,1432), marcador `PuntoBarco`.

**Capas de física:** 1 mundo · 2 jugador · 5 golpe_enemigo. `Decorado` y los tiles sólidos están en la capa 1. `SalidaZona` usa máscara 2.

**Código que vas a tocar o imitar:** `scripts/systems/game.gd`, `zona.gd`, `salida_zona.gd`, `scripts/ui/hud.gd`, `scripts/player/jugador.gd` (solo como modelo de cerebro), `scripts/componentes/{componente_movimiento,animador_direccional,componente_vida,hurtbox,hitbox,componente_parpadeo,componente_deteccion}.gd`, `tools/build_tilesets.gd`, `tools/build_zonas.gd`, `tools/verificar_zonas.gd`.

**Reglas de trabajo que más se rompen:**
- **No edites `project.godot` a mano con el editor abierto** (el editor lo pisa y borra autoloads). Usa el MCP de Godot AI (`autoload_manage`, `project_manage`) o cierra el editor. Al terminar: `git diff project.godot` y comprueba que siguen `EstadoJuego`, `Dialogos` y `Tienda`.
- Regenerar tilesets/zonas con el editor **cerrado**, o después Proyecto → Recargar proyecto actual.
- En `.tres` de diálogo escritos a mano no uses comillas `"` dentro del texto.
- `build_zonas.gd` sobrescribe `mar.tscn`: todo cambio de `mar` se hace **en el generador**, no en la escena.

## 4. Fases

Haz un commit pequeño (en español) por fase. Cada fase deja el juego arrancable.

### Fase 1 — Autoload `Microfono`

Archivo: `autoload/microfono.gd` (Node). Registrar como autoload `Microfono` **con el MCP** (`autoload_manage op="add"`).

Ajuste de proyecto: `audio/driver/enable_input = true` (con `project_manage`/settings del MCP; requiere reiniciar el editor). En macOS el editor pedirá permiso de micrófono la primera vez.

Funcionamiento (todo creado por código en `_ready`, sin tocar `default_bus_layout.tres`):
1. Crear un bus `Microfono`: `AudioServer.add_bus()`, `set_bus_name`, `set_bus_mute(idx, true)` (para que el micro **no suene** por los altavoces), `add_bus_effect(idx, AudioEffectCapture.new())`.
2. Un `AudioStreamPlayer` hijo con `stream = AudioStreamMicrophone.new()`, `bus = &"Microfono"`.
3. `activar()` → `play()`; `desactivar()` → `stop()` y `nivel = 0`. Solo se activa durante el minijuego (no dejar el micro abierto en todo el juego).
4. En `_process`: vaciar el buffer (`captura.get_buffer(captura.get_frames_available())` → `PackedVector2Array`), calcular el **RMS**, pasarlo a dB (`linear_to_db`), y normalizar:
   `crudo = clampf(inverse_lerp(db_min, db_max, db), 0, 1)`; suavizado asimétrico: sube rápido (≈ 20/s), baja lento (≈ 4/s) → `nivel`.
5. **Calibración:** `calibrar()` mide durante 0,5 s el ruido ambiente y fija `db_min = ruido + margen_db` (margen 12 dB). `db_max` exportado (−12 dB por defecto). Limitar `db_min` a [−50, −20].

API pública:
```gdscript
signal disponible_cambio(disponible: bool)
var nivel := 0.0            # 0..1, ya suavizado
var disponible := false     # true cuando han llegado muestras no nulas
var nivel_forzado := -1.0   # ≥ 0 → sustituye al micro (pruebas automáticas)
func activar() -> void
func desactivar() -> void
func calibrar() -> void     # corrutina (await)
```
`disponible` pasa a true al recibir la primera muestra con RMS > 0; si a los 2 s de `activar()` sigue en false (sin permiso, sin dispositivo, web sin gesto), se queda en false y el HUD muestra la pista del teclado (fase 4).

⚠ Comprobar: (a) que con el bus en *mute* el `AudioEffectCapture` sigue recibiendo audio; si llegan ceros, quita el mute y usa `set_bus_volume_db(idx, -80)`; (b) nombres exactos de `AudioEffectCapture.get_frames_available/get_buffer`; (c) si el nivel llega con mucho retraso en macOS, bajar `buffer_length` del efecto a 0,05–0,1 s.

Prueba de la fase: escena temporal o `print` cada 0,25 s de `Microfono.nivel` al soplar (no dejarla en el repo).

### Fase 2 — Entidad `Barco`

`scenes/player/barco.tscn` + `scripts/player/barco.gd` (`class_name Barco`). Créala con el MCP o a mano con el editor cerrado. Posición del nodo = base del casco.

```
Barco (CharacterBody2D, capa 2 jugador, máscara 1 mundo, grupo "barco")
├─ Estela (CPUParticles2D, opcional — fase 7)
├─ Sprite (AnimatedSprite2D: leonidas_mini.tres, offset (0,-14), animación barco_quieto_frente)
├─ Colision (RectangleShape2D 20×10, position (0,-5))
├─ Hurtbox (Area2D + script Hurtbox, capa 2, máscara 0; forma 22×14 en (0,-8))
├─ Movimiento (ComponenteMovimiento: velocidad 120, aceleracion 240, friccion 90)
├─ Animador (AnimadorDireccional → Sprite)
├─ Vida (ComponenteVida: vida_max 12, invulnerabilidad 1.0 → Hurtbox)
└─ Parpadeo (ComponenteParpadeo → Sprite)
```
Sin sombra (el casco ya va sobre el agua). Ajusta formas mirando el sprite (el barco mide ~33×25).

Cerebro (`barco.gd`), siguiendo el estilo de `jugador.gd`:

```gdscript
signal hundido

enum Estado { NAVEGANDO, DANO, HUNDIDO, BLOQUEADO }

@export_group("Navegación")
@export var velocidad_remo := 30.0      # solo dirección, sin soplar
@export var velocidad_viento := 120.0   # soplando al máximo
@export var umbral_soplo := 0.08        # por debajo, el soplido no cuenta
@export_group("Choques")
@export var velocidad_choque := 70.0    # chocar más rápido que esto daña
@export var danio_choque := 1           # cuartos de corazón
@export var rebote := 60.0

var estado := Estado.NAVEGANDO
var rumbo := Vector2.DOWN               # última dirección; el soplido empuja hacia aquí
```
Lógica de `_physics_process` en `NAVEGANDO`:
1. `entrada = Input.get_vector(mover_*)`; si no es cero: `rumbo = entrada.normalized()` y `animador.orientar(entrada)`.
2. `soplo = soplido()` = `max(Microfono.nivel (o nivel_forzado si ≥ 0), 1.0 si Input.is_action_pressed(&"pirueta"))`; si `< umbral_soplo` → 0.
3. Velocidad objetivo:
   - con dirección: `lerpf(velocidad_remo, velocidad_viento, soplo)` hacia `entrada`;
   - sin dirección y soplando: `velocidad_viento * soplo` hacia `rumbo` (soplar sin tocar nada empuja recto);
   - sin nada: `movimiento.frenar(delta)` (fricción baja = deriva).
   Usa `movimiento.mover(dir, delta, vel)`; no llames a `move_and_slide()` (lo hace el componente).
4. Animación: `barco_moviendo` si `velocity.length() > 8`, si no `barco_quieto`. Opcional: `sprite.speed_scale = lerpf(0.6, 1.6, velocity.length() / velocidad_viento)`.
5. Guarda `_vel_previa = velocity` (el padre se procesa antes que el componente).

Choques con rocas/arrecife: conecta `movimiento.choco`; si `_vel_previa.length() > velocidad_choque` → `vida.recibir_danio(danio_choque, colision.get_position())` y `velocity = colision.get_normal() * rebote`. La invulnerabilidad de `ComponenteVida` (1 s) evita daño repetido.

Daño (`vida.danado`): estado `DANO` durante 0,3 s (se frena con `movimiento.frenar(delta, 0.6)`), `parpadeo.parpadear(vida.tiempo_invulnerable())`, empuje `movimiento.empujar_desde(origen, 90, -rumbo)`. `vida.murio` → estado `HUNDIDO`, detener, animación de hundirse hecha por código (tween: `sprite.position:y` +6 y `modulate:a` → 0 en 0,8 s), luego `hundido.emit()`.

`set_bloqueado(b)`: como el del jugador (detiene y pone `barco_quieto`). `mirar(dir)`: fija `rumbo` y la orientación inicial.

### Fase 3 — `Zona`, `Game` y `SalidaZona`

**`zona.gd`:** añadir
```gdscript
## En esta zona se viaja en barco (minijuego del mar): Game sustituye a Leonidas por el Barco.
@export var modo_barco := false
```

**`salida_zona.gd`:** la condición pasa a `if not (cuerpo is Jugador or cuerpo is Barco) or zona_destino.is_empty(): return`.

**`game.gd`:**
- `@export var escena_barco: PackedScene` (asignar `barco.tscn` en `game.tscn`), `var barco: Barco = null`, y guardar `_ruta_actual` / `_entrada_actual` en `_cargar_zona`.
- Señal nueva `modo_cambio(en_barco: bool, vida: ComponenteVida)` para el HUD.
- En `_cargar_zona`, después de colocar al jugador:
  - Si había barco: `barco.queue_free()`, `barco = null`.
  - Si `zona_actual.modo_barco`: instanciar el barco como hijo de `Game` (hermano del jugador, para el y-sort), ponerlo en `punto_entrada(entrada)`, `barco.mirar(...)` hacia el interior del mapa (abajo si la entrada está en la mitad superior de los límites, arriba si no), conectar `barco.hundido` → `_al_hundirse`; **desactivar al jugador**: `jugador.visible = false`, `jugador.process_mode = Node.PROCESS_MODE_DISABLED` (con el `disable_mode` por defecto sale de la física); `camara.objetivo = barco`; `Microfono.activar()`.
  - Si no: reactivar al jugador (`visible = true`, `process_mode = INHERIT`), `camara.objetivo = jugador`, `Microfono.desactivar()`.
  - `_ajustar_camara()` debe ir **después** de fijar `camara.objetivo`. Emitir `modo_cambio`.
- `cambiar_zona`: bloquear/desbloquear también al barco (`if barco: barco.set_bloqueado(...)`; ojo: tras `_cargar_zona` el barco es otro o ya no existe).
- `_al_hundirse()`: si `_cambiando` salir; `_cambiando = true`; fundir a negro; `_cargar_zona(_ruta_actual, _entrada_actual)`; fundir; desbloquear; `_cambiando = false`.
- **Tutorial la primera vez:** en `EstadoJuego` añadir `var tutorial_barco_visto := false` (ponerlo a false en `reiniciar()`). Tras el fundido de entrada a una zona con barco, si no se ha visto: `barco.set_bloqueado(true)`, `await Dialogos.mostrar(load("res://resources/dialogues/tutorial_barco.tres"))`, `await Microfono.calibrar()` (pedir silencio en la última línea del diálogo), marcar visto, desbloquear. `CajaDialogo` bloquea al nodo del grupo `jugador` (que está desactivado: no pasa nada); por eso el barco se bloquea a mano.

Diálogo nuevo `resources/dialogues/tutorial_barco.tres` (formato `Dialogo`, texto PROVISIONAL, renglones ≤ 26 letras, sin comillas):
```
# TEXTO PROVISIONAL
Leonidas: ¡A navegar!
Elijo el rumbo con las teclas de moverme.
Si soplo al micrófono, la vela se hincha y voy más rápido.
Sin micrófono: mantener Espacio.
Cuidado con rocas, remolinos y tiburones.
(Guarda silencio un momento...)
```
Actualizar `cartel_muelle.tres` con una línea que avise de que se sopla para avanzar.

Prueba de la fase: en `game.tscn`, `zona_inicial = mar.tscn` y `modo_barco = true` puesto a mano en `mar.tscn` de forma temporal (la fase 5 lo hace desde el generador). Se navega, la cámara sigue al barco, se sale por los dos extremos y en la playa/isla vuelve Leonidas a pie.

### Fase 4 — HUD

En `scripts/ui/hud.gd`:
- Sustituir la conexión fija a `jugador.vida` por `seguir_vida(v: ComponenteVida)`: desconecta la anterior (`_vida`), conecta `v.cambio` a `_al_cambiar_vida` y refresca. `_ready` llama `seguir_vida(jugador.vida)`.
- `modo_barco(activo: bool)`: oculta/muestra `RanuraObjeto` y fuerza la barra de estamina invisible; muestra `MedidorViento`.
- Conectar en `_ready` a la señal `modo_cambio` de Game (`get_tree().get_first_node_in_group(&"game")`; Game ya está en el grupo; si el HUD se prepara antes, usar `call_deferred`): en barco → `seguir_vida(vida_del_barco)`, a pie → `seguir_vida(jugador.vida)`.
- **`MedidorViento`** (nodo nuevo en `hud.tscn`): reutiliza `BarraEstamina` (script `barra_estamina.gd`, `umbral_bajo = 0`, `color_relleno` celeste `7cc4d0`), 40×5 px, debajo de los corazones (x 2, y 15). En `_process`: `valor = soplido actual` (el mismo cálculo que usa el barco: exponlo como `Barco.soplido()` y que el HUD lo lea de `game.barco`).
- Pista cuando `Microfono.disponible == false`: un `Label` pequeño junto al medidor con `[Espacio]`. Mirar `docs/design/guia_interfaz.md` antes y apuntar allí la pieza nueva (sección "Barco").

### Fase 5 — Rediseño de `mar` en el generador

En `tools/build_zonas.gd`, `_mar()` (y actualizar el comentario "Leonidas camina"):
1. `z.raiz.set("modo_barco", true)` (comprueba en `constructor_zona.gd` que `raiz` ya tiene el script `Zona` en ese punto).
2. Suelo: `MAR_NAV` liso (quitar la variante `MAR_NAV_OLA`: las olas las pone el shader). Arrecife igual.
3. Muelles más cortos, pegados al borde: arriba `[22,0,25,1]`, abajo `[22,88,25,89]` (sustituyen al arrecife de esas celdas). El barco **no** navega sobre el muelle: la salida va justo delante.
   | Entrada | Posición | | Salida | Centro | Tamaño | Destino |
   |---|---|---|---|---|---|---|
   | `desde_playa` | (384, 96) | | `SalidaPlaya` | (384, 40) | 64×16 | `playa` / `desde_mar` |
   | `desde_isla` | (384, 1344) | | `SalidaIsla` | (384, 1400) | 64×16 | `isla_orilla` / `desde_mar` |
   Añadir `limite` invisibles a los lados de cada salida si el barco pudiera rodear el muelle y quedar sobre él.
4. Quitar `PuntoBarco`.
5. Rocas: conservar las 18 pero revisar que quede siempre un paso ≥ 64 px (el barco es más ancho que Leonidas) y nada a menos de 8 tiles de los muelles.
6. Peligros (fase 6) con `z.instancia("Peligros", RUTA, pos)`: 6 remolinos y 4 tiburones repartidos, dificultad creciente hacia el centro y ninguno en los primeros/últimos 200 px. Posiciones sugeridas (px) — remolinos: (250,330) (520,470) (330,640) (470,820) (260,1000) (500,1150); tiburones (patrulla horizontal ±120 px): (384,560) (300,760) (460,930) (384,1090). Ajustar jugando.

Regenerar y verificar (editor cerrado):
```bash
godot --headless --path . --script res://tools/build_zonas.gd -- mar
godot --headless --path . --script res://tools/verificar_zonas.gd
```
El verificador usa la forma de Leonidas (10×6); debe seguir dando OK. No hace falta enseñarle el barco.

`playa` e `isla_orilla` no cambian: Leonidas camina por el muelle, toca la salida del final y tras el fundido aparece ya en el barco.

### Fase 6 — Remolino y tiburón

**Sprites:** crear `tools/sprite_layouts/remolino.lua` (celda 20×20, una animación `girar`, loop) y `tools/sprite_layouts/tiburon.lua` (animaciones `nadar` desde `Layer 1`/`Layer 2` y `morder` desde `Layer 3` con `layer = "..."`; sin direcciones, mira a la izquierda → `espejar_sin_direccion`). Imitar `flor_falsa.lua` (sprite sin direcciones con una capa por animación) y ejecutar `tools/export_sprites.sh remolino` y `tools/export_sprites.sh tiburon` → `resources/sprite_frames/{remolino,tiburon}.tres`.

**Remolino** — `scenes/entorno/remolino.tscn` + `scripts/entorno/remolino.gd` (`class_name Remolino`, Node2D):
- `AnimatedSprite2D` (`girar`), `z_index = -1` no: debe verse sobre el agua y bajo el barco → dejarlo en `Objetos` con su posición = centro y `y_sort` normal, pero con `offset` de modo que su base quede **arriba** del centro (así el barco se dibuja encima al pasar).
- Exports: `radio_arrastre := 56.0`, `fuerza := 70.0` (px/s² en el borde, crece hacia el centro), `danio := 2`.
- `_physics_process`: `barco = get_tree().get_first_node_in_group(&"barco")`; si está dentro del radio: `barco.velocity += hacia_centro * fuerza * (1 - d/radio) * delta` (soplando fuerte se escapa).
- Un `Hitbox` hijo (capa 5 golpe_enemigo, máscara 2, `continuo = true`, `danio = 2`, círculo r 7) en el centro. El `Hitbox` encuentra el `Hurtbox` del barco.

**Tiburón** — `scenes/enemies/tiburon.tscn` + `scripts/enemies/tiburon.gd` (`class_name Tiburon`), receta de enemigo de `CLAUDE.md` pero **sin vida** (no se le puede atacar):
- CharacterBody2D (capa 3, máscara 1) + Sprite + `ComponenteMovimiento` (velocidad 60) + `AnimadorDireccional` (`espejar_sin_direccion = true`) + `ComponenteDeteccion` (`grupo = &"barco"`, `radio_vision` 90, `radio_perder` 150; lee su script para la API exacta) + `Hitbox` de contacto (capa 5, máscara 2, `continuo = true`, `danio = 2`).
- Estados: `PATRULLA` (va y viene en horizontal ±`alcance_patrulla` desde su posición inicial; al chocar da la vuelta), `EMBESTIR` (al ver el barco: animación `morder`, nada hacia él a 120 px/s durante 0,8 s), `CANSADO` (1,5 s casi quieto: ventana para pasar), y vuelve a `PATRULLA`.

### Fase 7 — Agua animada

**Shader** `resources/shaders/agua.gdshader` (canvas_item). Solo cambia los píxeles cuyo color es el del agua, así sirve también para tiles mixtos (orilla). Punto de partida (ajustar a ojo, siempre en píxeles enteros y con el tiempo a saltos para que parezca pixel art):

```glsl
shader_type canvas_item;

uniform vec4 color_agua : source_color;            // color base del agua en ese tileset
uniform vec4 color_cresta : source_color = vec4(0.49, 0.77, 0.82, 1.0);
uniform vec4 color_valle : source_color;           // un tono más oscuro que el agua
uniform float tolerancia = 0.06;
uniform float pasos_por_segundo = 4.0;
varying vec2 pos_mundo;

float azar(float n) { return fract(sin(n * 91.345) * 47453.5453); }

void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (distance(c.rgb, color_agua.rgb) < tolerancia) {
		vec2 p = floor(pos_mundo);
		float t = floor(TIME * pasos_por_segundo);
		float banda = floor(p.y / 8.0);                       // una fila de olas cada 8 px
		float sentido = mod(banda, 2.0) < 1.0 ? 1.0 : -1.0;   // filas alternas, sentidos opuestos
		float x = mod(p.x + azar(banda) * 48.0 + t * sentido, 48.0);
		float fila = mod(p.y, 8.0);
		float largo = 5.0 + floor(azar(banda + 7.0) * 4.0);
		if (fila == 3.0 && x < largo) c.rgb = color_cresta.rgb;
		else if (fila == 4.0 && x >= 1.0 && x < largo + 1.0) c.rgb = color_valle.rgb;
	}
	COLOR = c * COLOR;
}
```
(`fila == 3.0` funciona porque `p` es entero; si parpadea, usar `abs(fila - 3.0) < 0.5`.)

**Materiales:** `resources/shaders/agua_provisional.tres` (`color_agua = #3f8fa8`, valle `#357f98`) y `agua_naturaleza.tres` (mide el color base del mar y del estanque en `assets/tilesets/tiles_naturaleza.png` con un script headless que lea píxeles; si mar y estanque tienen colores distintos, haz un material para cada uno).

**`tools/build_tilesets.gd`:** añadir a cada configuración la clave opcional `"materiales": { "res://…/agua_x.tres": [Vector2i(...), …] }` y, tras crear los tiles, `fuente.get_tile_data(coords, 0).material = load(ruta)`. Tiles: provisional (4,0) y (5,0); naturaleza (16,0) (17,0) (18,0) (19,0) (0,1) (17,1) (18,1) (19,1). Regenerar con `godot --headless --path . --script res://tools/build_tilesets.gd` (conserva los UID) y comprobar que el `.tres` guarda el material como recurso externo.

⚠ Comprobar: que `TileData.material` existe y se aplica en `TileMapLayer` con GL Compatibility; que `pos_mundo` es estable al mover la cámara (las olas no deben "arrastrarse" con ella). Si `MODEL_MATRIX` no diera coordenadas de mundo en el tilemap, alternativa: `pos_mundo = (inverse(CANVAS_MATRIX) * vec4(FRAGCOORD.xy, 0.0, 1.0)).xy` — pruébalo.

**Estela del barco (opcional, si sobra tiempo):** `CPUParticles2D` en `Barco/Estela` (cuadrados blancos de 1 px, vida 0,6 s, sin gravedad, `emitting` solo si `velocity.length() > 40`, `local_coords = false`, `z_index` bajo el sprite).

### Fase 8 — Remates

1. **Recompensa (opcional, 5 líneas):** al salir de `mar` por la salida contraria a la entrada, `EstadoJuego.agregar_monedas(barco.vida.vida / 4)` (una moneda por corazón entero conservado).
2. **Exportación macOS (apuntar, no hacer si no hay `export_presets.cfg`):** el preset necesita la descripción de uso del micrófono y el permiso de entrada de audio; en web el micro exige HTTPS y un gesto del usuario (la alternativa de teclado cubre el caso).
3. **Si se quisiera el barco en otro tramo:** basta con marcar `modo_barco` en esa zona y enlazar sus `SalidaZona`; nada del barco depende de `mar`.
4. **Documentación:** en `CLAUDE.md` añadir una sección "Barco (hecho)" (entidad, autoload `Microfono`, `Zona.modo_barco`, cambios de Game/HUD, shader del agua y clave `materiales` de `build_tilesets.gd`), corregir la frase "En `mar` Leonidas camina", quitar remolino/tiburón de "Assets que faltan" y actualizar `docs/design/guia_interfaz.md` (Barco) y la sección 6.3 de `plan_mapa_mundo.md`.

## 5. Archivos

| Nuevo | |
|---|---|
| `autoload/microfono.gd` | nivel del soplido |
| `scenes/player/barco.tscn`, `scripts/player/barco.gd` | entidad Barco |
| `scenes/entorno/remolino.tscn`, `scripts/entorno/remolino.gd` | obstáculo |
| `scenes/enemies/tiburon.tscn`, `scripts/enemies/tiburon.gd` | enemigo |
| `tools/sprite_layouts/{remolino,tiburon}.lua` → strips y `resources/sprite_frames/*.tres` | sprites |
| `resources/shaders/agua.gdshader`, `agua_provisional.tres`, `agua_naturaleza.tres` | agua |
| `resources/dialogues/tutorial_barco.tres` | tutorial |

| Modificado | Cambio |
|---|---|
| `project.godot` (vía MCP) | autoload `Microfono`, `audio/driver/enable_input` |
| `scripts/systems/zona.gd` | `modo_barco` |
| `scripts/systems/salida_zona.gd` | acepta `Barco` |
| `scripts/systems/game.gd`, `game.tscn` | crear/quitar barco, cámara, hundirse, tutorial, señal `modo_cambio` |
| `autoload/estado_juego.gd` | `tutorial_barco_visto` |
| `scripts/ui/hud.gd`, `scenes/ui/hud.tscn` | `seguir_vida`, `MedidorViento` |
| `tools/build_zonas.gd` → `scenes/levels/mar.tscn` | zona de barco, salidas, peligros |
| `tools/build_tilesets.gd` → `resources/tilesets/*.tres` | materiales del agua |
| `resources/dialogues/cartel_muelle.tres`, `CLAUDE.md`, `docs/design/*` | textos y documentación |

## 6. Pruebas de aceptación

Automáticas:
- `verificar_zonas.gd` → `RESULTADO: OK (0 fallos)`.
- `godot --headless --path . --quit` (o abrir el proyecto) sin errores de script; `git diff project.godot` conserva los 4 autoloads anteriores + `Microfono`.

Jugando (MCP: `project_run` con `zona_inicial = mar.tscn`, o desde la playa; para pulsaciones simuladas recuerda el `await process_frame` previo; para simular el soplido usa `Microfono.nivel_forzado`):
1. Playa → muelle → fundido → Leonidas aparece **en el barco**, mirando al sur; la primera vez sale el tutorial y después no.
2. Solo WASD: avanza a ~30 px/s. WASD + soplar (o Espacio): hasta 120 px/s, proporcional a la fuerza. Soplar sin dirección: empuja hacia el último rumbo. Al dejar de soplar, deriva y se frena.
3. Hablar o hacer ruido moderado no dispara el barco tras la calibración; `MedidorViento` refleja el nivel.
4. El micrófono no se oye por los altavoces y se apaga al salir del mar.
5. Roca a toda velocidad: −1 cuarto, rebote y parpadeo. Remolino: arrastra y −2 en el centro. Tiburón: embiste y −2. Los corazones del HUD son los del barco.
6. Vida 0: el barco se hunde, fundido y reinicio en la entrada del mar con 3 corazones.
7. Llegar al muelle sur → `isla_orilla` con Leonidas a pie, su vida y su HUD normales (ranura de objeto visible). Volver al mar desde la isla funciona igual en sentido contrario.
8. J (atacar) y E (interactuar) no hacen nada en el barco.
9. El agua se mueve en `mar`, `playa`, `isla_orilla`, `isla` y los canales del pueblo; arena, muelle y hierba no cambian; las olas no tiemblan ni se desplazan al mover la cámara.
10. 120 FPS estables en `mar` (los materiales por tile no deben tirar el rendimiento; si lo hacen, deja el shader solo en `MAR_NAV`).

## 7. Riesgos

| Riesgo | Qué hacer |
|---|---|
| El micro no entrega audio (permiso, mute del bus, API distinta en 4.7) | La alternativa de teclado ya cubre el juego; resolver con las notas ⚠ de la fase 1 y no bloquear las demás fases. |
| El editor pisa `project.godot` | Usar el MCP para ajustes y autoloads; revisar el diff. |
| `build_zonas`/`build_tilesets` con el editor abierto → "invalid UID" | Cerrar el editor o Recargar proyecto. |
| El shader no se guarda por tile o rompe el batching | Plan B: un `ColorRect`/`Sprite2D` con el shader **debajo** de `SueloProvisional` solo en `mar` y dejar el resto del agua estática. |
| Ruido ambiente del aula (demo en clase) | `calibrar()` al empezar y `margen_db` exportado; se puede recalibrar volviendo a entrar. |

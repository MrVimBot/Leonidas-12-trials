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
assets/{sprites/{strips,entorno},tilesets,ui,fonts,backgrounds/cinematica,audio/{music,sfx}}
scenes/{player,npcs,enemies,levels,entorno,ui,cinematics,items}
scripts/{player,npcs,enemies,componentes,entorno,items,systems,ui}
autoload/  resources/{sprite_frames,dialogues}  tools/  docs/{design,reference}
```
Convención: nombres de archivo en `snake_case`, sin espacios ni acentos; escenas y scripts con el mismo nombre base.

## Estado de los sprites (IMPORTANTE)
Los `.aseprite` de `assets/sprites/` ya están en snake_case (renombrados desde el MCP de Godot; `leonidas mini (1)` → `leonidas_mini.aseprite`). `leonidas.aseprite` es otro archivo (ya no lo usa ninguna escena).

En `leonidas_mini.aseprite` (100×310 px, 16 frames, sin tags) las animaciones son una **rejilla**: 3 columnas (frente / lado / espalda; el barco va lado / frente / espalda) × filas por acción. El "lado" mira a la **izquierda** (derecha = `flip_h`). Hallazgos: la mayoría son ciclos de **8 frames** (8–15 repiten 0–7); `parado*` y `barco_quieto*` son un único frame; la paleta de la artista está dentro de `parado normal` (x 24–27).
La fila `Layer 17` (y 226–255) NO son direcciones: `recibir_dano` (frente), `morir` y una tercera pose de frente con el brazo en alto (`sin_nombre`): según Jugabilidad.pdf p. 8 es **comer la manzana** ("Leonidas a punto de disfrutar una rica manzana"); falta renombrarla en el layout. Daño y morir se solapan en x según el frame: se separan con `cut_left/cut_right` del layout.

**Pipeline de sprites (hecho):**
- `tools/sprite_layouts/<nombre>.lua`: tabla con la rejilla de cada `.aseprite` (columnas, filas, línea de pies, loop).
- `tools/export_strips.lua`: script de la CLI de Aseprite; exporta una tira PNG por animación + JSON a `assets/sprites/strips/<nombre>/` (detecta frames repetidos/vacíos y el periodo del ciclo).
- `tools/sprite_frames_builder.gd` + `tools/build_sprite_frames.gd`: construyen `resources/sprite_frames/<nombre>.tres` usando solo los frames del periodo.
- Todo con un comando: `tools/export_sprites.sh [nombre]` (trabaja sobre una copia temporal; no toca los originales).
- Celda 48×40 con el origen en (24, 34): en un `AnimatedSprite2D` usar `offset = (0, -14)` para que la posición del nodo sean los pies. Los pies de todas las animaciones (salvo ataque y barco) apoyan en la fila 33 de la celda; como la artista no los dibujó a la misma altura, el layout lleva `foot` por columna donde hace falta (medido con la fila más baja de los pies en reposo). La sombra del jugador va en y = −1.
- Para añadir otro sprite (p. ej. el Tocotón cuando llegue): crear su layout en `tools/sprite_layouts/` y ejecutar el script. Opciones por fila o columna del layout: `foot`, `ax`, `loop`, `fps`, `cut_left`/`cut_right`, `frames = n` (usar solo los n primeros), y de qué capas salen los frames: `layer = "nombre"` (una sola capa, también dentro de grupos: seta, flor) o `layers = {"a", "b"}` (solo esas capas visibles: zorro). Sin ninguna de las dos, el sprite aplanado.

## Arquitectura: composición (acordado)
Cada entidad = **cerebro** (script propio en la raíz: decide QUÉ hacer; el jugador lee la entrada, un enemigo tendrá IA) + **componentes** hijos reutilizables en `scripts/componentes/` (el CÓMO). No meter lógica reutilizable en el cerebro.

| Componente | Nodo | Para qué |
|---|---|---|
| `ComponenteMovimiento` | Node | acelera/frena el CharacterBody2D padre y llama a `move_and_slide()` (el padre se procesa antes que los hijos, así que el cerebro fija la intención y el componente la aplica en el mismo frame) |
| `AnimadorDireccional` | Node | dirección cardinal, regla de diagonales tipo Zelda, `reproducir(base)` → `base_frente/lado/espalda` con espejo |
| `ComponenteVida` | Node | vida, invulnerabilidad, `danado`/`murio`/`cambio`; se conecta solo a un `Hurtbox` |
| `ComponenteEstamina` | Node | `gastar()`, regeneración con retraso |
| `ComponenteAtaque` | Node | coloca el `Hitbox` por dirección y lo activa solo en `frames_golpe` |
| `ComponenteCarga` | Node | levantar/lanzar `ObjetoAgarrable` |
| `ComponenteInteraccion` | Area2D | busca delante algo con `interactuar(quien)` u `ObjetoAgarrable` |
| `ComponenteParpadeo` | Node | parpadeo de un CanvasItem |
| `Hitbox` / `Hurtbox` | Area2D | hace / recibe daño |

Dependencias entre componentes por `@export` (se ven en el Inspector), no por rutas fijas. Las máquinas de estado van como enum en el cerebro.
Receta para un enemigo nuevo: CharacterBody2D (capa enemigos) + AnimatedSprite2D + Movimiento + Animador + Vida→Hurtbox (capa enemigos) + Hitbox de contacto (`continuo = true`, capa golpe_enemigo, máscara jugador) + script cerebro con su IA.

## Jugador (hecho)
- `scenes/player/jugador.tscn` + `scripts/player/jugador.gd` (`class_name Jugador`, cerebro). La posición del nodo son los pies. Estados: NORMAL, PIRUETA, ATAQUE, AGARRAR, TIRAR, DANO, MUERTO, BLOQUEADO (`set_bloqueado()` para diálogos/cinemáticas).
- Vida en **cuartos de corazón** (4 por corazón, como el arte de `corazones.aseprite`): `Vida.vida_max = 12` → 3 corazones. El daño de los Hitbox va en cuartos (un enemigo normal debería quitar 2 = medio corazón). El jugador emite `murio` y `reaparecio`; reaparece en `punto_control`.
- `tiene_espada` empieza en false (la dan los sabios).
- Controles: WASD/flechas mover · J atacar · Espacio/K pirueta · E/L interactuar (agarrar, lanzar, hablar). Mando: X atacar, A pirueta, B interactuar.
- Contrato de daño: un `Hitbox` llama a `recibir_golpe(danio, origen)`; lo implementan `Hurtbox`, `ObjetoAgarrable` (vasijas) y lo rompible (arbustos). Interactuar: cualquier nodo con `interactuar(jugador)` en la capa `interactuable`.
- **Ojo:** en Godot un `Area2D` no detecta `StaticBody2D`. Por eso `Hitbox` e `Interaccion` usan `Hitbox.consultar()` (consulta directa al espacio físico), no `get_overlapping_bodies()`.
- Capas de física: 1 mundo · 2 jugador · 3 enemigos · 4 golpe_jugador · 5 golpe_enemigo · 6 interactuable · 7 obstaculo_bajo (la pirueta lo atraviesa).
- `game.tscn` (nodo `Game`; la escena principal del proyecto es el menú principal → cinemática, que al terminar carga `game.tscn`; F6 sobre `game.tscn` la salta) con el Jugador y la `Camara` (Camera2D + `CamaraPixel`, `scripts/systems/camara_pixel.gd`, zoom 1). La cámara NO va dentro de `jugador.tscn`: sigue a su `objetivo` (el Jugador). **CamaraPixel** se actualiza en el ciclo de física (como el jugador), siempre se coloca en píxeles enteros y por defecto va **pegada** al jugador (`suavizado = 0`; con suavizado el jugador tiembla 1 px respecto al fondo). La **física va a 120 ticks/s** (`physics/common/physics_ticks_per_second`) para que coincida con la pantalla de 120 Hz del Mac: a 60 el movimiento solo avanzaba en una de cada dos imágenes y se veía "con fricción"/borroso. Velocidades recomendadas: múltiplos de 60 px/s (60 → 0,5 px por tick, 120 → 1 px por tick). No usar el suavizado nativo de Camera2D ni un RemoteTransform2D: dejan la cámara en medios píxeles y todo tiembla/se ve borroso al moverse. Zoom 1 = 480×270 px de mundo visibles (el ×4 ya lo hace el estiramiento de la ventana).

## Enemigos (hecho: seta bomba y falsa flor)
- Escenas en `scenes/enemies/`, cerebros en `scripts/enemies/`. Hay 2 de cada en `bosque.tscn` para probar (para empezar allí: `zona_inicial` de Game en el Inspector).
- **Sprites:** sus `.aseprite` tienen **una capa por animación** (y las capas se solapan), así que su layout usa `layer = "nombre de la capa"` por fila/columna (soporte añadido en `export_strips.lua`, junto con `frames = n`). Seta: celda 40×40, `offset (0, −16)`, frente/espalda sin lado (`AnimadorDireccional` usa frente de lado). Flor: celda 64×48, `offset (0, −20)`, sin direcciones, mira a la izquierda (`espejar_sin_direccion = true`).
- Componentes nuevos: `ComponenteDeteccion` (ve al jugador por distancia: `radio_vision` / `radio_perder`) y `ComponenteMuerte` (destello + aplastar + desvanecer, apaga golpes, da `monedas`, libera el nodo).
- **SetaBomba** (vida 3): deambula, persigue al verle, a `distancia_explotar` se infla y en el frame 3 suelta una `NubeToxica` (daño 4 = 1 corazón, una vez por objetivo; la voltereta la esquiva). Luego queda escondida 2,5 s (momento de atacarla) y sale. Contacto: 1.
- **FlorFalsa** (vida 4): escondida = flor camuflada e invulnerable; al acercarse sale, muerde (`ComponenteAtaque`, frames 3–5, daño 2) y a los 5 s se esconde y reaparece a ≤ 72 px de su sitio (en suelo libre de la zona).
- El **montón Tocotón** no está: no hay sprite (solo el boceto del guion).

## Mundo (hecho: primer trozo)
- **Recortes de entorno:** `tools/recortes/todos_los_assets.lua` (tabla nombre → rectángulo) + `tools/export_recortes.lua` sacan cada objeto de `todos_los_assets.aseprite` a `assets/sprites/entorno/*.png` y la franja de tiles a `assets/tilesets/tiles_naturaleza.png`. `aislar = true` se queda solo con la mancha más grande (para objetos que se solapan). Las coordenadas salieron de detectar manchas de píxeles.
- **Tiles:** 16×16 con **1 px de separación** (20 en la fila 0; fila 1: 0–6 y 17–19). `tools/build_tilesets.gd` genera `resources/tilesets/naturaleza.tres`; los tiles sólidos (seto 12,0 · agua 16–18,0 · mar 19,0 y 0/17–19,1) se definen como datos en ese script (capa física 1 = mundo). Faltan transiciones (hierba↔arena, esquinas de camino/bordillo): pedírselas a la artista.
- Hierba y tierra (tiles 0–5 de la fila 0) tienen **volteos** como tiles alternativos (1 = H, 2 = V, 3 = H+V), definidos en `volteables` de `build_tilesets.gd`.
- **VariadorPasto** (`scripts/entorno/variador_pasto.gd`, `@tool`): nodo de editor dentro de cada zona; botón "Variar pasto" en el Inspector (o cambiar `semilla`) reparte al azar variantes de hierba con volteos según `pesos`, con semilla fija. Solo toca celdas de pasto.
- Los constructores (`build_tilesets.gd`, `sprite_frames_builder.gd`) conservan el UID del `.tres` anterior (`ResourceSaver.set_uid`); `take_over_path` NO lo conserva.
- Todo se regenera con `tools/export_sprites.sh` (mejor con el editor **cerrado**: si el editor está abierto no recarga el TileSet regenerado y su caché de UID queda vieja → avisos "invalid UID"; se arregla con Proyecto → Recargar proyecto actual).
- **Sombras:** `ComponenteSombra` (`scripts/componentes/componente_sombra.gd`, `@tool`) dibuja el óvalo opaco #106165 de la artista (`sombra.png`, 29×9) a cualquier tamaño, nítido. Va antes del sprite en el árbol. `Decorado` lo trae (`sombra`, `tamano_sombra` 0 = automático 70 % del ancho, `desplazamiento_sombra`); desactivarlo en casas, estatua, puesto del mercado y en objetos que ya traen sombra pintada (rocas, troncos, arbustos grandes de la artista). El jugador tiene una de 12×4 en y = −1 (asoma 1 px bajo los pies; más abajo parece que flota).
- **Decorado** (`scenes/entorno/decorado.tscn` + `scripts/entorno/decorado.gd`, `@tool`): StaticBody2D genérico; se elige `textura` en el Inspector. La posición = base del objeto (como los pies del jugador) → orden por Y correcto. Colisión en la base: `base` (0,0 = automática), `desplazamiento_base`, `solido`.
- **Zonas:** cada zona es una escena en `scenes/levels/` con `Zona` (`scripts/systems/zona.gd`): `Suelo` (TileMapLayer, z_index −1), `Objetos` (y_sort), `Entradas/<nombre>` (Marker2D) y `SalidaZona` (Area2D: `zona_destino` + `entrada_destino`). Límites de cámara = rectángulo pintado (o `limites_camara`).
- **Game** (`scripts/systems/game.gd`): `Mundo` (aquí se instancia la zona), `Jugador`, `Camara`, `Transicion/Fundido`. `cambiar_zona(ruta, entrada)` hace fundido a negro, bloquea al jugador, cambia la zona, coloca al jugador, fija su `punto_control` y ajusta los límites de la cámara. Game, Mundo, Zona y Objetos tienen `y_sort_enabled` para que el jugador se ordene con los decorados.
- Zonas actuales: `pueblo.tscn` ↔ `bosque.tscn` (32×20, de prueba; salida izquierda).
- **Pueblo** (114×92 tiles = 1824×1472 px): sigue el plano de la artista (pueblo amurallado ovalado: templo arriba, plaza de la estatua con greca en el centro, 8 casas, mercado, canales, bosque alrededor). Lo genera `tools/build_pueblo.gd` (`godot --headless --path . --script res://tools/build_pueblo.gd`), que **sobrescribe** la escena: si se retoca a mano, no volver a ejecutarlo. Muralla = piezas `muro_enredadera_*` en una elipse (centro 920,816; semiejes 857×607); colisión baja arriba y casi de todo el alto abajo. Puerta norte → camino → `SalidaBosque` en el borde superior (entrada `desde_bosque`); puerta sur cerrada (`Limites/PuertaSurCerrada`). Los árboles de fuera no tienen colisión (no se llega); las flores sí. Agua sólida; los caminos que la cruzan hacen de vado. `inicio` = delante de `CasaLeonidas`.
- `build_tilesets.gd`: `transformables` (greca 4,1 y 5,1) crea las 7 alternativas: id = H 1 + V 2 + transponer 4.

## Interfaz (hecho)
> Guía completa, con lo pendiente y dónde mirar en los PDF: **`docs/design/guia_interfaz.md`**.

- **Fuente:** `assets/fonts/perfect_dos_vga_437_win.ttf` a 16 px (glifos de 9×16), importada sin antialiasing/hinting/subpíxel. Usar la versión **_win**: la otra coloca los caracteres según la página de códigos de MS-DOS y las tildes salen como símbolos. No tiene Á Í Ó Ú mayúsculas: `CajaDialogo.adaptar_a_fuente()` las muestra sin tilde. Tema global `resources/ui/tema.tres` (`gui/theme/custom`).
- **Arte de UI agrandado:** `dialog_box.png` y `dialog_continue_arrow.png` venían a ×6 (1800×630). `tools/reducir_png.lua` los reduce a tamaño real → `assets/ui/caja_dialogo.png` y `flecha_dialogo.png` (300×105, mismo lienzo). Pestaña del nombre: x 47–136, y 9–23; texto: x 20–260, y 33–81 (3 renglones de ~26 letras).
- **Referencia visual:** `docs/pdf/` (fuera de git: `.gitignore`). La interfaz del nivel 1 sale de `Jugabilidad.pdf` p. 16 ("Interfaz", = Guión p. 2), p. 15 (diálogo con NPC, demo) y p. 10 (burbujas de NPC). Las de Aracne/Cancerbero (Guión p. 68, 113) son de niveles fuera de alcance. Para ver una página: renderizarla con PDFKit (`swift`), el PDF del guion pesa 140 MB.
- **La maqueta del HUD está a ~192×108 px de arte** (cada píxel = 12,7 px en un render a 4000 px de ancho), es decir, con la cámara bastante más cerca que nuestros 480×270. **Decidido (2026-11-09): se mantiene 480×270**, porque la caja de diálogo de la artista (300 px) y las casas (150–180 px) no caben en una pantalla tan pequeña. El HUD usa el arte a su tamaño real y en las mismas esquinas que la maqueta.
- **Arte provisional sacado de las láminas** (`assets/ui/provisional/`): ranura del objeto + icono de la espada, bolsa del inventario con "[ i ]", placa de dinero sin dígitos y las 3 burbujas de NPC. Extraído muestreando el centro de cada bloque del render del PDF y quitando el fondo. Sustituir por los PNG de la artista cuando los entregue.
- **HUD** (`scenes/ui/hud.tscn` + `scripts/ui/hud.gd`, dentro de Game, `jugador` por Inspector), como la lámina 16: corazones arriba a la izquierda (`assets/ui/corazones.png`, 5 estados cada 12 px), ranura del objeto equipado debajo (la espada se ve si `tiene_espada`), bolsa arriba a la derecha (aún sin menú), placa de dinero abajo a la derecha (`ContadorMonedas`: dígitos dibujados de 4×6 px a partir del "0" de la maqueta). La estamina no sale en la maqueta: `BarraEstamina` va sobre la cabeza de Leonidas solo mientras no está llena.
- **Autoload `EstadoJuego`** (`autoload/estado_juego.gd`): monedas (`agregar_monedas`, `gastar_monedas`, señal `monedas_cambio`; las dan los enemigos con `ComponenteMuerte.monedas`) y manzanas (`agregar_manzanas`/`gastar_manzanas`, máx. 9, señal `manzanas_cambio`). Dura **la partida** (sobrevive a cambios de zona y a morir), no se guarda en disco; `reiniciar()` lo pone a cero y lo llama el menú al pulsar Jugar.
- **Diálogos:** autoload `Dialogos` = `scenes/ui/caja_dialogo.tscn` (`CajaDialogo`). `await Dialogos.mostrar(recurso)` o `await Dialogos.mostrar_texto("Nombre: texto")`. Bloquea al jugador, máquina de escribir, E/J avanza (la primera pulsación completa el texto), parte solo las líneas largas en varios cuadros, flecha parpadeante.
- **Recurso `Dialogo`** (`scripts/systems/dialogo.gd`): en `resources/dialogues/*.tres`, campo `texto` en el Inspector: una línea por cuadro, `Nombre: texto` cambia quién habla (nombre ≤ 16 letras), las líneas sin nombre siguen con el último, `#` = comentario. Pensado para que el equipo de guion escriba sin tocar código.
- **`ZonaDialogo`** (`scripts/componentes/zona_dialogo.gd`): Area2D en capa interactuable con su CollisionShape2D; se añade a un cartel o NPC y muestra su `dialogo` al interactuar; señal `hablado`. Al acercarse el jugador muestra la burbuja de la lámina 10 según `tipo` (HABLAR "…", MISION "!", TIENDA "$") en `posicion_burbuja`.
- **Menú principal** (escena principal del proyecto): `scenes/ui/menu_principal.tscn` + `scripts/ui/menu_principal.gd`. Jugar → fundido → `escena_jugar` (la cinemática); Salir cierra (oculto en la web). Teclado/mando (arriba/abajo, Enter/E/J) y ratón; `> ` marca la opción elegida. **Arte PROVISIONAL**: fondo = `fondo_1.png` (pintura del exterior, en modo CANVAS_ITEMS como la cinemática), título y botones de texto con la fuente del juego y un tema propio dentro de la escena. Al llegar el logo/botones de la artista: cambiar `Titulo` por un TextureRect y dar textura a los botones.
- **Retratos en el diálogo** (lámina 15: "solo personajes importantes"): `CajaDialogo.retratos` = {nombre → textura ~46×46}; con retrato el texto se estrecha. Aún no hay retratos dibujados. Ejemplo: el cartel del pueblo (`resources/dialogues/cartel_pueblo.tres`, texto PROVISIONAL).

## NPC (hecho)
- `scenes/npcs/npc.tscn` + `scripts/npcs/npc.gd` (`class_name NPC`, `@tool`): CharacterBody2D (capa mundo, el jugador choca con él) + Sombra + Sprite (`offset (0, −24)`) + Movimiento + Animador + `ZonaDialogo` (círculo r 28). Todo se configura en la raíz desde el Inspector: `sprite_frames`, `dialogo`, `burbuja` (HABLAR/MISION/TIENDA), `posicion_burbuja`; grupo Paseo: `paseo`, `radio_paseo`, `velocidad` (30), `espera`.
- Paseo: el centro es la posición inicial; va a puntos al azar dentro de `radio_paseo`, se para un rato; si choca, se para y elige otro. Al hablar se para y mira al jugador (`ZonaDialogo.empezo`). `paseo = false` → fijo.
- Sprites: layouts `tools/sprite_layouts/{npc_burro,npc_zorro,tendedera}.lua` (celda 56×52, origen (28, 50)). Rejilla 3 columnas × filas `parado`/`caminar`, una capa por animación; las colas del zorro van en capas aparte (`Layer 5` frente, `Layer 4` espalda) → `export_strips.lua` admite `layers = {...}` por columna/fila para aplanar solo esas capas. La tendedera tiene un único frame de frente.
- En el pueblo (`Objetos/NPCs`, añadidos a mano: no volver a ejecutar `build_pueblo.gd`): `Tendedera` fija junto al puesto del mercado (burbuja "$"), `Burro` delante de `CasaBalconNO` y `Zorro` delante de `CasaAmarillaE` (radio 40). Diálogos PROVISIONALES en `resources/dialogues/npc_*.tres`.

## Tienda (hecho)
- **`ComponenteTienda`** (`scripts/componentes/componente_tienda.gd`): Node hijo del vendedor; se asigna en `tienda` del NPC (o de su ZonaDialogo, que entonces atiende la tienda en vez de su `dialogo`). Exports: `articulos`, `nombre_vendedor`, `dialogo_saludo`, `dialogo_sin_monedas`, `dialogo_despedida`. Al hablarle: si `EstadoJuego.monedas` < el precio más barato → solo `dialogo_sin_monedas`; si no → saludo → menú → despedida. `comprar()` no cobra si no cabe el objeto. Para vender algo nuevo: crear su `.tres` y añadir su `id` en `cantidad`/`cabe`/`entregar`.
- **`ArticuloTienda`** (`scripts/systems/articulo_tienda.gd`, Resource): `id`, `nombre`, `descripcion` (≤ 26 letras), `precio`, `icono`. `resources/tienda/manzana.tres` (3 monedas, PROVISIONAL).
- **Menú:** autoload **`Tienda`** = `scenes/ui/menu_tienda.tscn` (`class_name MenuTienda`; el autoload no puede llamarse igual que la clase). `await Tienda.abrir(componente)`. Misma caja que el diálogo: 2 renglones de lista (`> icono Nombre (tienes)  N mon.` + "Salir") y 1 de información/avisos ("¡Gracias!", "No te alcanza.", "No puedes llevar más."). Arriba/abajo eligen, E/J compran, Espacio/K/Esc salen. Mantiene bloqueado al jugador mientras está abierto. Diseño PROVISIONAL (no hay maqueta).
- En el pueblo: `Objetos/NPCs/Tendedera/Tienda` vende manzanas. Comer la manzana (curar) aún no está.
- Para probar con pulsaciones simuladas (`Input.action_press`): hacer `await process_frame` justo antes de pulsar, o la pulsación cae después del `_process` del diálogo/tienda y no se lee.

## Cinemática inicial (hecho)
- **Se abre desde el menú principal** (Jugar): `scenes/cinematics/cinematica_inicial.tscn` + `scripts/cinematics/cinematica_inicial.gd`. Al terminar (o con **Esc**, `ui_cancel`) carga `escena_siguiente` = `game.tscn`. Sigue el video del prototipo (`Assets_guion_todo/WhatsApp Video 2026-11-05…mp4`, 2:40):
  1. Ilustración del cumpleaños (`assets/backgrounds/cinematica/fondo_2.png`, 1920×1080) + diálogo.
  2. Exterior pasando del día a la noche: **39 fotogramas clave JPG** en `assets/backgrounds/cinematica/atardecer/` (cada 5 de la secuencia original 55–245; antes y después de eso la imagen no cambia) que se funden entre sí (error medio < 1 nivel de color). Sustituyen a los 360 PNG (435 MB → 8 MB).
  3. Cuarto en pixel art (`Cuarto`, escala ×2): Kathita entra con la carta, Leonidas duerme → `despertar` → `despierto`; Kathita `dar_regalo`; se lee la carta; diálogo final.
- **Modo de escala:** las pinturas y la carta se ven a la resolución real de la ventana poniendo `get_window().content_scale_mode = CANVAS_ITEMS` mientras salen; el cuarto vuelve al modo normal (viewport, 480×270). La carta usa la fuente a 8 px, que solo se lee en CANVAS_ITEMS.
- **Textos:** `resources/dialogues/cinematica_{cumpleanos,despertar,mision,entrega,carta,final}.tres` (formato `Dialogo`; en la carta cada línea es un párrafo). **Ojo:** en los `.tres` escritos a mano no usar comillas `"` dentro del texto (rompen el archivo; desde el Inspector no pasa).
- **Sprites:** `tools/export_sprites.sh` exporta las tiras a `assets/sprites/cinematica/*.png` y `tools/build_cinematica.gd` (tabla `HOJAS`: paso, ancho, `dx`, fps de cada tira) genera `resources/sprite_frames/cinematica_cama.tres` (celda 38×47) y `cinematica_mama.tres` (celda 50×50), alineados abajo: en el `AnimatedSprite2D`, `centered = false` y `offset = (-ancho/2, -alto)`.
- **Falta el fondo del cuarto:** mientras tanto hay dos rectángulos provisionales (`Cuarto/Provisional`). Cuando la artista lo entregue, asignarlo en `fondo_cuarto` (Inspector) y se ocultan solos.
- Para depurar: las pulsaciones dentro de corrutinas se leen en `_process` (`_pulsado`), porque las inyectadas por el MCP no llegan a tiempo si se comprueban tras `await process_frame`.

## Assets que faltan o no se vieron
Sprite de monedas, ranura/ítem de la espada, arbustos, enemigo Tocotón, ítem de la espada, árbol de manzanas, tiles del pueblo/bosque/playa, obstáculos del mar (el barco con Leonidas sí está en `leonidas_mini`), jefe Medusa. `todos_los_assets.aseprite` (1000×600, 1 frame, 1 capa) tiene: tiles (franja arriba a la izquierda), casas, templo redondo, casa-tocón, puesto de mercado, árboles de manzanas, pinos, cipreses, arbustos, flores, rocas, troncos, columnas, ruinas, estatua, cartel. Las PNG de `assets/sprites/environment/` son ilustraciones grandes (~600 px), no pixel art a escala.

## Reglas del repo
- GitHub rechaza archivos >100 MB. **Fuera del repo** (están en la carpeta externa `Leonidas_12_pruebas/Assets_guion_todo`): el PDF "Guión Multimedia" (146 MB), el video del prototipo (110 MB), `playa entero.png` (16 MB) y los 360 PNG de "Fondo con puesta sol" (~430 MB; el juego usa los fotogramas clave de `atardecer/`, y `assets/backgrounds/cinematica/Untitled_*.png` está en `.gitignore`). Si hacen falta, usar Git LFS.
- No subir el binario de Aseprite, nada de `.godot/` ni `.DS_Store` (en `.gitignore`).
- Commits pequeños y en español; avisar al usuario antes de reescribir historial ya subido.

## Documentos de diseño (LEER ANTES DE EMPEZAR UNA TAREA)
- **`docs/design/indice_pdfs.md`**: índice página por página de `docs/pdf/Jugabilidad.pdf` (22 pp.) y `docs/pdf/Guión Multimedia (1).pdf` (145 pp.): qué hay en cada lámina, qué entra en el alcance (Guión pp. 1–39 = niveles 1 y 2, fichas pp. 135–145) y qué no. Para cualquier tarea (enemigo, NPC, barco, Medusa…), buscar ahí su página antes de abrir el PDF.
- **`docs/design/guia_interfaz.md`**: guía de la UI. Recoge las reglas de escala, cada pieza hecha (con posiciones y arte), y para cada pieza pendiente (menú de inventario, pausa, vida de Medusa, tienda, game over) qué dicen los PDF y una propuesta. **Leerla antes de tocar la interfaz.**
- **`tools/pdf_paginas.swift`**: consulta los PDF sin abrirlos (`info`, `texto`, `render`, `hoja` de miniaturas). Los renders van al scratchpad o a `/tmp`, nunca al repo.
- `docs/design/jugabilidad_primera_parte.md` (el más claro), `guion_primera_cinematica.md`, `jugabilidad_laminas.txt` y `guion_multimedia_laminas.txt` (texto extraído de las láminas, con ruido de maquetación).
- ⚠ **Nivel 2 (Guión p. 22):** estética "lineless" con textura y animación con rig/esqueleto, **no pixel art**. Antes de empezarlo, hablar con la artista sobre el formato del arte y la escala.

# Plan: Kathita entrega el libro-inventario al salir de casa

## Contexto
Tras la cinemática inicial la partida empieza en `pueblo` (entrada `inicio`, delante de `CasaLeonidas`). Queremos una pequeña escena jugable: cuando Leonidas se aleja unos pasos de casa, su madre **Kathita** lo llama, sale y le regala un **libro** que es su **inventario**. El libro reúne tres cosas: **guardar la partida**, **inventario de objetos** y **mapa**. Además Kathita le enseña la **voltereta** (tutorial integrado). La **espada la siguen dando los sabios** (sin cambios en el diseño; esa escena queda fuera de este plan).

Estado actual relevante:
- La bolsa del HUD (`Inventario`, `assets/ui/provisional/bolsa_inventario.png`) se ve siempre y no abre nada; el menú del inventario está pendiente (`guia_interfaz.md`, Jugabilidad p. 17: pestañas MAPA · MALDICIONES · OBJETOS · GUÍA/MISIONES).
- Kathita solo tiene sprites de la cinemática (vista lateral, ~38 px de alto): `resources/sprite_frames/cinematica_mama.tres` con `caminar`, `parada`, `dar_regalo`, `caminar_regalo`, `parada_regalo` (celda 50×50, `centered = false`, `offset = (-25, -50)`). Sirven a escala 1 en el mundo hasta que haya sprites cenitales.
- **Los sprites del libro aún no existen** (llegan pronto): usar marcadores provisionales.
- `CajaDialogo._cerrar()` desbloquea al jugador un frame después de cerrar → en una secuencia de varios diálogos el jugador recuperaría el control entre medias.

## Diseño de la escena (flujo)
1. Leonidas aparece en `inicio` con control. Un `Disparador` (Area2D, máscara capa 2 jugador) a ~3–4 tiles de la puerta.
2. Al cruzarlo (solo si `not EstadoJuego.tiene_libro`): se bloquea al jugador, `Dialogo` de llamada: «Kathita: ¡Leonidas, espera!». Leonidas se gira hacia la casa (`animador.mirar()`).
3. Kathita aparece en la puerta (`Puerta`, Marker2D) con un fundido corto, camina (`caminar_regalo`, tween a 60 px/s) hasta ~20 px de Leonidas, `flip_h` según el lado; `parada_regalo`.
4. Diálogo del libro (PROVISIONAL, lo reescribe el guion): es un regalo, aquí puede apuntar lo que lleva, ver el mapa y «escribir» su viaje (guardar). `dar_regalo` → `parada`.
5. Aviso de objeto obtenido (sin nombre): «¡Obtuviste el libro de Leonidas! Pulsa [I] para abrirlo.» → `EstadoJuego.tiene_libro = true` (aquí, para que no se repita aunque luego se interrumpa).
6. Diálogo de la voltereta: «Pulsa Espacio (o K; A en el mando) para dar una voltereta. Cansa: mira la barra de estamina.» + «¡Inténtalo!».
7. Se desbloquea al jugador y se espera a su primera voltereta (nueva señal `Jugador.pirueta_empezada`). Entonces: «Kathita: ¡Muy bien! Ve con cuidado, hijo. Los sabios te esperan en el templo.»
8. Kathita vuelve a la puerta (`caminar`), se desvanece y el nodo se libera.

## Cambios

### Nuevos
- `scenes/cinematics/escena_kathita_libro.tscn` + `scripts/cinematics/escena_kathita_libro.gd` (`class_name EscenaKathitaLibro`, Node2D):
  - Hijos: `Puerta` (Marker2D), `Disparador` (Area2D + CollisionShape2D rectangular), `Kathita` (Node2D, oculto) con `Sombra` (`ComponenteSombra`) + `Sprite` (AnimatedSprite2D con `cinematica_mama.tres`).
  - Exports: `dialogo_llamada`, `dialogo_libro`, `texto_obtenido`, `dialogo_voltereta`, `dialogo_despedida` (`Dialogo`), `velocidad := 60.0`, `distancia_al_jugador := 20.0`.
  - `_ready`: si `EstadoJuego.tiene_libro` → `queue_free()`. Busca el jugador con `get_first_node_in_group(&"jugador")`.
  - Secuencia en una corrutina como `cinematica_inicial.gd` (`_dialogo`, `_mover`), envuelta en `Dialogos.mantener_bloqueo = true/false`.
- `resources/dialogues/kathita_{llamada,libro,voltereta,despedida}.tres` (formato `Dialogo`, textos PROVISIONALES; sin comillas `"` dentro).
- Arte provisional del libro: `assets/ui/provisional/icono_libro.png` (p. ej. 14×14, cuadrado marrón con lomo) para el HUD; anotar en CLAUDE.md «Assets que faltan». Cuando llegue el sprite de la artista, sustituir y, si trae animación de abrir/entregar, usarla en el paso 4.

### Modificados
- `autoload/estado_juego.gd`: `var tiene_libro := false` (en `reiniciar()` vuelve a false). Comentario: el libro = inventario + mapa + guardar.
- `scripts/ui/caja_dialogo.gd`: `var mantener_bloqueo := false`; en `_cerrar()` no desbloquear si está activo (evita que el jugador se mueva entre diálogos de la escena).
- `scripts/player/jugador.gd`: `signal pirueta_empezada`, emitida en `_pirueta()`. (Ojo: hay un cambio sin commitear en `_pirueta` del espejo de `pirueta_lado`; no tocarlo.)
- `scripts/ui/hud.gd` / `hud.tscn`: el icono `Inventario` solo visible si `EstadoJuego.tiene_libro`, con el icono del libro (provisional) en lugar de la bolsa.
- `scenes/levels/pueblo.tscn`: instanciar la escena en `Objetos/Eventos/EntregaLibro`, con `Puerta` en la puerta de `CasaLeonidas` (casa en (629, 1109), `inicio` en (586, 1127); medir la puerta en el editor) y el `Disparador` entre la casa y la plaza. **A mano / por MCP: no volver a ejecutar `build_pueblo.gd`.**
- Docs: `jugabilidad_primera_parte.md` (la madre da el libro y enseña la voltereta; los sabios, espada y misión), `guia_interfaz.md` (la bolsa pasa a ser el libro; sus 3 funciones), CLAUDE.md (sección «Escena de Kathita» + `tiene_libro` + `mantener_bloqueo`).

## Fuera de este plan (siguientes tareas)
- **Menú del libro** (acción `inventario` = I / Select): pestañas Objetos (comer manzanas), Mapa (imagen fija), Guardar, Misiones. Solo se abre con `tiene_libro`.
- **Guardar partida**: hoy `EstadoJuego` no se guarda en disco; harán falta `guardar()/cargar()` (ConfigFile en `user://`) con zona, entrada, monedas, manzanas, flags.
- **Sabios y la espada**: escena en el templo; entonces `Jugador.tiene_espada` debe empezar en `false` (hoy está en `true` para pruebas).
- Sprites cenitales de Kathita (frente/lado/espalda) para que pueda quedarse como NPC.

## Verificación
1. F6 sobre `game.tscn` (empieza en `pueblo`/`inicio`): caminar hacia la plaza → se dispara la escena; el jugador no se mueve entre diálogos; Kathita sale y vuelve por la puerta.
2. Al pulsar Espacio/K tras «¡Inténtalo!» sale la despedida; el HUD muestra el icono del libro.
3. Volver a pasar por el disparador o cambiar de zona y regresar: no se repite. Menú → Jugar: se repite (`reiniciar()`).
4. Morir/estamina: la voltereta sin estamina no dispara la señal (solo se emite si la pirueta empieza).
5. `godot --headless --path . --script res://tools/verificar_zonas.gd` sigue pasando (el disparador no tapa la entrada `inicio`).
6. Prueba con el MCP de Godot AI (`project_run` + `Input.action_press`, con `await process_frame` antes de pulsar) para recorrer los diálogos.

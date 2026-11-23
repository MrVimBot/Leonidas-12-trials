# Plan: escena de los sabios (espada + misión)

> **Hecho el 2026-11-14** (ver CLAUDE.md, «Escena de los sabios»). Cambios respecto al plan:
> el disparador cubre solo el pasillo entre los canales (x 868–972), no 200 px; los hablantes
> son «Toro», «Carnero», «Fauno», «Ave» (la pestaña del nombre solo muestra 8 letras); en vez de
> `mostrar_burbuja = false`, `ZonaDialogo` no enseña burbuja si no tiene diálogo ni tienda.

> Pensado para ejecutarlo en otra sesión (Opus o Sonnet). Leer antes `CLAUDE.md` (secciones
> «Escena de Kathita», «NPC», «Jugador», «Interfaz»). Responder y escribir textos en español.
> **No hacer commits ni push** (los hace Esteban).

## Contexto

Es la pieza que falta para cerrar el arranque del nivel 1: hoy la espada la regala un
atajo de depuración (`Game.depurar_dar_espada = true`) y nadie pone
`EstadoJuego.mision_recibida`, así que Zeus nunca deja salir del pueblo de forma legítima.
Según el guion (Guión p. 8, `docs/design/jugabilidad_primera_parte.md` «Encuentro con los
sabios»): Leonidas va al norte del pueblo, **al acercarse** a los sabios se activa una
cinemática breve, le asignan la misión (ir a la isla de Medusa y derrotarla; ir al **sur**,
a la orilla, donde espera una barca) y le entregan una **pequeña espada**, que además es la
segunda etapa del tutorial (atacar).

Decisiones ya tomadas con Esteban (2026-11-14):
- **Lugar:** delante del templo del pueblo (provisional: no hay arte del interior). Hacer la
  escena autocontenida para poder moverla a una zona `templo` cuando exista.
- **Inicio:** automático al acercarse (disparador), como la escena de Kathita.
- **Tutorial:** tras la espada se devuelve el control y la escena sigue con el **primer ataque**.
- **BarreraSur** vuelve a exigir la MISIÓN (hoy tiene `requisito = 1` = VOLTERETA: se puede
  salir al bosque sin ver a los sabios).

## Lo que ya existe y se reutiliza

| Qué | Dónde |
|---|---|
| Patrón de cinemática jugable (disparador → `Dialogos.mantener_bloqueo` → diálogos → devolver control → esperar señal → seguir) | `scripts/cinematics/escena_kathita_libro.gd` (copiar su estructura) |
| Sprites de los 4 sabios (solo de frente: `parado_frente`, `caminar_frente`; celda 48×60, offset (0, −28)) | `resources/sprite_frames/sabio_{1..4}.tres` (1 toro, 2 carnero, 3 fauno, 4 ave) |
| NPC fijo con diálogo y burbuja | `scenes/npcs/npc.tscn` + `scripts/npcs/npc.gd` (`paseo = false`) |
| Estado: `tiene_espada`, `mision_recibida`, `completar_mision`, `empezar_mision` (ya se guardan/cargan) | `autoload/estado_juego.gd` |
| Misiones `ir_al_templo` y `derrotar_medusa`, objeto `espada` con icono 16×16 | `resources/misiones/`, `resources/objetos/espada.tres` |
| Barreras de Zeus (se abren solas con `mision_recibida`) | `scripts/systems/barrera_mision.gd` |
| Pose «objeto en alto» (`comer` + Sprite2D `ObjetoEnMano`) | `scripts/player/jugador.gd` (`_mostrar_objeto_en_mano`) |
| Retroceso/caminata por tween con `animador.reproducir(&"caminar")` | `barrera_mision.gd::_detener` |

Geometría medida en `scenes/levels/pueblo.tscn`: `Templo` en (920, 626) con colisión
x 755–1085, y 556–626; columnas sólidas en (802, 702) y (1032, 702); la calle este–oeste
empieza en y 704. Queda una explanada libre de **y 626–704, x ~815–1020**.

## Diseño

### Flujo de la escena
1. Leonidas cruza el `Disparador` (explanada). Se bloquea (`Dialogos.mantener_bloqueo = true`,
   `jugador.set_bloqueado(true)`), camina por tween hasta `PuntoLeonidas` mirando arriba.
2. `sabios_bienvenida` → `sabios_mision` (la misión: Medusa, ir al sur, la barca).
3. El sabio 1 (toro) da 2–3 pasos al frente (`caminar_frente`, tween ~10 px) → `sabios_espada`.
4. **Entrega atómica** (todo junto, antes de devolver el control, para que guardar/cargar a
   mitad no deje estados raros):
   `EstadoJuego.tiene_espada = true`, `completar_mision(&"ir_al_templo")`,
   `empezar_mision(&"derrotar_medusa")`, `mision_recibida = true`.
5. Leonidas levanta la espada (pose de objeto obtenido, ver abajo) +
   `Dialogos.mostrar_texto("¡Obtuviste la espada! Pulsa [J] para atacar.")`.
6. `sabios_ataque` («pruébala») → `await process_frame` → `Dialogos.desbloquear_jugador()` →
   `await jugador.ataque_empezado` → esperar ~0,6 s.
7. `sabios_despedida` (recordatorio: al sur, la orilla). El sabio vuelve a su sitio.
   Los sabios quedan como NPC normales con `sabios_recordatorio` y burbuja «…».

Si al cargar la zona ya `mision_recibida`: no hay disparador y los sabios están directamente
en modo «después» (paso 7). Los cuatro miran siempre de frente (no hay otras vistas):
`mirar_al_hablar = false`.

### Nodos
- **Sabios:** 4 instancias de `npc.tscn` en `Objetos/NPCs` (`Sabio1`…`Sabio4`), que es el nodo
  con `y_sort` (así no hace falta el `reparent` que usa Kathita). Posiciones: y = 646,
  x = 878, 906, 934, 962. `paseo = false`, `mirar_al_hablar = false`,
  `posicion_burbuja = (0, −60)`, sin `dialogo` en el Inspector (lo pone la escena).
- **`scenes/cinematics/escena_sabios.tscn`** (`Node2D`, `class_name EscenaSabios`), instanciada
  en `Objetos/Eventos/EscenaSabios` en (920, 646):
  - `Disparador` (Area2D, capa 0, máscara 2, `monitorable = false`): rectángulo ~200×44
    centrado en (0, +32) → cubre la explanada sin tocar la calle.
  - `PuntoLeonidas` (Marker2D) en (0, +38).
  - Exports: `sabios: Array[NPC]` (asignados en el pueblo), `sabio_que_entrega := 0`,
    los 6 `Dialogo`, `texto_obtenido`, `velocidad := 60.0`.
  Dependencias por `@export`, sin rutas fijas (convención del proyecto).

## Pasos de implementación

1. **Guardar este plan** en `docs/design/plan_escena_sabios.md`.
2. **`scripts/player/jugador.gd`**
   - `signal ataque_empezado`, emitida al final de `_atacar()` (igual que `pirueta_empezada`).
   - Método público `mostrar_objeto_obtenido(icono: Texture2D, duracion := 1.0)`: pose `comer`
     mirando al frente + `ObjetoEnMano` con el icono, sin curar; al acabar oculta el icono y
     vuelve a `parado`. Reutilizar `_mostrar_objeto_en_mano`; añadir un export
     `posicion_objeto_obtenido` (el de comer, (11, −18), está medido para la manzana de 9×10;
     ajustar a ojo para el icono de 16×16). Debe funcionar con el estado BLOQUEADO (no cambiar
     de estado: solo animación + sprite).
3. **`scripts/npcs/npc.gd`**: export `desplazamiento_sprite := Vector2(0, -24)` aplicado en
   `_aplicar_aspecto()` (los sabios necesitan (0, −28)). No cambia a los NPC actuales.
4. **Diálogos** en `resources/dialogues/` (formato `Dialogo`, PROVISIONALES para el equipo de
   guion; nombres ≤ 16 letras; **sin comillas `"` dentro del texto**):
   `sabios_bienvenida`, `sabios_mision`, `sabios_espada`, `sabios_ataque`, `sabios_despedida`,
   `sabios_recordatorio`. Hablantes provisionales: «Sabio Toro», «Sabio Carnero»,
   «Sabio Fauno», «Sabio Ave», «Leonidas». Contenido mínimo que deben decir: tradición de los
   15 años (enlaza con la carta), misión = ir a la isla de Medusa y derrotarla, ir al sur
   hasta la orilla donde espera una barca y alguien que explicará el resto, plazo de una
   semana, entrega de la espada, cómo atacar.
5. **`scripts/cinematics/escena_sabios.gd` + `scenes/cinematics/escena_sabios.tscn`** según el
   diseño. Detalles:
   - `_ready`: si `mision_recibida` → `_modo_despues()` y liberar el `Disparador`. Si no,
     en cada sabio `ZonaDialogo.mostrar_burbuja = false` (sin diálogo no hay nada que hablar).
   - `_modo_despues()`: a cada sabio, `ZonaDialogo.dialogo = dialogo_recordatorio`,
     `mostrar_burbuja = true`.
   - Mover al sabio: `Sprite.play(&"caminar_frente")` + tween de `position`; al parar,
     `parado_frente`.
   - Bandera `_en_curso` y `set_deferred(&"monitoring", false)` como en Kathita.
6. **`scenes/levels/pueblo.tscn`** (NO ejecutar `build_pueblo.gd`). Con el editor abierto, usar
   el MCP de Godot AI (`node_create` con instancia de escena, `node_set_property`,
   `scene_save`); con el editor cerrado, editar el `.tscn` a mano:
   - Añadir `Sabio1..4` en `Objetos/NPCs` y `EscenaSabios` en `Objetos/Eventos` con su array.
   - **`BarreraSur`: quitar `requisito = 1`** (vuelve a MISION con los diálogos de Zeus por
     defecto de `barrera_mision.tscn`; comprobar que los trae).
   - Tras usar el editor, comprobar que `project.godot` conserva los autoloads (el editor
     abierto a veces los borra).
7. **`scripts/systems/game.gd`**
   - `depurar_dar_espada` pasa a `false` por defecto (actualizar su comentario).
   - Que `depurar_mision_recibida` también dé la espada y marque las misiones (equivale a
     «los sabios ya pasaron»), para seguir probando bosque/playa.
   - Nuevo `depurar_saltar_kathita` (da el libro y `voltereta_aprendida`), para probar los
     sabios sin repetir la escena de Kathita cada vez.
8. **HUD:** comprobar en `scripts/ui/hud.gd` (~línea 104) que el icono de la espada aparece en
   el momento de recibirla; si solo se refresca al inicio, conectarlo a
   `EstadoJuego.objetos_cambio`.
9. **Documentación:** `CLAUDE.md` (nueva sección «Escena de los sabios (hecho)», quitar los
   «Pendiente: escena de los sabios», corregir lo de BarreraSur y las banderas de depuración),
   `docs/design/assets_pendientes.md` (sabios → en uso).

## Fuera de alcance (anotar como pendiente)
- Interior del templo / sala de reuniones (falta arte) y retratos de los sabios en el diálogo.
- El NPC de la playa que explica la barca (Guión p. 8: «alguien que le dirá qué hacer»).
- Textos definitivos (equipo de guion).

## Verificación

1. Estáticas (editor cerrado o en paralelo):
   - `godot --headless --path . --script res://tools/verificar_zonas.gd`
   - `godot --headless --path . --script res://tools/verificar_barreras_pueblo.gd`
   - Abrir el proyecto sin errores de parseo (MCP `logs_read` o `godot --headless --path . --quit`).
2. Jugando (`project_run` del MCP sobre `game.tscn` con `depurar_saltar_kathita = true`), con
   pulsaciones simuladas (`await process_frame` antes de cada `Input.action_press`):
   - Antes de los sabios: J no ataca, el HUD no muestra la espada, **ambas** puertas (norte y
     sur) paran a Leonidas con Zeus.
   - Al entrar en la explanada empieza la escena sola; Leonidas queda frente a los sabios,
     sin atravesar a ninguno; orden por Y correcto con el templo y las columnas.
   - Tras la entrega: espada en el HUD y en el libro (Objetos Importantes); en Misiones,
     «Ve a ver a los sabios» tachada y «Derrota a Medusa» activa.
   - La escena no avanza hasta el primer espadazo; después, despedida y control normal.
   - Hablar con cualquier sabio da el recordatorio; volver a pisar la explanada no repite nada.
   - Las dos puertas dejan salir; se llega al bosque.
   - Guardar en el libro justo tras recibir la espada (antes de atacar) → Continuar: los
     sabios están en modo «después», con espada y misión.
   - Partida nueva completa desde el menú (cinemática → Kathita → sabios → bosque) con las
     banderas de depuración apagadas.


## Segunda fase: regreso con la cabeza de Medusa (hecho, 2026-11-22)
- En la misión y la despedida los sabios piden volver con la cabeza petrificada.
- Con Medusa vencida y sin la misión del Minotauro: burbuja «!» en los cuatro; al hablar con
  cualquiera (`sabios_regreso`) Leonidas se coloca, enseña la cabeza (la conserva) y recibe
  «Derrota al Minotauro» (`sabios_minotauro`): debe seguir por debajo de la isla de Medusa,
  al sur de la cueva, por mar (ese segundo mar está PENDIENTE, ver `plan_minijuego_barco.md`).
- Misión «Regresa con los sabios» (`regresar_con_sabios`): empieza al vencer a Medusa y se
  completa al recibir la del Minotauro.
- Después, recordatorios `sabios_recordatorio_minotauro_*`. Prueba: `prueba_escena_sabios.gd`.

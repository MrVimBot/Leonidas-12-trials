# Pruebas automáticas

Pruebas de jugabilidad sin interfaz (`--headless`), sin addons. Cada `prueba_*.gd` es una escena
de juego real (o un autoload) manejada con eventos de entrada reales.

## Ejecutar

```bash
tools/verificar_todo.sh                 # los 2 verificadores del mapa + todas las pruebas
tools/verificar_todo.sh libro           # solo las que contengan "libro" en el nombre
tools/verificar_todo.sh -v prueba_barco # además, la salida completa
GODOT=/ruta/Godot tools/verificar_todo.sh
```

Una línea por comprobación (nombre, OK/FALLO, segundos) y código de salida ≠ 0 si algo falla.
Una sola prueba, a mano:

```bash
godot --headless --fixed-fps 120 --path . --script res://tools/pruebas/lanzar.gd -- prueba_estado
```

Salida de cada prueba: líneas `PASA` / `FALLA`, `COMPROBACIONES: N` y `RESULTADO: TODO PASA` o
`RESULTADO: N FALLOS` (código 0 / 1).

## Qué hay

`prueba_estado`, `prueba_guardado` (+ `datos/partida_ejemplo.cfg`), `prueba_dialogo`,
`prueba_transiciones`, `prueba_jugador_bloqueo`, `prueba_jugador_estados`, `prueba_entrada`,
`prueba_libro_{raton,navegacion,barco}`, `prueba_escena_{zeus,kathita,sabios}`,
`prueba_caminar_hasta`, `prueba_cinematica`, `prueba_pantalla`, `prueba_combate`, `prueba_npc`,
`prueba_objetos_sueltos`, `prueba_ataque_formas` (forma del golpe por dirección: área exacta, una sola forma, sondas), `prueba_avisos_componentes` (avisos de configuración del editor), `prueba_barco`, `prueba_musica`, `prueba_microfono` y
`prueba_animaciones` (compara con `referencias/animaciones.txt`; si la artista cambia sprites,
regenerarla a propósito con `... -- prueba_animaciones generar`).

## Escribir una prueba nueva

1. Crear `tools/pruebas/prueba_<tema>.gd` con `extends "res://tools/pruebas/base_prueba.gd"`, una
   cabecera `##` que diga qué cubre y `func ejecutar() -> void:` (admite `await`). No definir `_ready()`.
2. Usar las utilidades de `base_prueba.gd`: `ok()`, `ticks()`, `esperar_hasta()`, `pulsar()`,
   `tecla()`, `crear_game()`, `ir()`, `cerrar_dialogos()`… (documentadas en el propio archivo).
3. Entrada siempre por eventos (`Input.parse_input_event`), no con `Input.action_press`.
4. Ejecutarla con `tools/verificar_todo.sh <nombre>` y dos veces seguidas: no puede depender del azar
   (fijar semillas) ni del orden.

Protecciones de la base: la partida va a `user://prueba_partida.cfg` (se borra al empezar y al
acabar; si `user://partida.cfg` cambia, la prueba FALLA) y cada prueba tiene un tiempo máximo real
(120 s por defecto, `tiempo_maximo`).

## Qué NO cubren

Aspecto en pantalla (colores, posiciones, animación vista), sonido real (solo qué pista suena),
mando, micrófono real (solo el camino sin micrófono y el nivel forzado), exportación web ni
rendimiento. El recorrido de humo a mano de `docs/plan/00_indice.md` sigue siendo necesario.

## Avisos conocidos de headless

`ERROR: Parameter "t" is null` al abrir el libro (captura de pantalla con el renderizador vacío),
los avisos de recursos/ObjectDB al salir y el error de `prueba_microfono` (quita el bus a propósito)
son inofensivos: `verificar_todo.sh` los ignora.

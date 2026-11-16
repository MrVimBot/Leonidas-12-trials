class_name Capas
## Capas de física del proyecto. Deben coincidir con los nombres de
## Proyecto → Configuración → Nombres de capa → Física 2D (`[layer_names]` de project.godot):
## 1 mundo · 2 jugador · 3 enemigos · 4 golpe_jugador · 5 golpe_enemigo · 6 interactuable · 7 obstaculo_bajo.
##
## Hay dos formas de nombrar una capa y no son intercambiables:
## - Máscara de bits (MUNDO, JUGADOR…): para `collision_layer`, `collision_mask` y las
##   consultas al espacio físico. Se pueden combinar con `|` (p. ej. `MUNDO | ENEMIGOS`).
## - Número de capa (NUMERO_*, 1..32): para `set_collision_layer_value()` y
##   `set_collision_mask_value()`, que activan o apagan una sola capa.

const MUNDO := 1 << 0
const JUGADOR := 1 << 1
const ENEMIGOS := 1 << 2
const GOLPE_JUGADOR := 1 << 3
const GOLPE_ENEMIGO := 1 << 4
const INTERACTUABLE := 1 << 5
const OBSTACULO_BAJO := 1 << 6

const NUMERO_MUNDO := 1
const NUMERO_JUGADOR := 2
const NUMERO_ENEMIGOS := 3
const NUMERO_GOLPE_JUGADOR := 4
const NUMERO_GOLPE_ENEMIGO := 5
const NUMERO_INTERACTUABLE := 6
const NUMERO_OBSTACULO_BAJO := 7

@tool
class_name ComponentePaseo
extends Node
## Deambular: la entidad espera un rato, elige un punto al azar alrededor de `centro`, camina
## hasta él y vuelve a esperar. Si choca, se para y elige otro. Lo usan el NPC y la seta bomba.
##
## El cerebro decide CUÁNDO pasea (llama a `actualizar(delta)` en cada tick de física mientras
## está en su estado de paseo) y qué animación pone (lee `andando` y `hacia` después de
## actualizar); este componente decide el destino, las esperas y las paradas, y mueve el
## cuerpo con el `ComponenteMovimiento`. Los choques los reenvía el cerebro con
## `al_chocar(colision.get_normal())` (solo cuenta si está en su estado de paseo).
##
## El destino se elige AL PARAR (no al acabar la espera): así `ir_a()` puede mandarlo a otro
## sitio (la seta vuelve a su origen tras perder de vista a Leonidas) y el orden de las
## tiradas del azar es: espera, ángulo, distancia.
##
## Los dos usuarios eligen el punto de forma distinta, de ahí los parámetros del grupo
## "Elección del destino": el NPC reparte uniforme por el área del círculo, no se mueve si el
## viaje sería menor de 8 px y se rinde si tarda el doble de lo previsto; la seta reparte
## uniforme por la distancia (entre 8 px y el radio), sin tiempo límite.
##
## `@tool` solo para avisar en el editor de lo que falta; en el editor no hace nada más.

enum Reparto {
	AREA, ## Uniforme por superficie (sqrt): los puntos no se amontonan en el centro.
	DISTANCIA, ## Distancia uniforme entre `distancia_minima` y `radio`.
}

## Quien aplica el movimiento. El cuerpo es el suyo (`movimiento.cuerpo`).
@export var movimiento: ComponenteMovimiento:
	set(valor):
		movimiento = valor
		update_configuration_warnings()
## Distancia máxima (px) a `centro`.
@export var radio := 48.0
## Velocidad al andar (px/s). Múltiplos de 30 se ven más suaves (física a 120 Hz).
@export var velocidad := 30.0
## Segundos parado entre un viaje y otro (mínimo, máximo).
@export var espera := Vector2(1.5, 4.0)

@export_group("Elección del destino")
@export var reparto := Reparto.AREA
## Con `Reparto.DISTANCIA`: distancia mínima al centro.
@export var distancia_minima := 0.0
## Si el viaje elegido mide menos de esto (px), no se mueve: espera 0,5 s y elige otro.
## 0 = sin límite.
@export var viaje_minimo := 0.0
## Se rinde y se para si tarda más de `margen_tiempo` veces el tiempo previsto (por si algo
## lo frena sin chocar). 0 = sin tiempo límite.
@export var margen_tiempo := 2.0

## Punto alrededor del cual pasea. Lo fija el cerebro (su posición inicial) antes de `activar()`.
var centro := Vector2.ZERO
## Generador propio (se puede fijar `rng.seed` para pruebas reproducibles).
var rng := RandomNumberGenerator.new()
## Tras `actualizar()`: si en ese tick ha andado (false = parado o acaba de llegar).
var andando := false
## Tras `actualizar()` con `andando`: vector (sin normalizar) del cuerpo al destino.
var hacia := Vector2.ZERO

var _destino := Vector2.ZERO
var _tiempo := 0.0
var _caminando := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	rng.randomize()


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if movimiento == null:
		avisos.append("Asigna el ComponenteMovimiento en `movimiento` (es quien mueve el cuerpo).")
	return avisos


## Empieza (o vuelve a empezar) el paseo parado en su sitio. Sin `espera_inicial` espera lo
## normal y elige destino; con ella (mínimo, máximo) espera ese tiempo y, como si hubiera
## llegado, elige destino al acabar (así arranca la seta).
func activar(espera_inicial := Vector2.ZERO) -> void:
	if espera_inicial == Vector2.ZERO:
		_parar()
		return
	_caminando = false
	_destino = movimiento.cuerpo.global_position
	_tiempo = rng.randf_range(espera_inicial.x, espera_inicial.y)


## Un tick del paseo; lo llama el cerebro mientras pasea.
func actualizar(delta: float) -> void:
	andando = false
	if not _caminando:
		movimiento.frenar(delta)
		_tiempo -= delta
		if _tiempo <= 0.0:
			_empezar_viaje()
		return
	hacia = _destino - movimiento.cuerpo.global_position
	_tiempo -= delta
	if hacia.length() < 2.0 or _tiempo <= 0.0:
		_parar()
		return
	movimiento.mover(hacia.normalized(), delta, velocidad)
	andando = true


## El cerebro lo llama cuando choca (solo si está paseando): se para y elige otro destino.
## Con la `normal` del choque solo se para si iba CONTRA el obstáculo: un cuerpo que se queda
## tocando algo (una vasija, una pared) recibe un choque en cada tick aunque esté quieto o se
## aleje, y sin esta comprobación se paraba nada más arrancar y no volvía a andar nunca
## (visto con una seta pegada a una vasija, 2026-11-18). Sin normal, se para siempre.
func al_chocar(normal := Vector2.ZERO) -> void:
	if not _caminando:
		return
	if normal != Vector2.ZERO and normal.dot(_destino - movimiento.cuerpo.global_position) >= 0.0:
		return # se aleja del obstáculo (o lo roza): que siga
	_parar()


## Cambia el destino actual sin tocar la espera (p. ej. «vuelve a casa»).
func ir_a(punto: Vector2) -> void:
	_destino = punto


func _parar() -> void:
	_caminando = false
	_tiempo = rng.randf_range(espera.x, espera.y)
	_elegir_destino()


func _elegir_destino() -> void:
	var angulo := rng.randf() * TAU
	var distancia: float
	match reparto:
		Reparto.AREA:
			distancia = sqrt(rng.randf()) * radio
		Reparto.DISTANCIA:
			distancia = rng.randf_range(distancia_minima, radio)
	_destino = centro + Vector2.from_angle(angulo) * distancia


## Acabó la espera: empieza a andar hacia el destino (salvo viaje demasiado corto).
func _empezar_viaje() -> void:
	var distancia := _destino.distance_to(movimiento.cuerpo.global_position)
	if distancia < viaje_minimo:
		_elegir_destino()
		_tiempo = 0.5
		return
	# Margen por si algo lo frena: a la velocidad de paseo, `margen_tiempo` veces lo necesario.
	_tiempo = (distancia / maxf(velocidad, 1.0) * margen_tiempo + 0.5) if margen_tiempo > 0.0 else INF
	_caminando = true

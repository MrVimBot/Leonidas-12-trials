class_name LuzAntorcha
extends PointLight2D
## Luz de una antorcha (los aros dorados del laberinto del Minotauro): parpadea un poco, como
## una llama, y se puede apagar y encender poco a poco (`fijar_intensidad`). La textura (círculo
## con degradado) y el color se ponen en la escena; la energía base es `energia`.
## Necesita que la zona esté a oscuras (un CanvasModulate): si no, apenas se nota.

## Energía con la llama "entera".
@export var energia := 1.0
## Cuánto varía la energía al parpadear (fracción de `energia`).
@export_range(0.0, 1.0) var parpadeo := 0.15
## Rapidez del parpadeo.
@export var rapidez := 6.0

## 0 = apagada, 1 = encendida del todo (la cambia `fijar_intensidad`).
var intensidad := 1.0

var _tiempo := 0.0
var _semilla := 0.0
var _tween: Tween


func _ready() -> void:
	_semilla = randf() * 100.0
	energy = energia


func _process(delta: float) -> void:
	_tiempo += delta * rapidez
	# Dos senos desfasados: un temblor irregular sin ruido que generar.
	var temblor := sin(_tiempo + _semilla) * 0.6 + sin(_tiempo * 2.3 + _semilla * 1.7) * 0.4
	energy = energia * intensidad * (1.0 + temblor * parpadeo)
	visible = intensidad > 0.001


## Lleva la luz a `valor` (0–1) en `duracion` s.
func fijar_intensidad(valor: float, duracion := 0.0) -> void:
	if _tween:
		_tween.kill()
	if duracion <= 0.0:
		intensidad = valor
		return
	_tween = create_tween()
	_tween.tween_property(self, ^"intensidad", valor, duracion)

class_name FilaCorazones
extends HBoxContainer
## Fila de corazones de una vida en CUARTOS (4 por corazón). La usan los corazones del HUD
## (Leonidas o el barco) y la barra de la jefa (`BarraJefe`).
## `textura` tiene 5 estados de `ancho_celda` px, de izquierda a derecha: lleno, 3/4, 1/2,
## 1/4 y vacío (assets/ui/corazones.png).
## Los corazones se crean aquí (y no en la escena) porque su número depende de `vida_max`:
## un jefe da un corazón extra a Leonidas.
## Cada corazón usa el material del padre (`use_parent_material`): poniendo un material en
## la fila (p. ej. el de desaturar) cambian todos a la vez.

const CUARTOS_POR_CORAZON := ComponenteVida.CUARTOS_POR_CORAZON

@export var textura: Texture2D = preload("res://assets/ui/corazones.png")
@export var ancho_celda := 12

var _estados: Array[AtlasTexture] = []


func _ready() -> void:
	# Una textura por estado: índice = cuartos llenos (0 = vacío ... 4 = lleno).
	for cuartos in range(CUARTOS_POR_CORAZON + 1):
		var a := AtlasTexture.new()
		a.atlas = textura
		a.region = Rect2((CUARTOS_POR_CORAZON - cuartos) * ancho_celda, 0, ancho_celda, ancho_celda)
		_estados.append(a)


## Dibuja `ceil(vida_max / 4)` corazones con `vida` cuartos llenos.
func mostrar(vida: int, vida_max: int) -> void:
	var total := ceili(vida_max / float(CUARTOS_POR_CORAZON))
	while get_child_count() < total:
		var t := TextureRect.new()
		t.stretch_mode = TextureRect.STRETCH_KEEP
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.use_parent_material = true
		add_child(t)
	while get_child_count() > total:
		var sobra := get_child(get_child_count() - 1)
		remove_child(sobra)
		sobra.queue_free()
	for i in total:
		var cuartos := clampi(vida - i * CUARTOS_POR_CORAZON, 0, CUARTOS_POR_CORAZON)
		(get_child(i) as TextureRect).texture = _estados[cuartos]


## Cuartos llenos que se ven en el corazón `i` (0..4), o -1 si no existe. Para las pruebas:
## lo que se dibuja, no la vida de la que sale.
func cuartos_de(i: int) -> int:
	if i < 0 or i >= get_child_count():
		return -1
	return _estados.find((get_child(i) as TextureRect).texture)


## Cuartos llenos que se ven en toda la fila.
func cuartos_visibles() -> int:
	var total := 0
	for i in get_child_count():
		total += maxi(cuartos_de(i), 0)
	return total

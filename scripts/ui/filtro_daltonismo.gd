class_name FiltroDaltonismo
extends CanvasLayer
## Filtro de daltonismo del jugador. Autoload `Daltonismo` (scenes/ui/filtro_daltonismo.tscn).
##
## Una capa por encima de todo (menús, libro, diálogos, cinemática) con un ColorRect que
## corrige los colores de la pantalla (resources/shaders/daltonismo.gdshader). Se elige en
## el menú de pausa. Con NINGUNO la capa se oculta y no cuesta nada.
##
## Es un ajuste del jugador, no de la partida: se guarda en `user://ajustes.cfg` (no en
## partida.cfg) y `EstadoJuego.reiniciar()` no lo toca.
##
## Para ver cómo ve el juego una persona daltónica (revisar el arte) se usa el plugin del
## editor Eyesee (Asset Store), no este filtro.

signal cambio(tipo: Tipo)

enum Tipo { NINGUNO, PROTANOPIA, DEUTERANOPIA }

const NOMBRES: Array[String] = ["No", "Protanopía", "Deuteranopía"]
## Variable (no const) para que las pruebas usen otro archivo, como `EstadoJuego.ruta_partida`.
var ruta_ajustes := "user://ajustes.cfg"

var tipo := Tipo.NINGUNO:
	set(valor):
		tipo = valor
		if is_node_ready():
			_aplicar()

@onready var _filtro: ColorRect = %Filtro


func _ready() -> void:
	_cargar()
	_aplicar()


## Pasa al siguiente filtro (No → Protanopía → Deuteranopía → No) y lo guarda.
func siguiente() -> void:
	tipo = ((tipo + 1) % Tipo.size()) as Tipo
	_guardar()
	cambio.emit(tipo)


func nombre() -> String:
	return NOMBRES[tipo]


func _aplicar() -> void:
	visible = tipo != Tipo.NINGUNO
	(_filtro.material as ShaderMaterial).set_shader_parameter(&"tipo", int(tipo))


func _cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ruta_ajustes) != OK:
		return
	var valor: Variant = cfg.get_value("accesibilidad", "daltonismo", 0)
	if not valor is int:
		return
	var n: int = valor
	if n >= 0 and n < Tipo.size():
		tipo = n as Tipo


func _guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.load(ruta_ajustes) # conserva otros ajustes si los hay
	cfg.set_value("accesibilidad", "daltonismo", int(tipo))
	cfg.save(ruta_ajustes)

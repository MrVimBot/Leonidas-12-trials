class_name PaginaGuardar
extends PaginaLibro
## Página Guardar del libro: tiempo jugado y jefes derrotados (junto a los rótulos pintados
## en el arte), el botón Guardar (%BotonGuardar, un TextureButton sin textura sobre el botón
## pintado) con su marca «>» parpadeante cuando el cursor está aquí, y el mensaje tras
## guardar. Guardar lo hace el coordinador: esta página solo lo pide (`pide_guardar`).

signal pide_guardar

@onready var _tiempo_label: Label = %TiempoJugado
@onready var _jefes_label: Label = %JefesDerrotados
@onready var _marca: Label = %MarcaGuardar
@onready var _mensaje: Label = %MensajeGuardar


func refrescar() -> void:
	_tiempo_label.text = EstadoJuego.tiempo_texto()
	_jefes_label.text = str(EstadoJuego.jefes_derrotados)
	_marca.visible = con_cursor


func animar(tiempo: float) -> void:
	if not con_cursor:
		return
	_tiempo_label.text = EstadoJuego.tiempo_texto()
	_marca.modulate.a = 1.0 if fmod(tiempo, 0.8) < 0.55 else 0.0


func confirmar() -> void:
	pide_guardar.emit()


## Mensaje tras guardar («¡Partida guardada!»); "" lo borra.
func avisar(t: String) -> void:
	_mensaje.text = t


## Clic en el botón Guardar (señal `pressed`, conectada en la escena).
func _on_boton_guardar_pressed() -> void:
	cursor_pedido.emit(self)
	pide_guardar.emit()

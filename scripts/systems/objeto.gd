class_name Objeto
extends Resource
## Un objeto que Leonidas puede llevar (resources/objetos/<id>.tres).
## El libro lo enseña en Inventario (CONSUMIBLE) u Objetos Importantes (IMPORTANTE);
## EstadoJuego guarda cuántos tiene de cada uno (`EstadoJuego.objetos`, id → cantidad).
## Se edita en el Inspector: el equipo de guion puede cambiar nombre y descripción.

enum Tipo { CONSUMIBLE, IMPORTANTE }

## Igual que el nombre del archivo: resources/objetos/<id>.tres.
@export var id: StringName = &""
## Nombre en el libro y en la tienda (≤ 12 letras).
@export var nombre := ""
## Qué hace, en el libro: 2 renglones de ~20 letras (se parte solo).
@export_multiline var descripcion := ""
## Icono de 16×16 (como mucho 24×24) para las casillas del libro y la tienda.
@export var icono: Texture2D
@export var tipo := Tipo.CONSUMIBLE
## Cuántos se pueden llevar a la vez.
@export_range(1, 99) var maximo := 1
## Cuartos de corazón que cura al usarlo (consumibles; 4 = 1 corazón).
@export_range(0, 40) var cura := 0

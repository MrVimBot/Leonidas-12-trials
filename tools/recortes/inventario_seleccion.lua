-- assets/sprites/inventario/seleccion_de_casilla_de_inventario.aseprite (80×80):
-- marco blanco que se pone encima de la casilla elegida (las casillas de las páginas
-- miden ~76×76; el marco las rodea).
return {
  source = "assets/sprites/inventario/seleccion_de_casilla_de_inventario.aseprite",
  out_dir = "assets/ui/inventario",
  escala = 0.4, -- el libro mide 1119×576 y la pantalla 480×270 (docs/design/plan_inventario_libro.md)
  recortes = {
    { nombre = "seleccion_casilla", x = 0, y = 0, w = 80, h = 80 },
  },
}

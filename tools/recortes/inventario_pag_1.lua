-- assets/sprites/inventario/pag_1.aseprite (1119×576). Arte del menú del libro (inventario),
-- dibujado a 1:1 (NO viene agrandado ×N), pero más grande que la pantalla:
-- se exporta reducido a ×0,4 (448×230). La cobertura (tapas) y las páginas comparten el
-- mismo lienzo: se exporta el lienzo entero para poder superponerlas en (0, 0).
-- Cómo se combinan: assets/sprites/inventario/inventario_y_como_se_debe_de_ver.aseprite.
return {
  source = "assets/sprites/inventario/pag_1.aseprite",
  out_dir = "assets/ui/inventario",
  escala = 0.4, -- el libro mide 1119×576 y la pantalla 480×270 (docs/design/plan_inventario_libro.md)
  recortes = {
    { nombre = "pag_1", x = 0, y = 0, w = 1119, h = 576 },
  },
}

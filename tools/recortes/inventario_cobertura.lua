-- assets/sprites/inventario/cobertura.aseprite (1119×576). Arte del menú del libro (inventario),
-- a su tamaño real (NO viene agrandado). La cobertura (tapas) y las páginas comparten el
-- mismo lienzo: se exporta el lienzo entero para poder superponerlas en (0, 0).
-- Cómo se combinan: assets/sprites/inventario/inventario_y_como_se_debe_de_ver.aseprite.
return {
  source = "assets/sprites/inventario/cobertura.aseprite",
  out_dir = "assets/ui/inventario",
  recortes = {
    { nombre = "cobertura", x = 0, y = 0, w = 1119, h = 576 },
  },
}

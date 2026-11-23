-- assets/sprites/inventario/objetos/cuerno.aseprite (40×40, 1 frame): icono del cuerno del
-- Minotauro (nivel 3, lo da el cofre del laberinto). Recortado a lo dibujado (34×32) y sin escala:
-- reducirlo a 16×16 como los demás iconos borraba el contorno. Lo usa resources/objetos/cuerno.tres.
return {
  source = "assets/sprites/inventario/objetos/cuerno.aseprite",
  out_dir = "assets/ui/inventario/objetos",
  recortes = {
    { nombre = "icono_cuerno", x = 3, y = 1, w = 34, h = 32 },
  },
}

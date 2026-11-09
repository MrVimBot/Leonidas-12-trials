-- Distribución de animaciones dentro de assets/sprites/leonidas_mini.aseprite
-- (100×310 px, 16 frames, sin tags; cada animación vive en una franja del lienzo).
--
-- Cada animación = columna (dirección) × fila (acción). El recorte se pega en una
-- celda de tamaño fijo alineando el punto (centro de la columna, `foot` de la fila)
-- con `cell.origin`, para que los pies queden siempre en el mismo píxel y no haya
-- saltos al cambiar de animación.
--
-- Si la artista mueve una franja, solo hay que tocar esta tabla.

return {
  source = "assets/sprites/leonidas_mini.aseprite",
  name = "leonidas_mini",
  out_dir = "assets/sprites/strips/leonidas_mini",

  cell = { w = 40, h = 40, origin = { x = 20, y = 34 } },

  -- El sprite "lado" mira hacia aquí; la otra dirección se obtiene con flip_h.
  side_faces = "izquierda",

  columns = {
    frente  = { x = 0,  w = 33 },
    lado    = { x = 33, w = 33 },
    espalda = { x = 66, w = 34 },
  },

  -- y/h: franja vertical; foot: línea de los pies (en coordenadas del lienzo).
  -- columns (opcional): sustituye las columnas por defecto en esa fila.
  -- skip (opcional): direcciones que esa fila no tiene.
  rows = {
    { name = "parado",          y = 0,   h = 28, foot = 28, loop = true,
      -- la paleta de colores de la artista está en x 24–27 de esta fila
      columns = { frente = { x = 0, w = 24 } } },
    { name = "caminar",         y = 28,  h = 28, foot = 55, loop = true },
    { name = "ataque",          y = 56,  h = 32, foot = 86, loop = false,
      columns = { frente = { x = 0, w = 32 }, lado = { x = 32, w = 35 }, espalda = { x = 67, w = 33 } } },
    { name = "pirueta",         y = 88,  h = 27, foot = 113, loop = false },
    { name = "parado_objeto",   y = 115, h = 27, foot = 141, loop = true },
    { name = "caminar_objeto",  y = 142, h = 28, foot = 169, loop = true },
    { name = "agarrar",         y = 170, h = 28, foot = 197, loop = false },
    { name = "tirar",           y = 198, h = 28, foot = 225, loop = false },
    -- PENDIENTE: capa "Layer 17" sin nombre; parece "recibir daño". Confirmar con la artista.
    { name = "fila_17",         y = 226, h = 29, foot = 255, loop = false },
    -- El barco está ordenado lado / frente / espalda (distinto del resto).
    { name = "barco_moviendo",  y = 255, h = 25, foot = 279, loop = true,
      columns = { lado = { x = 0, w = 33 }, frente = { x = 33, w = 33 }, espalda = { x = 66, w = 34 } } },
    { name = "barco_quieto",    y = 280, h = 30, foot = 306, loop = true,
      columns = { lado = { x = 0, w = 33 }, frente = { x = 33, w = 33 }, espalda = { x = 66, w = 34 } } },
  },
}

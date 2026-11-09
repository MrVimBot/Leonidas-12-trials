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

  -- offset del AnimatedSprite2D = (w/2 - origin.x, h/2 - origin.y) = (0, -14)
  cell = { w = 48, h = 40, origin = { x = 24, y = 34 } },

  -- El sprite "lado" mira hacia aquí; la otra dirección se obtiene con flip_h.
  side_faces = "izquierda",

  columns = {
    frente  = { x = 0,  w = 33 },
    lado    = { x = 33, w = 33 },
    espalda = { x = 66, w = 34 },
  },

  -- y/h: franja vertical; foot: línea de los pies (en coordenadas del lienzo).
  -- columns (opcional): sustituye las columnas por defecto en esa fila. Cada columna
  --   admite name (nombre completo de la animación), ax (x del ancla en el lienzo), loop
  --   y cut_left / cut_right = {a, b} (ver export_strips.lua).
  -- fps (opcional): fuerza la velocidad de la fila (si no, la duración de Aseprite).
  -- skip (opcional): direcciones que esa fila no tiene.
  rows = {
    { name = "parado",          y = 0,   h = 28, foot = 28, loop = true,
      -- la paleta de colores de la artista está en x 24–27 de esta fila
      columns = { frente = { x = 0, w = 24 } } },
    { name = "caminar",         y = 28,  h = 28, foot = 55, loop = true },
    { name = "ataque",          y = 56,  h = 32, foot = 86, loop = false, fps = 20,
      columns = { frente = { x = 0, w = 32 }, lado = { x = 32, w = 35 }, espalda = { x = 67, w = 33 } } },
    { name = "pirueta",         y = 88,  h = 27, foot = 113, loop = false, fps = 20 },
    { name = "parado_objeto",   y = 115, h = 27, foot = 141, loop = true },
    { name = "caminar_objeto",  y = 142, h = 28, foot = 169, loop = true },
    { name = "agarrar",         y = 170, h = 28, foot = 197, loop = false, fps = 20 },
    { name = "tirar",           y = 198, h = 28, foot = 225, loop = false, fps = 20 },
    -- Capa "Layer 17": NO son direcciones, son 3 animaciones de frente.
    -- Se solapan en x según el frame (la cola de "morir" llega a x 29 en los frames 5–7,
    -- y "recibir_dano" llega a x 28 en los 0–4): cut_* busca el hueco en cada frame.
    { name = "fila_17",         y = 226, h = 29, foot = 255, loop = false, fps = 16,
      columns = {
        frente  = { name = "recibir_dano", x = 0,  w = 36, ax = 16, cut_right = { 26, 36 } },
        lado    = { name = "morir",        x = 26, w = 40, ax = 49, cut_left = { 26, 36 } },
        -- PENDIENTE con la artista: pose de frente con el brazo en alto (¿recibir objeto?)
        espalda = { name = "sin_nombre",   x = 66, w = 34, loop = true },
      } },
    -- El barco está ordenado lado / frente / espalda (distinto del resto).
    { name = "barco_moviendo",  y = 255, h = 25, foot = 279, loop = true,
      columns = { lado = { x = 0, w = 33 }, frente = { x = 33, w = 33 }, espalda = { x = 66, w = 34 } } },
    { name = "barco_quieto",    y = 280, h = 30, foot = 306, loop = true,
      columns = { lado = { x = 0, w = 33 }, frente = { x = 33, w = 33 }, espalda = { x = 66, w = 34 } } },
  },
}

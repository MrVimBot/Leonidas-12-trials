-- assets/sprites/flor_falsa.aseprite (85×150 px, 8 frames de 100 ms, sin tags).
-- Cada animación es una CAPA; las capas se solapan en el lienzo, por eso cada fila
-- lleva `layer`. Sin direcciones: la flor mira (muerde) hacia la IZQUIERDA y el
-- cerebro la espeja con flip_h. `ax`/`foot` = base del tallo (donde está plantada).
-- offset del AnimatedSprite2D = (w/2 - origin.x, h/2 - origin.y) = (0, -20)

return {
  source = "assets/sprites/flor_falsa.aseprite",
  name = "flor_falsa",
  out_dir = "assets/sprites/strips/flor_falsa",
  cell = { w = 64, h = 48, origin = { x = 32, y = 44 } },
  side_faces = "izquierda",

  columns = { frente = { x = 0, w = 85 } },

  rows = {
    -- "totalmente quieto" tiene dos dibujos: la flor camuflada en el suelo (x 8–27)
    -- y la flor fuera, en reposo (x 28–53; su hoja llega a x 29).
    { name = "escondida", layer = "totalmente quieto", y = 0, h = 40, foot = 32, loop = true,
      columns = { frente = { name = "escondida", x = 0, w = 28, ax = 19 } } },
    { name = "quieta", layer = "totalmente quieto", y = 0, h = 40, foot = 35, loop = true,
      columns = { frente = { name = "quieta", x = 28, w = 32, ax = 41 } } },
    { name = "morder", layer = "ataque", y = 30, h = 40, foot = 66, loop = false,
      columns = { frente = { name = "morder", x = 36, w = 49, ax = 60 } } },
    { name = "morder_exito", layer = "ataque exitoso del enemigo", y = 30, h = 40, foot = 66, loop = false,
      columns = { frente = { name = "morder_exito", x = 0, w = 36, ax = 19 } } },
    { name = "recibir_dano", layer = "recibe daño", y = 70, h = 40, foot = 107, loop = false,
      columns = { frente = { name = "recibir_dano", x = 0, w = 50, ax = 19 } } },
    { name = "salir", layer = "se activa el enemigo", y = 70, h = 45, foot = 110, loop = false,
      columns = { frente = { name = "salir", x = 50, w = 35, ax = 67 } } },
    -- el frame 7 está vacío
    { name = "esconderse", layer = "se desactiva el enemigo", y = 104, h = 42, foot = 143, loop = false, frames = 7,
      columns = { frente = { name = "esconderse", x = 30, w = 34, ax = 47 } } },
  },
}

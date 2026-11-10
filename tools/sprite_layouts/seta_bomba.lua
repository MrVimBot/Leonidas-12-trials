-- assets/sprites/seta_bomba.aseprite (75×170 px, 8 frames de 100 ms, sin tags).
-- Cada animación es una CAPA con su nombre; dentro de cada capa, la mitad izquierda
-- del lienzo es "frente" y la derecha "espalda". No hay vista lateral: el
-- AnimadorDireccional usa la de frente cuando la seta camina de lado.
--
-- `ax` = centro de la seta en el lienzo (borde izquierdo del sombrero en el frame 0
-- + 11, porque el sombrero en reposo mide 22 px); `foot` = fila más baja de los pies.
-- offset del AnimatedSprite2D = (w/2 - origin.x, h/2 - origin.y) = (0, -16)

return {
  source = "assets/sprites/seta_bomba.aseprite",
  name = "seta_bomba",
  out_dir = "assets/sprites/strips/seta_bomba",
  cell = { w = 40, h = 40, origin = { x = 20, y = 36 } },
  side_faces = "izquierda",

  columns = {
    frente  = { x = 0,  w = 37 },
    espalda = { x = 37, w = 38 },
  },

  rows = {
    { name = "parado",     layer = "parado",            y = 0,   h = 24, foot = 20, loop = true,
      columns = { frente = { x = 0, w = 37, ax = 21 }, espalda = { x = 37, w = 38, ax = 55 } } },
    { name = "caminar",    y = 24,  h = 25, foot = 46, loop = true,
      columns = { frente  = { layer = "caminar frente",  x = 0,  w = 37, ax = 22 },
                  espalda = { layer = "caminar espalda", x = 37, w = 38, ax = 55 } } },
    { name = "explotar",   y = 52,  h = 38, foot = 87, loop = false,
      columns = { frente  = { layer = "explotar de frente",  x = 0,  w = 37, ax = 20 },
                  espalda = { layer = "explotar de espalda", x = 37, w = 38, ax = 58 } } },
    { name = "esconderse", y = 92,  h = 24, foot = 112, loop = true,
      columns = { frente  = { layer = "esconderse tras explosion", x = 0,  w = 37, ax = 19 },
                  espalda = { layer = "esconderse atras",          x = 37, w = 38, ax = 58 } } },
    -- En el frame 5 de "salir adelante" hay una raya suelta hasta x 68: el corte
    -- de la columna (w = 37) la deja fuera.
    { name = "salir",      y = 117, h = 24, foot = 137, loop = false,
      columns = { frente  = { layer = "salir adelante", x = 0,  w = 37, ax = 19 },
                  espalda = { layer = "salir detras",   x = 37, w = 38, ax = 58 } } },
    -- La nube de la explosión (efecto aparte, sin dirección).
    { name = "nube", layer = "nube de toxinas", y = 142, h = 28, foot = 166, loop = true, skip = { espalda = true },
      columns = { frente = { name = "nube", x = 0, w = 37, ax = 20 } } },
  },
}

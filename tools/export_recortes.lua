-- Exporta recortes rectangulares de un .aseprite a PNG sueltos, según una tabla
-- (tools/recortes/*.lua). Pensado para hojas con muchos objetos sueltos, como
-- todos_los_assets.aseprite.
--
-- Uso (desde la raíz del repo, sobre una COPIA del .aseprite):
--   aseprite -b copia.aseprite \
--     --script-param config=tools/recortes/todos_los_assets.lua \
--     --script-param root=$(pwd) \
--     --script tools/export_recortes.lua
--
-- Opciones de cada recorte: `aislar = true` (solo la mancha más grande) y
-- `escala = 0.4` (reduce por un factor no entero; también vale para toda la tabla).
--
-- Normalmente se llama desde tools/export_sprites.sh. Nunca guarda el sprite.

local spr = app.activeSprite
if not spr then error("No hay sprite abierto. Pasa el .aseprite antes de --script.") end

local root = app.params.root or "."
local C = dofile(app.params.config or error("Falta --script-param config=..."))

-- Aplanar el primer frame (solo capas visibles).
local lienzo = Image(spr.width, spr.height, ColorMode.RGB)
lienzo:drawSprite(spr, 1)

local function opaco(img, x, y)
  return app.pixelColor.rgbaA(img:getPixel(x, y)) > 0
end

-- Deja solo la mancha conexa (8 vecinos) más grande de la imagen.
local function aislar_mayor(img)
  local W, H = img.width, img.height
  local etiqueta, mejor, mejor_n, id = {}, 0, 0, 0
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local k = y * W + x
      if not etiqueta[k] and opaco(img, x, y) then
        id = id + 1
        local n, pila = 0, { x, y }
        etiqueta[k] = id
        while #pila > 0 do
          local cy = table.remove(pila); local cx = table.remove(pila)
          n = n + 1
          for dy = -1, 1 do
            for dx = -1, 1 do
              local nx, ny = cx + dx, cy + dy
              if nx >= 0 and ny >= 0 and nx < W and ny < H then
                local nk = ny * W + nx
                if not etiqueta[nk] and opaco(img, nx, ny) then
                  etiqueta[nk] = id
                  pila[#pila + 1] = nx; pila[#pila + 1] = ny
                end
              end
            end
          end
        end
        if n > mejor_n then mejor, mejor_n = id, n end
      end
    end
  end
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local e = etiqueta[y * W + x]
      if e and e ~= mejor then img:drawPixel(x, y, 0) end
    end
  end
end

-- Reduce (o amplía) la imagen por un factor NO entero promediando el área que cubre
-- cada píxel de salida (pesos por solape, color premultiplicado por alfa). El alfa
-- sale binario (opaco si la cobertura es >= 50 %): sin bordes semitransparentes.
-- Si el original tiene pocos colores (<= 256: iconos, marcos), cada píxel se ajusta
-- al color más parecido del original para no inventar tonos intermedios.
-- Para arte que NO viene agrandado y no cabe en pantalla (el libro del inventario);
-- si viene agrandado ×N exacto, usar tools/reducir_png.lua.
local function escalar(img, s)
  local pc = app.pixelColor
  local W, H = img.width, img.height
  local w, h = math.floor(W * s + 0.5), math.floor(H * s + 0.5)
  local paleta, n_paleta = {}, 0
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local c = img:getPixel(x, y)
      if pc.rgbaA(c) == 255 and not paleta[c] then
        paleta[c] = true; n_paleta = n_paleta + 1
      end
    end
    if n_paleta > 256 then break end
  end
  local lista = nil
  if n_paleta <= 256 then
    lista = {}
    for c in pairs(paleta) do lista[#lista + 1] = { pc.rgbaR(c), pc.rgbaG(c), pc.rgbaB(c) } end
  end
  local out = Image(w, h, ColorMode.RGB)
  local paso = 1 / s
  for oy = 0, h - 1 do
    local y0, y1 = oy * paso, math.min((oy + 1) * paso, H)
    for ox = 0, w - 1 do
      local x0, x1 = ox * paso, math.min((ox + 1) * paso, W)
      local r, g, b, a, area = 0, 0, 0, 0, 0
      for sy = math.floor(y0), math.ceil(y1) - 1 do
        local py = math.min(sy + 1, y1) - math.max(sy, y0)
        for sx = math.floor(x0), math.ceil(x1) - 1 do
          local p = py * (math.min(sx + 1, x1) - math.max(sx, x0))
          local c = img:getPixel(sx, sy)
          local ca = pc.rgbaA(c) / 255 * p
          r = r + pc.rgbaR(c) * ca; g = g + pc.rgbaG(c) * ca; b = b + pc.rgbaB(c) * ca
          a = a + ca; area = area + p
        end
      end
      if area > 0 and a / area >= 0.5 then
        r, g, b = r / a, g / a, b / a
        if lista then
          local mejor, dmin = nil, math.huge
          for _, q in ipairs(lista) do
            local d = (q[1] - r) ^ 2 + (q[2] - g) ^ 2 + (q[3] - b) ^ 2
            if d < dmin then mejor, dmin = q, d end
          end
          r, g, b = mejor[1], mejor[2], mejor[3]
        end
        out:drawPixel(ox, oy, pc.rgba(math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5), 255))
      end
    end
  end
  return out
end

local total = 0
for _, r in ipairs(C.recortes) do
  local dir = root .. "/" .. (r.dir or C.out_dir)
  app.fs.makeAllDirectories(dir)
  local img = Image(r.w, r.h, ColorMode.RGB)
  img:drawImage(lienzo, Point(-r.x, -r.y))
  if r.aislar then aislar_mayor(img) end
  local escala = r.escala or C.escala
  if escala and escala ~= 1 then img = escalar(img, escala) end
  img:saveAs(dir .. "/" .. r.nombre .. ".png")
  total = total + 1
end
-- Atlas opcional: tiles sueltos de la hoja empaquetados en una rejilla
-- (tamano × tamano, `separacion` px entre tiles; una fila del atlas por grupo).
if C.atlas then
  local A = C.atlas
  local t, sep = A.tamano, A.separacion or 0
  local cols = 0
  for _, fila in ipairs(A.filas) do cols = math.max(cols, #fila) end
  local W = cols * t + (cols - 1) * sep
  local H = #A.filas * t + (#A.filas - 1) * sep
  local img = Image(W, H, ColorMode.RGB)
  for r, fila in ipairs(A.filas) do
    for c, p in ipairs(fila) do
      local tile = Image(t, t, ColorMode.RGB)
      tile:drawImage(lienzo, Point(-p[1], -p[2]))
      -- parche = {x, y, rx, ry, w, h}: tapa el rectángulo (rx, ry, w, h) del tile con el
      -- mismo trozo del tile de la hoja en (x, y). Sirve para fabricar un relleno a partir
      -- de una esquina interior (tapando su pico de hierba con otra esquina limpia).
      if p.parche then
        local q = p.parche
        local trozo = Image(q[5], q[6], ColorMode.RGB)
        trozo:drawImage(lienzo, Point(-(q[1] + q[3]), -(q[2] + q[4])))
        tile:drawImage(trozo, Point(q[3], q[4]))
      end
      img:drawImage(tile, Point((c - 1) * (t + sep), (r - 1) * (t + sep)))
      total = total + 1
    end
  end
  local dir = root .. "/" .. (A.dir or C.out_dir)
  app.fs.makeAllDirectories(dir)
  img:saveAs(dir .. "/" .. A.nombre .. ".png")
end
print(string.format("[export_recortes] %d recortes de %s", total, C.source))

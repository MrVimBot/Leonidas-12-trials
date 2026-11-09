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

local total = 0
for _, r in ipairs(C.recortes) do
  local dir = root .. "/" .. (r.dir or C.out_dir)
  app.fs.makeAllDirectories(dir)
  local img = Image(r.w, r.h, ColorMode.RGB)
  img:drawImage(lienzo, Point(-r.x, -r.y))
  if r.aislar then aislar_mayor(img) end
  img:saveAs(dir .. "/" .. r.nombre .. ".png")
  total = total + 1
end
print(string.format("[export_recortes] %d recortes de %s", total, C.source))

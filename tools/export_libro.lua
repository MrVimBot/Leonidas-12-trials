-- Exporta las piezas del libro (menú de inventario) desde la maqueta por capas de la
-- artista, SIN reescalar: assets/sprites/inventario/inventario_y_como_se_debe_de_ver.aseprite
-- (559×300, entregada el 2026-11-14). El juego la muestra a escala entera de pantalla
-- (×3 en 1920×1080): ver scripts/ui/menu_libro.gd y docs/design/plan_inventario_libro.md.
--
--   aseprite -b copia.aseprite --script-param root=<repo> --script tools/export_libro.lua
--   (lo llama tools/export_sprites.sh)
--
-- Salida en assets/ui/libro/:
--   cobertura.png, pag_1.png, pag_2y3.png, pag_4y5.png   lienzo completo 559×300
--   pestana_<pagina>.png / pestana_<pagina>_apagada.png  31×28 (la apagada lleva la sombra
--                                                        negra al 67 % de la artista)
--   salir.png, salir_apagada.png, seleccion.png
--   libro.json   posiciones (en px del lienzo) de pestañas, X, marco de selección y de cada
--                casilla (detectadas en las capas "CASILLAS PARA HERRAMIENTAS": interiores
--                oscuros), para que el menú no dependa de medidas a mano.
-- Si la artista cambia nombres de capas, tocar la tabla PIEZAS / PESTANAS de abajo.

local root = app.params["root"] or "."
local out = root .. "/assets/ui/libro"
local spr = app.activeSprite
assert(spr, "export_libro: no hay sprite abierto")

local BASE = "icono activado" -- grupo que tiene todas las piezas
local W, H = spr.width, spr.height

-- --- Utilidades -----------------------------------------------------------------------

local function buscar(ruta)
  local capas = spr.layers
  local capa = nil
  for parte in string.gmatch(ruta, "[^/]+") do
    capa = nil
    for _, l in ipairs(capas) do
      if l.name == parte then capa = l break end
    end
    assert(capa, "export_libro: no existe la capa " .. ruta)
    if capa.isGroup then capas = capa.layers end
  end
  return capa
end

local function todas(capas, lista)
  lista = lista or {}
  for _, l in ipairs(capas) do
    table.insert(lista, l)
    if l.isGroup then todas(l.layers, lista) end
  end
  return lista
end

-- Dibuja el sprite con solo esas capas visibles (y sus grupos).
local function render(rutas)
  for _, l in ipairs(todas(spr.layers)) do l.isVisible = false end
  for _, r in ipairs(rutas) do
    local l = buscar(BASE .. "/" .. r)
    while l and l ~= spr do
      l.isVisible = true
      l = l.parent
    end
  end
  local img = Image(spr.spec)
  img:clear()
  img:drawSprite(spr, 1)
  return img
end

local function recortar(img, r)
  local c = Image(r.width, r.height, img.colorMode)
  c:clear()
  c:drawImage(img, Point(-r.x, -r.y))
  return c
end

local function rect_capa(ruta, base)
  local c = buscar((base or BASE) .. "/" .. ruta):cel(1)
  return Rectangle(c.position.x, c.position.y, c.image.width, c.image.height)
end

-- Interiores oscuros (casillas) de una capa, en coordenadas del lienzo.
local function casillas(ruta)
  local cel = buscar(BASE .. "/" .. ruta):cel(1)
  local img = cel.image
  local w, h = img.width, img.height
  local visto = {}
  local res = {}
  local function oscuro(x, y)
    local p = img:getPixel(x, y)
    local a = app.pixelColor.rgbaA(p)
    local s = app.pixelColor.rgbaR(p) + app.pixelColor.rgbaG(p) + app.pixelColor.rgbaB(p)
    return a > 0 and s < 90
  end
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local k = y * w + x
      if not visto[k] and oscuro(x, y) then
        local x0, y0, x1, y1 = x, y, x, y
        local pila = { { x, y } }
        visto[k] = true
        while #pila > 0 do
          local p = table.remove(pila)
          local px, py = p[1], p[2]
          if px < x0 then x0 = px end
          if py < y0 then y0 = py end
          if px > x1 then x1 = px end
          if py > y1 then y1 = py end
          for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local nx, ny = px + d[1], py + d[2]
            local nk = ny * w + nx
            if nx >= 0 and ny >= 0 and nx < w and ny < h and not visto[nk] and oscuro(nx, ny) then
              visto[nk] = true
              table.insert(pila, { nx, ny })
            end
          end
        end
        if x1 - x0 >= 15 and y1 - y0 >= 15 then
          table.insert(res, { x0 + cel.position.x, y0 + cel.position.y, x1 - x0 + 1, y1 - y0 + 1 })
        end
      end
    end
  end
  -- Orden de lectura: por filas (y) y luego columnas (x).
  table.sort(res, function(a, b)
    if math.abs(a[2] - b[2]) > 4 then return a[2] < b[2] end
    return a[1] < b[1]
  end)
  return res
end

-- --- Qué se exporta -------------------------------------------------------------------

local PIEZAS = {
  cobertura = { "COBERTURA" },
  pag_1 = { "pag1/paginas de relleno para pagina 1", "pag1/1era pagina", "pag1/Layer 1",
            "pag1/CASILLAS PARA HERRAMIENTAS" },
  pag_2y3 = { "pag 2 y 3/paginas de relleno para 2 y 3", "pag 2 y 3/2da y 3er pagina",
              "pag 2 y 3/Layer 4", "pag 2 y 3/MANCHAS", "pag 2 y 3/MAPA para pagina 5",
              "pag 2 y 3/CASILLAS PARA HERRAMIENTAS" },
  pag_4y5 = { "pag 4 y 5/paginas de relleno para 4 y 5", "pag 4 y 5/4ta y 5ta pagina",
              "pag 4 y 5/CUADROS DE MISIONES pagina 6", "pag 4 y 5/Layer 7" },
}

-- Pestañas en el orden de las páginas del menú: { nombre, capa del icono, capa apagada }.
local G = "simbolos arriba/"
local PESTANAS = {
  { "importantes", G .. "Group 5/ICONOS HERRAMIENTA}", G .. "Group 5/ICONOS HERRAMIENTA APAGADO" },
  { "inventario", G .. "Group 6/ÍCONOS OBJETOS", G .. "Group 6/ÍCONOS OBJETOS APAGADO" },
  { "mapa", G .. "Group 8/ÍCONO MAPA", G .. "Group 8/ÍCONO MAPA APAGADO" },
  { "misiones", G .. "Group 7/ÍCONO MALDICIONES", G .. "Group 7/ÍCONO MALDICIONES APAGADO" },
  { "guardar", G .. "Group 9/ÍCONO MISIONES", G .. "Group 9/ÍCONO MISIONES APAGADO" },
}
local SALIR = { G .. "Group 10/ÍCONO MISIONES", G .. "Group 10/ÍCONO MISIONES APAGADO" }
local SELECCION = "pag1/Layer 3"

-- --- Exportar -------------------------------------------------------------------------

app.fs.makeAllDirectories(out)
local json = { lienzo = { W, H }, pestanas = {}, casillas = {} }

for nombre, capas in pairs(PIEZAS) do
  render(capas):saveAs(out .. "/" .. nombre .. ".png")
end

-- En "icono activado" la 1.ª pestaña está encendida (subida); la altura normal se toma del
-- grupo "iconos desactivados", donde están todas abajo.
local y_apagada = rect_capa(PESTANAS[1][2], "iconos desactivados").y
local y_encendida = rect_capa(PESTANAS[1][2]).y
json.pestana_y = { y_apagada, y_encendida }
for _, p in ipairs(PESTANAS) do
  local r = rect_capa(p[2])
  recortar(render({ p[2] }), r):saveAs(out .. "/pestana_" .. p[1] .. ".png")
  recortar(render({ p[2], p[3] }), r):saveAs(out .. "/pestana_" .. p[1] .. "_apagada.png")
  table.insert(json.pestanas, { p[1], r.x, r.width, r.height })
end

local rs = rect_capa(SALIR[1])
recortar(render({ SALIR[1] }), rs):saveAs(out .. "/salir.png")
recortar(render({ SALIR[1], SALIR[2] }), rs):saveAs(out .. "/salir_apagada.png")
json.salir = { rs.x, rs.y, rs.width, rs.height }

local rsel = rect_capa(SELECCION)
recortar(render({ SELECCION }), rsel):saveAs(out .. "/seleccion.png")
json.casillas.importantes = casillas("pag1/CASILLAS PARA HERRAMIENTAS")
-- El marco está dibujado sobre la 1.ª casilla de Objetos Importantes: su desplazamiento
-- respecto a esa casilla vale para todas.
local c1 = json.casillas.importantes[1]
json.seleccion = { rsel.width, rsel.height, rsel.x - c1[1], rsel.y - c1[2] }
json.casillas.inventario = casillas("pag 2 y 3/CASILLAS PARA HERRAMIENTAS")

-- JSON a mano (la API de Lua de Aseprite no trae serializador).
local function enc(v)
  if type(v) == "table" then
    if #v > 0 or next(v) == nil then
      local t = {}
      for _, x in ipairs(v) do table.insert(t, enc(x)) end
      return "[" .. table.concat(t, ", ") .. "]"
    end
    local claves = {}
    for k in pairs(v) do table.insert(claves, k) end
    table.sort(claves)
    local t = {}
    for _, k in ipairs(claves) do table.insert(t, string.format("%q: %s", k, enc(v[k]))) end
    return "{\n  " .. table.concat(t, ",\n  ") .. "\n}"
  elseif type(v) == "string" then
    return string.format("%q", v)
  end
  return tostring(v)
end
local f = io.open(out .. "/libro.json", "w")
f:write(enc(json) .. "\n")
f:close()
print(string.format("[libro] %d casillas importantes, %d de inventario -> %s",
  #json.casillas.importantes, #json.casillas.inventario, out))

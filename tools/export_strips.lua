-- Exporta tiras PNG (+ JSON) de un .aseprite cuyas animaciones están apiladas
-- en franjas del lienzo, según una tabla de distribución (tools/sprite_layouts/*.lua).
--
-- Uso (desde la raíz del repo, sobre una COPIA del .aseprite):
--   aseprite -b copia.aseprite \
--     --script-param layout=tools/sprite_layouts/leonidas_mini.lua \
--     --script-param root=$(pwd) \
--     --script tools/export_strips.lua
--
-- Normalmente se llama desde tools/export_sprites.sh.
-- El script solo lee el sprite: nunca lo guarda.

local spr = app.activeSprite
if not spr then error("No hay sprite abierto. Pasa el .aseprite antes de --script.") end

local root = app.params.root or "."
local layout_path = app.params.layout or error("Falta --script-param layout=...")
local L = dofile(layout_path)

local out_dir = root .. "/" .. L.out_dir
app.fs.makeAllDirectories(out_dir)

local cell_w, cell_h = L.cell.w, L.cell.h
local ox, oy = L.cell.origin.x, L.cell.origin.y
local nframes = #spr.frames

-- 1) Aplanar cada frame una sola vez (solo capas visibles).
local function flatten()
  local out = {}
  for i = 1, nframes do
    local img = Image(spr.width, spr.height, ColorMode.RGB)
    img:drawSprite(spr, i)
    out[i] = img
  end
  return out
end
local flat = flatten()

-- Columnas con `layers = {"capa", ...}`: se aplana solo con esas capas visibles.
-- Sirve cuando dos animaciones vecinas se tocan en el lienzo pero están en capas
-- distintas (p. ej. la cola del zorro). Se cachea por combinación de capas.
local flat_by_layers = {}
local function flat_for(layers)
  if not layers then return flat end
  local key = table.concat(layers, "|")
  if flat_by_layers[key] then return flat_by_layers[key] end
  local wanted, found = {}, {}
  for _, n in ipairs(layers) do wanted[n] = true end
  local saved = {}
  for _, layer in ipairs(spr.layers) do
    saved[layer] = layer.isVisible
    layer.isVisible = wanted[layer.name] == true
    if wanted[layer.name] then found[layer.name] = true end
  end
  for _, n in ipairs(layers) do
    if not found[n] then error("No existe la capa '" .. n .. "' en " .. L.source) end
  end
  local out = flatten()
  for layer, v in pairs(saved) do layer.isVisible = v end
  flat_by_layers[key] = out
  return out
end

-- Frames con UNA sola capa (filas/columnas con `layer = "nombre"`), para sprites
-- cuyas animaciones están en capas que se solapan en el lienzo (seta_bomba, flor_falsa).
local function find_layer(layers, name)
  for _, l in ipairs(layers) do
    if l.name == name then return l end
    if l.isGroup then
      local r = find_layer(l.layers, name)
      if r then return r end
    end
  end
end
local by_layer = {}
local function layer_frames(name)
  if by_layer[name] then return by_layer[name] end
  local layer = find_layer(spr.layers, name) or error("No existe la capa '" .. name .. "'")
  local imgs = {}
  for i = 1, nframes do
    local img = Image(spr.width, spr.height, ColorMode.RGB)
    local cel = layer:cel(i)
    if cel then img:drawImage(cel.image, cel.position) end
    imgs[i] = img
  end
  by_layer[name] = imgs
  return imgs
end

-- ¿La imagen tiene algún píxel no transparente?
local function is_empty(img)
  for it in img:pixels() do
    if app.pixelColor.rgbaA(it()) > 0 then return false end
  end
  return true
end

-- Recorta `rect` del frame y lo pega en una celda con el ancla alineada.
-- Devuelve la celda y cuántos píxeles quedaron fuera de ella.
-- ¿La columna x (coordenadas de la región) está vacía?
local function column_empty(img, x)
  for y = 0, img.height - 1 do
    if app.pixelColor.rgbaA(img:getPixel(x, y)) > 0 then return false end
  end
  return true
end

local function erase_columns(img, x1, x2)
  for x = math.max(0, x1), math.min(img.width - 1, x2) do
    for y = 0, img.height - 1 do img:drawPixel(x, y, 0) end
  end
end

-- Cortes por frame para animaciones que se solapan en x en frames distintos.
-- (Alternativa: `layers` o `layer` en la columna o la fila, ver flat_for y layer_frames.)
-- col.cut_right = {a, b}: busca la PRIMERA columna vacía en [a, b] (lienzo) y borra a su derecha.
-- col.cut_left  = {a, b}: busca la ÚLTIMA columna vacía en [a, b] y borra a su izquierda.
local function apply_cuts(region, rect, col)
  if col.cut_right then
    for x = col.cut_right[1], col.cut_right[2] do
      if column_empty(region, x - rect.x) then erase_columns(region, x - rect.x, region.width - 1); break end
    end
  end
  if col.cut_left then
    for x = col.cut_left[2], col.cut_left[1], -1 do
      if column_empty(region, x - rect.x) then erase_columns(region, 0, x - rect.x); break end
    end
  end
end

local function make_cell(frame_img, rect, foot, col)
  local ax = col.ax
  local region = Image(rect.w, rect.h, ColorMode.RGB)
  region:drawImage(frame_img, Point(-rect.x, -rect.y))
  apply_cuts(region, rect, col)
  -- ancla horizontal: `ax` (absoluta en el lienzo) o el centro de la columna
  local anchor_x = ax and (ax - rect.x) or math.floor(rect.w / 2)
  local anchor_y = foot - rect.y                -- pies, relativo a la región
  local dx, dy = ox - anchor_x, oy - anchor_y
  local cell = Image(cell_w, cell_h, ColorMode.RGB)
  cell:drawImage(region, Point(dx, dy))
  -- detectar recorte: píxeles opacos de la región que caen fuera de la celda
  local clipped = 0
  for it in region:pixels() do
    if app.pixelColor.rgbaA(it()) > 0 then
      local cx, cy = it.x + dx, it.y + dy
      if cx < 0 or cy < 0 or cx >= cell_w or cy >= cell_h then clipped = clipped + 1 end
    end
  end
  return cell, clipped
end

-- JSON mínimo (sin depender de la versión de la API).
local function esc(s) return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"' end
local function to_json(v, ind)
  ind = ind or ""
  local t = type(v)
  if t == "table" then
    local n = #v
    local inner = ind .. "  "
    local parts = {}
    if n > 0 or next(v) == nil then
      for _, x in ipairs(v) do parts[#parts + 1] = to_json(x, inner) end
      return "[" .. table.concat(parts, ", ") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do parts[#parts + 1] = inner .. esc(k) .. ": " .. to_json(v[k], inner) end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. ind .. "}"
  elseif t == "string" then return esc(v)
  elseif t == "boolean" then return v and "true" or "false"
  else return tostring(v) end
end

local manifest = {
  name = L.name,
  source = L.source,
  cell = { w = cell_w, h = cell_h },
  origin = { x = ox, y = oy },
  side_faces = L.side_faces or "izquierda",
  animations = {},
}
local warnings = {}
local dir_order = { "frente", "lado", "espalda" }

for _, row in ipairs(L.rows) do
  for _, dir in ipairs(dir_order) do
    local col = (row.columns and row.columns[dir]) or L.columns[dir]
    local skip = row.skip and row.skip[dir]
    if col and not skip then
      local anim = col.name or (row.name .. "_" .. dir)
      local rect = { x = col.x, y = row.y, w = col.w, h = row.h }
      local cells, durations, dup_of, empty = {}, {}, {}, {}
      local clipped_total = 0
      -- De dónde salen los frames (de más a menos específico):
      --   `layers = {"a", "b"}`: solo esas capas visibles (npc_zorro);
      --   `layer = "nombre"`: una sola capa, también dentro de grupos (seta_bomba, flor_falsa);
      --   nada: el sprite aplanado con todas las capas visibles.
      local layers = col.layers or row.layers
      local layer_name = col.layer or row.layer
      local source
      if layers then source = flat_for(layers)
      elseif layer_name then source = layer_frames(layer_name)
      else source = flat end
      -- `frames` (opcional): cuántos frames usar (p. ej. si los últimos están vacíos)
      local nframes = col.frames or row.frames or nframes
      for i = 1, nframes do
        local c, clipped = make_cell(source[i], rect, col.foot or row.foot, col)
        clipped_total = clipped_total + clipped
        cells[i] = c
        -- `fps` en la fila fuerza una duración fija; si no, la de Aseprite
        durations[i] = row.fps and math.floor(1000 / row.fps + 0.5)
          or math.floor(spr.frames[i].duration * 1000 + 0.5)
        empty[i] = is_empty(c)
        dup_of[i] = -1
        for j = 1, i - 1 do
          if dup_of[j] == -1 and c:isEqual(cells[j]) then dup_of[i] = j - 1; break end
        end
      end

      -- tira horizontal
      local strip = Image(cell_w * nframes, cell_h, ColorMode.RGB)
      for i = 1, nframes do strip:drawImage(cells[i], Point((i - 1) * cell_w, 0)) end
      local file = anim .. ".png"
      strip:saveAs(out_dir .. "/" .. file)

      -- periodo: menor p (divisor de n) tal que frame[i] == frame[i-p] para todo i >= p.
      -- Ej.: 16 frames donde 8–15 repiten 0–7 -> period = 8. Godot usa solo los `period` primeros.
      local period = nframes
      for p = 1, nframes - 1 do
        if nframes % p == 0 then
          local ok = true
          for i = p + 1, nframes do
            if not cells[i]:isEqual(cells[i - p]) then ok = false; break end
          end
          if ok then period = p; break end
        end
      end

      local unique, empties, dups = 0, {}, {}
      for i = 1, nframes do
        if dup_of[i] == -1 then unique = unique + 1 else dups[#dups + 1] = { i - 1, dup_of[i] } end
        if empty[i] then empties[#empties + 1] = i - 1 end
      end
      if clipped_total > 0 then
        warnings[#warnings + 1] = string.format("%s: %d px quedaron fuera de la celda (agranda cell o ajusta foot)", anim, clipped_total)
      end
      if #empties == nframes then
        warnings[#warnings + 1] = anim .. ": todos los frames están vacíos (¿región mal definida?)"
      end

      local loop = row.loop ~= false
      if col.loop ~= nil then loop = col.loop end

      manifest.animations[anim] = {
        file = file,
        frame_count = nframes,
        durations_ms = durations,
        loop = loop,
        period = period,
        unique_frames = unique,
        duplicates = dups,          -- pares [frame, igual_a_frame]
        empty_frames = empties,
        region = { rect.x, rect.y, rect.w, rect.h },
        layer = layer_name,
        layers = layers,
        foot = col.foot or row.foot,
      }
    end
  end
end

manifest.warnings = warnings

local f = io.open(out_dir .. "/" .. L.name .. ".json", "w")
f:write(to_json(manifest) .. "\n")
f:close()

local count = 0
for _ in pairs(manifest.animations) do count = count + 1 end
print(string.format("[export_strips] %s: %d animaciones -> %s", L.name, count, L.out_dir))
for _, w in ipairs(warnings) do print("[export_strips] AVISO " .. w) end

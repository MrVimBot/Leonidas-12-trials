#!/usr/bin/env bash
# Regenera, a partir de los .aseprite: tiras PNG + SpriteFrames (personajes),
# recortes de entorno + TileSets.
#
#   tools/export_sprites.sh                 # todo
#   tools/export_sprites.sh leonidas_mini   # solo ese personaje (sin recortes)
#
# Variables opcionales: ASEPRITE (ruta al binario), GODOT (ruta al binario).
# Trabaja siempre sobre una copia temporal del .aseprite: los originales no se tocan.
# Mejor con el editor de Godot CERRADO: el import en modo consola puede dejar
# desactualizada la caché de UID del editor (avisos "invalid UID" hasta reiniciarlo).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASEPRITE="${ASEPRITE:-$(command -v aseprite || echo "$HOME/Developer/aseprite/build/bin/aseprite")}"
GODOT="${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"

cd "$ROOT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [[ $# -gt 0 ]]; then
  layouts=(); for n in "$@"; do layouts+=("tools/sprite_layouts/$n.lua"); done
else
  layouts=(tools/sprite_layouts/*.lua)
fi

for layout in "${layouts[@]}"; do
  # el layout declara su source = "assets/sprites/xxx.aseprite"
  src="$(sed -n 's/^[[:space:]]*source[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' "$layout" | head -1)"
  [[ -f "$src" ]] || { echo "No existe $src (declarado en $layout)" >&2; exit 1; }
  cp "$src" "$TMP/copia.aseprite"
  "$ASEPRITE" -b "$TMP/copia.aseprite" \
    --script-param layout="$layout" \
    --script-param root="$ROOT" \
    --script tools/export_strips.lua
done

# Recortes sueltos (objetos de entorno y franjas de tiles): tools/recortes/*.lua
if [[ $# -eq 0 ]]; then
  for config in tools/recortes/*.lua; do
    src="$(sed -n 's/^[[:space:]]*source[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' "$config" | head -1)"
    [[ -f "$src" ]] || { echo "No existe $src (declarado en $config)" >&2; exit 1; }
    cp "$src" "$TMP/copia.aseprite"
    "$ASEPRITE" -b "$TMP/copia.aseprite" \
      --script-param config="$config" \
      --script-param root="$ROOT" \
      --script tools/export_recortes.lua
  done
fi

# Tiras de la cinemática inicial: cada .aseprite tal cual, en una tira horizontal.
# (Los cortes de cada tira están en tools/build_cinematica.gd.)
if [[ $# -eq 0 ]]; then
  mkdir -p assets/sprites/cinematica
  for n in leonidas_dormido leonidas_sorprendido_2 leonidas_termina_de_leer \
           mama_caminando_con_regalo mama_parada dar_regalo parada_sin_nada \
           caminar_sin_nada carta; do
    cp "assets/sprites/$n.aseprite" "$TMP/copia.aseprite"
    "$ASEPRITE" -b "$TMP/copia.aseprite" --sheet "assets/sprites/cinematica/$n.png" \
      --sheet-type horizontal >/dev/null
  done
fi

# Importar los PNG nuevos y construir los SpriteFrames y los TileSets.
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT" --script res://tools/build_sprite_frames.gd
"$GODOT" --headless --path "$ROOT" --script res://tools/build_tilesets.gd
"$GODOT" --headless --path "$ROOT" --script res://tools/build_cinematica.gd

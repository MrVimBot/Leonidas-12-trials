#!/usr/bin/env bash
# Arte PINTADO del nivel 2: de fuente/nivel2/ (1280×720 sueltos) a SpriteFrames del juego.
#
#   tools/pintados/normalizar.sh            # todos los personajes de tools/pintados/personajes.gd
#   tools/pintados/normalizar.sh medusa     # solo ese
#
# Pasos: 1) normalizar.gd recorta/escala/empaqueta en assets/sprites/pintados/<personaje>/
#        2) importa las hojas con filtro lineal + mipmaps (no son pixel art)
#        3) construir_sprite_frames.gd -> resources/sprite_frames/<personaje>.tres
# Si la artista entrega de nuevo: tools/pintados/copiar_fuente.sh "<carpeta>" y luego esto.
# Mejor con el editor de Godot CERRADO (mismo motivo que tools/export_sprites.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
cd "$ROOT"

"$GODOT" --headless --path . --script res://tools/pintados/normalizar.gd -- "$@"

# Importar (crea los .import), activar mipmaps en los de assets/sprites/pintados y reimportar.
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
for imp in assets/sprites/pintados/*/*.png.import; do
  sed -i '' 's/^mipmaps\/generate=false/mipmaps\/generate=true/' "$imp"
done
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

"$GODOT" --headless --path . --script res://tools/pintados/construir_sprite_frames.gd -- "$@"

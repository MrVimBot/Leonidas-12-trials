shader_type canvas_item;
// Agua animada por tile (TileData.material, lo asigna tools/build_tilesets.gd).
// Solo cambia los píxeles del color base del agua (`color_agua`), así sirve también
// para tiles mixtos (orillas). Dibuja olas de 1 px en filas cada 8 px que se desplazan
// a saltos de píxel entero (tiempo a pasos), en sentidos alternos por fila.
// Las coordenadas son del mundo: las olas no se arrastran con la cámara.

uniform vec4 color_agua : source_color;
uniform vec4 color_cresta : source_color = vec4(0.49, 0.77, 0.82, 1.0);
uniform vec4 color_valle : source_color;
uniform float tolerancia = 0.06;
uniform float pasos_por_segundo = 4.0;
varying vec2 pos_mundo;
varying vec4 modulacion; // COLOR del vértice (en fragment() COLOR ya trae la textura)

float azar(float n) { return fract(sin(n * 91.345) * 47453.5453); }

void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	modulacion = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (distance(c.rgb, color_agua.rgb) < tolerancia) {
		vec2 p = floor(pos_mundo);
		float t = floor(TIME * pasos_por_segundo);
		float banda = floor(p.y / 8.0);
		float sentido = mod(banda, 2.0) < 1.0 ? 1.0 : -1.0;
		float x = mod(p.x + floor(azar(banda) * 48.0) + t * sentido, 48.0);
		float fila = mod(p.y, 8.0);
		float largo = 5.0 + floor(azar(banda + 7.0) * 4.0);
		if (abs(fila - 3.0) < 0.5 && x < largo) {
			c.rgb = color_cresta.rgb;
		} else if (abs(fila - 4.0) < 0.5 && x >= 1.0 && x < largo + 1.0) {
			c.rgb = color_valle.rgb;
		}
	}
	COLOR = c * modulacion;
}

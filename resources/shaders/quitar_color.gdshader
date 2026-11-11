shader_type canvas_item;
// Vuelve transparentes los píxeles de un color (el fondo de agua que trae dibujado
// el remolino), para que se vea el agua de la zona debajo.

uniform vec4 color_fondo : source_color = vec4(0.243, 0.388, 0.584, 1.0); // #3e6395
uniform float tolerancia = 0.02;
varying vec4 modulacion; // COLOR del vértice (en fragment() COLOR ya trae la textura)

void vertex() {
	modulacion = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (distance(c.rgb, color_fondo.rgb) < tolerancia) {
		c.a = 0.0;
	}
	COLOR = c * modulacion;
}

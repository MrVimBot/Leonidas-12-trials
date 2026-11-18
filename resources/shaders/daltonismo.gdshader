shader_type canvas_item;
render_mode unshaded;
// Filtro de daltonismo para el jugador (lo usa el autoload `Daltonismo`, scenes/ui/filtro_daltonismo.tscn).
// Es una CORRECCIÓN (daltonización), no una simulación: como hacen los juegos comerciales,
// 1) simula cómo ve el color un dicrómata, 2) calcula el color que pierde (error) y
// 3) reparte ese error en los canales que sí distingue, para que rojos y verdes se separen.
// Daltonización: Fidaner, Lin y Ozguven, "Analysis of Color Blindness" (2005), la del proyecto daltonize.
// Simulación: Viénot, Brettel y Mollon (1999), mismas matrices que el plugin Eyesee
// (github.com/Ultipuk/godot-eyesee-color, MIT) y libDaltonLens. Se trabaja en sRGB lineal.

uniform sampler2D pantalla : hint_screen_texture, filter_nearest; // nearest: no emborronar el pixel art
uniform int tipo : hint_range(0, 2) = 0; // 0 sin filtro · 1 protanopía · 2 deuteranopía
uniform float intensidad : hint_range(0.0, 1.0) = 1.0;

const mat3 VIENOT_PROTAN = mat3(
	vec3(0.11238, 0.11238, 0.00401),
	vec3(0.88762, 0.88762, -0.00401),
	vec3(0.00000, 0.00000, 1.00000)
);
const mat3 VIENOT_DEUTAN = mat3(
	vec3(0.29275, 0.29275, -0.02234),
	vec3(0.70725, 0.70725, 0.02234),
	vec3(0.00000, 0.00000, 1.00000)
);

vec3 srgb_a_lineal(vec3 c) {
	return mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

vec3 lineal_a_srgb(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(1.055 * pow(c, vec3(1.0 / 2.4)) - vec3(0.055), c * 12.92, lessThan(c, vec3(0.0031308)));
}

void fragment() {
	vec3 original = srgb_a_lineal(texture(pantalla, SCREEN_UV).rgb);
	vec3 simulado = (tipo == 1 ? VIENOT_PROTAN : VIENOT_DEUTAN) * original;
	vec3 error = original - simulado;
	// El rojo perdido pasa al verde y al azul (matriz de Fidaner).
	vec3 correccion = vec3(0.0, 0.7 * error.r + error.g, 0.7 * error.r + error.b);
	vec3 resultado = tipo == 0 ? original : original + correccion * intensidad;
	COLOR = vec4(lineal_a_srgb(resultado), 1.0);
}

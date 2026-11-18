shader_type canvas_item;
// Pasa a gris lo que dibuja el CanvasItem (`cantidad` 1 = gris del todo). Lo usa la barra de
// la jefa mientras es invulnerable (`BarraJefe`): un `modulate` gris no quita el rojo de los
// corazones, solo los oscurece.
// En fragment() de Godot 4, COLOR ya trae la textura multiplicada por el color del vértice.

uniform float cantidad : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 c = COLOR;
	float gris = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(gris), cantidad), c.a);
}

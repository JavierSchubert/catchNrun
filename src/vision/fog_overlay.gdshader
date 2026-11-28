shader_type canvas_item;
// World fog of war: the texture's red channel is the fog opacity per map cell
// (255 = unexplored, mid = previously seen, 0 = visible). Linear filtering softens cell edges.

uniform vec4 fog_color : source_color = vec4(0.015, 0.02, 0.035, 1.0);

void fragment() {
	COLOR = vec4(fog_color.rgb, texture(TEXTURE, UV).r * fog_color.a);
}

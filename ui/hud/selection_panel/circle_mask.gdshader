shader_type canvas_item;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float radius = length(centered);
	vec4 sample = texture(TEXTURE, UV);
	float alpha = sample.a * smoothstep(0.5, 0.47, radius);
	COLOR = vec4(sample.rgb, alpha);
}

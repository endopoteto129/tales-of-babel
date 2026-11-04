// プレイヤーキャラの輪郭線。CanvasGroup に付けて、中に描いたものの周りを縁取る
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 line_color : source_color = vec4(1.0, 0.95, 0.55, 1.0);
uniform float line_thickness : hint_range(0.0, 10.0) = 3.0;

const vec2 DIRS[8] = {vec2(1, 0), vec2(-1, 0), vec2(0, 1), vec2(0, -1), vec2(0.7, 0.7), vec2(-0.7, 0.7), vec2(0.7, -0.7), vec2(-0.7, -0.7)};

void fragment() {
	vec2 size = SCREEN_PIXEL_SIZE * line_thickness;
	float outline = 0.0;
	for (int i = 0; i < 8; i++) {
		outline += texture(screen_texture, SCREEN_UV + DIRS[i] * size).a;
	}
	outline = min(outline, 1.0);
	vec4 c = texture(screen_texture, SCREEN_UV);
	COLOR = mix(c, line_color, outline - c.a);
}

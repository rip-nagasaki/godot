shader_type canvas_item;
// "Lights Out" twist: darkens the screen except for soft light pools.

uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec4 light0 = vec4(0.0);
uniform vec4 light1 = vec4(0.0);
uniform vec4 light2 = vec4(0.0);
uniform vec4 light3 = vec4(0.0);
uniform float darkness = 0.0;

float pool(vec2 p, vec4 l) {
	if (l.z <= 0.0) {
		return 0.0;
	}
	float d = length(p - l.xy);
	return 1.0 - smoothstep(l.z * 0.35, l.z, d);
}

void fragment() {
	vec2 p = UV * rect_size;
	float lit = max(max(pool(p, light0), pool(p, light1)), max(pool(p, light2), pool(p, light3)));
	float flicker = 0.97 + 0.03 * sin(TIME * 13.0);
	COLOR = vec4(0.02, 0.02, 0.07, darkness * (1.0 - lit * flicker) * 0.94);
}

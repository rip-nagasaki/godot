shader_type canvas_item;
// Animated festival sky: gradient, twinkling stars, sun glow, optional aurora and drifting clouds.

uniform vec4 top_color : source_color = vec4(0.14, 0.10, 0.33, 1.0);
uniform vec4 mid_color : source_color = vec4(0.72, 0.27, 0.49, 1.0);
uniform vec4 bottom_color : source_color = vec4(1.0, 0.70, 0.42, 1.0);
uniform vec4 cloud_color : source_color = vec4(1.0, 0.81, 0.66, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.94, 0.72, 1.0);
uniform vec2 sun_pos = vec2(0.82, 0.62);
uniform float star_amount = 0.4;
uniform float aurora = 0.0;
uniform float aspect = 1.7777;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, mid_color.rgb, smoothstep(0.0, 0.62, uv.y));
	col = mix(col, bottom_color.rgb, smoothstep(0.5, 1.0, uv.y));

	// Stars
	vec2 sp = uv * vec2(aspect, 1.0) * 70.0;
	vec2 cell = floor(sp);
	float h = hash(cell);
	if (h > 0.975) {
		vec2 off = vec2(hash(cell + 1.3), hash(cell + 7.1)) - 0.5;
		vec2 c = fract(sp) - 0.5 - off * 0.6;
		float tw = 0.55 + 0.45 * sin(TIME * (1.5 + h * 6.0) + h * 40.0);
		float s = smoothstep(0.16, 0.0, length(c)) * tw;
		s += smoothstep(0.03, 0.0, abs(c.x)) * smoothstep(0.35, 0.0, abs(c.y)) * tw * 0.4;
		s += smoothstep(0.03, 0.0, abs(c.y)) * smoothstep(0.35, 0.0, abs(c.x)) * tw * 0.4;
		col += vec3(s) * star_amount * (1.0 - smoothstep(0.15, 0.85, uv.y));
	}

	// Sun / moon
	vec2 d = (uv - sun_pos) * vec2(aspect, 1.0);
	float sd = length(d);
	col = mix(col, sun_color.rgb, smoothstep(0.075, 0.068, sd) * 0.95);
	col += sun_color.rgb * exp(-sd * 5.0) * 0.35;

	// Aurora ribbons
	if (aurora > 0.0) {
		float a = fbm(vec2(uv.x * 2.5 + TIME * 0.04, TIME * 0.07));
		float y0 = 0.22 + (a - 0.5) * 0.25;
		float band = exp(-pow((uv.y - y0) * 7.0, 2.0));
		float streak = 0.5 + 0.5 * fbm(vec2(uv.x * 14.0, TIME * 0.25));
		vec3 ac = mix(vec3(0.1, 1.0, 0.65), vec3(0.65, 0.35, 1.0), smoothstep(0.2, 0.9, uv.x));
		col += ac * band * streak * aurora * 0.7;
	}

	// Clouds (two parallax layers)
	vec2 cp = uv * vec2(aspect, 1.0) * 2.2;
	float c1 = fbm(cp + vec2(TIME * 0.015, 0.0));
	float c2 = fbm(cp * 1.7 + vec2(TIME * 0.04, 3.0));
	float m1 = smoothstep(0.52, 0.78, c1) * smoothstep(0.25, 0.85, uv.y);
	float m2 = smoothstep(0.56, 0.82, c2) * smoothstep(0.45, 1.0, uv.y);
	col = mix(col, cloud_color.rgb * 0.8, m1 * 0.45);
	col = mix(col, cloud_color.rgb, m2 * 0.6);

	// Vignette
	vec2 v = uv - 0.5;
	col *= 1.0 - dot(v, v) * 0.55;
	COLOR = vec4(col, 1.0);
}

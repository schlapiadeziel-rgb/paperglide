shader_type canvas_item;
// Full-screen post pass: shockwave ripples, chromatic aberration, hurt /
// low-health vignette, screen flash and FURY golden grading.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec4 waves[4];            // xy = uv centre, z = age 0..1, w = strength
uniform float aspect = 1.7778;
uniform float aberration = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.8, 0.05, 0.02, 1.0);
uniform float vignette = 0.0;
uniform float base_vignette = 0.22;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash = 0.0;
uniform float fury = 0.0;
uniform float time_s = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 off = vec2(0.0);
	for (int i = 0; i < 4; i++) {
		vec4 w = waves[i];
		if (w.w <= 0.0) { continue; }
		vec2 d = uv - w.xy;
		d.x *= aspect;
		float dist = length(d);
		float radius = w.z * 0.55;
		float band = 0.07;
		float x = (dist - radius) / band;
		float ring = exp(-x * x) * (1.0 - w.z);
		off += normalize(d + 1e-5) * ring * 0.022 * w.w * vec2(1.0 / aspect, 1.0);
	}
	uv -= off;
	float ab = aberration + length(off) * 1.6;
	vec2 dir = (uv - 0.5) * ab;
	vec3 col;
	col.r = texture(screen_tex, uv + dir).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - dir).b;
	// FURY: warm grade + pulsing golden edge glow
	if (fury > 0.0) {
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		vec3 warm = mix(col, vec3(lum) * vec3(1.25, 1.0, 0.62), 0.35);
		col = mix(col, warm, fury);
		vec2 e = abs(SCREEN_UV - 0.5) * 2.0;
		float edge = pow(max(e.x, e.y), 5.0) * (0.75 + 0.25 * sin(time_s * 8.0));
		col += vec3(1.0, 0.7, 0.15) * edge * 0.55 * fury;
	}
	// vignettes
	vec2 v = (SCREEN_UV - 0.5) * vec2(aspect * 0.62, 1.0);
	float vd = smoothstep(0.35, 0.95, length(v));
	col *= 1.0 - vd * base_vignette;
	col = mix(col, vignette_color.rgb, vd * clamp(vignette, 0.0, 1.0));
	col = mix(col, flash_color.rgb, clamp(flash, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}

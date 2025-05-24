shader_type sky;
render_mode use_debanding;

uniform vec3 sky_color: source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D sky_texture: source_color, hint_default_white, filter_linear;

uniform vec2 wind_direction = vec2(-1.0, 1.0);
uniform float wind_intensity = 0.05;
uniform float wind_speed = 0.15;

uniform bool ground_enabled = false;
uniform float ground_threshold: hint_range(-1.0, 1.0, 0.01) = 0.0;
uniform float ground_blend: hint_range(0.0, 1.0, 0.01) = 0.2;

uniform bool sun_enabled = false;
uniform vec2 sun_rotation = vec2(60.0, 30.0);
uniform float sun_threshold: hint_range(-1.0, 1.0, 0.001) = 0.98;
uniform float sun_blend: hint_range(0.0, 1.0, 0.001) = 0.02;
uniform bool sun_show = false;

uniform float pole_threshold: hint_range(0.0, 1.0, 0.01) = 0.96;
uniform bool pole_whirlwind = true;


vec4 flowing_sky(vec3 sky_normal, vec2 sky_coords) {
	vec3 up_vector = vec3(0.0, 1.0, 0.0);
	float sky_normal_dot_up = dot(sky_normal, up_vector);
	vec3 sphere_v = normalize(up_vector - sky_normal_dot_up * sky_normal);
	vec3 sphere_u = cross(sphere_v, sky_normal);

	vec3 wind_direction_normalized = normalize(vec3(wind_direction.x, 0.0, wind_direction.y));
	vec3 flow_direction = wind_direction_normalized - dot(wind_direction_normalized, sky_normal) * sky_normal;
	vec2 flow_uv = vec2(dot(flow_direction, sphere_u), dot(flow_direction, sphere_v));

	float phase1_time = fract(TIME * wind_speed);
	float phase2_time = fract(phase1_time + 0.5);
	float mix_time = abs((phase1_time - 0.5) * 2.0);

	float ground_mask = 1.0;
	if (ground_enabled) {
		float ground_threshold_remapped = (ground_threshold + 1.0) * (1.0 + ground_blend / 2.0) - 1.0; // from [-1.0, 1.0] to [-1.0, 1.0 + ground_blend]
		ground_mask = smoothstep(ground_threshold_remapped - ground_blend, ground_threshold_remapped, sky_normal_dot_up);
	}

	float sun_mask = 1.0;
	if (sun_enabled) {
		vec2 r = vec2(-radians(sun_rotation.x), radians(sun_rotation.y) + PI / 2.0);
		vec3 sun_direction = normalize(vec3(cos(r.y) * cos(r.x), sin(r.x), cos(r.x) * sin(r.y)));
		sun_mask = smoothstep(-sun_threshold - sun_blend, -sun_threshold, dot(normalize(sun_direction), sky_normal));
	}

	float mask = ground_mask * sun_mask;
	vec2 phase1_uv = sky_coords + flow_uv * wind_intensity * phase1_time * mask;
	vec2 phase2_uv = sky_coords + flow_uv * wind_intensity * phase2_time * mask;
	vec4 phase1_color = texture(sky_texture, phase1_uv);
	vec4 phase2_color = texture(sky_texture, phase2_uv);
	vec4 mix_color = mix(phase1_color, phase2_color, mix_time);

	vec4 pole_color; // fixing uv holes on poles
	float pole_mix = smoothstep(pole_threshold, 1.0, abs(sky_normal_dot_up));
	if (pole_whirlwind) {
		vec2 pole_flow_uv = vec2(pole_mix, 1.0 - pole_mix); // creates whirlwind at poles
		vec2 pole_phase1_uv = sky_coords + pole_flow_uv * wind_intensity * phase1_time * mask;
		vec2 pole_phase2_uv = sky_coords + pole_flow_uv * wind_intensity * phase2_time * mask;
		vec4 pole_phase1_color = texture(sky_texture, pole_phase1_uv);
		vec4 pole_phase2_color = texture(sky_texture, pole_phase2_uv);
		pole_color = mix(pole_phase1_color, pole_phase2_color, mix_time);
	} else { pole_color = texture(sky_texture, sky_coords); }
	mix_color = mix(mix_color, pole_color, pole_mix);

	return mix_color * max(sun_mask, 1.0 - float(sun_show));
}


void sky() {
	COLOR = flowing_sky(EYEDIR, SKY_COORDS).rgb * sky_color;
}
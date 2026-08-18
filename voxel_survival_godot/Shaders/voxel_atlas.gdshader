shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

uniform sampler2D atlas : source_color, filter_nearest_mipmap;
uniform vec2 atlas_grid = vec2(4.0, 4.0);
uniform float ambient_strength : hint_range(0.0, 1.0) = 0.20;

void fragment() {
    vec2 local_uv = fract(UV);
    vec2 inset = vec2(0.035);
    local_uv = mix(inset, vec2(1.0) - inset, local_uv);
    vec2 atlas_uv = (UV2 + local_uv) / atlas_grid;
    vec4 tex = texture(atlas, atlas_uv);
    ALBEDO = tex.rgb;
    ROUGHNESS = 1.0;
    AO = 1.0 - ambient_strength;
}

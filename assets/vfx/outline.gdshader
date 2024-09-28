shader_type canvas_item;

uniform float outline_size : hint_range(0.0, 10.0); // Outline thickness
uniform vec4 outline_color : source_color; // Outline color

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    // If the pixel is transparent, check the neighboring pixels
    if (tex_color.a < 0.1) {
        // Check surrounding pixels for color
        vec4 color = vec4(0.0);
        for (float x = -outline_size; x <= outline_size; x++) {
            for (float y = -outline_size; y <= outline_size; y++) {
                // Sample neighboring pixels
                color += texture(TEXTURE, UV + vec2(x, y) / SCREEN_SIZE);
            }
        }

        // If any neighboring pixel is not transparent, render the outline color
        if (color.a > 0.1) {
            tex_color = outline_color;
        }
    }

    COLOR = tex_color;
}

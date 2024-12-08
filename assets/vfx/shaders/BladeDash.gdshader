shader_type canvas_item;

uniform float trail_opacity : hint_range(0.0, 1.0) = 0.3;  // Opacity of the trail ghosts
uniform int trail_count : hint_range(1, 20) = 10;          // Number of trail ghosts
uniform float trail_spacing : hint_range(0.0, 1.0) = 0.1;  // Spacing between trail ghosts
uniform float movement_direction_x : hint_range(-1.0, 1.0) = 1.0; // X component of movement direction
uniform float movement_direction_y : hint_range(-1.0, 1.0) = 0.0; // Y component of movement direction
uniform float blur_strength : hint_range(0.0, 1.0) = 0.05; // Blurring/stretching effect

void fragment() {
    vec4 final_color = vec4(0.0);  // Accumulated trail colors
    vec2 movement_direction = vec2(movement_direction_x, movement_direction_y); // Combine direction components

    // Loop to create multiple trailing "ghosts"
    for (int i = 1; i <= trail_count; i++) {
        float factor = float(i);  // Factor to control trail placement

        // Compute the offset for this trail ghost
        vec2 trail_offset = movement_direction * trail_spacing * factor;

        // Apply additional blur or stretching effect
        trail_offset += vec2(cos(TIME - factor) * blur_strength, sin(TIME - factor) * blur_strength);

        // Fetch the trail layer texture color
        vec4 trail_color = texture(TEXTURE, UV - trail_offset);

        // Adjust the trail color opacity and fading
        trail_color.a *= trail_opacity / factor;  // Fade out each successive ghost

        // Accumulate the trail layer
        final_color.rgb += trail_color.rgb * trail_color.a;  // Blend by alpha
        final_color.a += trail_color.a;  // Add to overall alpha
    }

    // Add the main sprite's color on top
    vec4 sprite_color = texture(TEXTURE, UV);
    final_color.rgb += sprite_color.rgb * sprite_color.a;  // Modulate by alpha
    final_color.a = max(final_color.a, sprite_color.a);    // Ensure proper alpha blending

    // Output the final color
    COLOR = final_color;
}

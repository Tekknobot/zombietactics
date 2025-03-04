shader_type canvas_item;

// Convert RGB to HSV
vec3 rgb2hsv(vec3 c) {
    float maxC = max(c.r, max(c.g, c.b));
    float minC = min(c.r, min(c.g, c.b));
    float delta = maxC - minC;
    float h = 0.0;
    if (delta < 0.00001) {
        h = 0.0;
    } else if (maxC == c.r) {
        h = mod((c.g - c.b) / delta, 6.0);
    } else if (maxC == c.g) {
        h = ((c.b - c.r) / delta) + 2.0;
    } else {
        h = ((c.r - c.g) / delta) + 4.0;
    }
    h = h / 6.0;
    if (h < 0.0)
        h += 1.0;
    float s = (maxC <= 0.0) ? 0.0 : (delta / maxC);
    float v = maxC;
    return vec3(h, s, v);
}

// Convert HSV back to RGB
vec3 hsv2rgb(vec3 c) {
    float h = c.x * 6.0;
    float s = c.y;
    float v = c.z;
    float c_val = v * s;
    float x = c_val * (1.0 - abs(mod(h, 2.0) - 1.0));
    float m = v - c_val;
    vec3 rgb;
    if (h < 1.0)
        rgb = vec3(c_val, x, 0.0);
    else if (h < 2.0)
        rgb = vec3(x, c_val, 0.0);
    else if (h < 3.0)
        rgb = vec3(0.0, c_val, x);
    else if (h < 4.0)
        rgb = vec3(0.0, x, c_val);
    else if (h < 5.0)
        rgb = vec3(x, 0.0, c_val);
    else
        rgb = vec3(c_val, 0.0, x);
    return rgb + vec3(m);
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    vec4 final_color = tex_color;
    
    // Preserve pixels that are nearly black.
    if (!(tex_color.r < 0.1 && tex_color.g < 0.1 && tex_color.b < 0.1)) {
        vec3 hsv = rgb2hsv(tex_color.rgb);
        
        // Approximate skin tone check:
        // Here we assume skin tones fall roughly within:
        // - Hue between 0.03 and 0.12
        // - Saturation between 0.2 and 0.6
        // - Brightness above 0.4
        if (!(hsv.x > 0.03 && hsv.x < 0.12 &&
              hsv.y > 0.2  && hsv.y < 0.6  &&
              hsv.z > 0.4)) {
            // For a predominant black/gray tone, desaturate fully.
            hsv.x = 0.0; // Hue is irrelevant when saturation is zero.
            hsv.y = 0.0; // Remove all color.
            // Remap the brightness to a darker range.
            // Even bright pixels will be mapped to a dark gray tone.
            hsv.z = mix(0.1, 0.5, hsv.z);
            
            final_color.rgb = hsv2rgb(hsv);
        }
    }
    
    COLOR = final_color;
}

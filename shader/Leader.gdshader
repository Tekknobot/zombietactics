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
    vec3 hsv = rgb2hsv(tex_color.rgb);
    
    // Override the hue to red (0.0 or 1.0 works for red in HSV)
    hsv.x = 0.0;
    // Force full saturation for a vivid red tone
    hsv.y = 1.0;
    // Remap the brightness so that low values become very dark (e.g., 0.2) and high values become bright red (1.0)
    hsv.z = mix(0.2, 1.0, hsv.z);
    
    vec3 terminator_color = hsv2rgb(hsv);
    COLOR = vec4(terminator_color, tex_color.a);
}

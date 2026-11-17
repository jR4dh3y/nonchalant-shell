#version 440
// Keeps a layered item's pixels inside a rounded rectangle (in the item's
// own coordinates) with an antialiased edge.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec4 clipRect;
    float radius;
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 half_size = ubuf.clipRect.zw * 0.5;
    vec2 point = qt_TexCoord0 * ubuf.size - ubuf.clipRect.xy - half_size;
    vec2 corner = abs(point) - (half_size - vec2(ubuf.radius));
    float distance = length(max(corner, 0.0)) + min(max(corner.x, corner.y), 0.0) - ubuf.radius;
    fragColor = texture(source, qt_TexCoord0) * clamp(0.5 - distance, 0.0, 1.0) * ubuf.qt_Opacity;
}

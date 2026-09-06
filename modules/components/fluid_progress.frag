#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float phase;
    float isPlaying;
    float canvasWidth;
    float canvasHeight;
    vec2 _pad;
    vec4 baseColor;
    vec4 fillColor;
    vec4 highlightColor;
} ubuf;

void main() {
    vec4 textSample = texture(source, qt_TexCoord0);
    float textAlpha = textSample.a;
    if (textAlpha < 0.001) {
        discard;
    }

    if (ubuf.isPlaying < 0.5 || ubuf.progress <= 0.0) {
        fragColor = vec4(ubuf.baseColor.rgb * textAlpha, textAlpha) * ubuf.qt_Opacity;
        return;
    }

    float w = max(1.0, ubuf.canvasWidth);
    float h = max(1.0, ubuf.canvasHeight);
    float px = qt_TexCoord0.x * w;
    float py = qt_TexCoord0.y * h;

    // 1. Fluid wavy boundary (undulating meniscus in pixel space)
    // 6px wave amplitude, frequency tuned to font height
    float waveAmp = 5.0 * smoothstep(0.0, 0.03, ubuf.progress) * (1.0 - smoothstep(0.97, 1.0, ubuf.progress));
    float fluidEdgePx = (ubuf.progress * w) + sin(py * 0.45 + ubuf.phase * 2.8) * waveAmp;

    // 2. Liquid fill mask with smooth 1.5px antialiased edge
    float fillAmount = 1.0 - smoothstep(fluidEdgePx - 1.5, fluidEdgePx + 1.5, px);

    // 3. Glowing meniscus right at the liquid crest
    float distToCrest = abs(px - fluidEdgePx);
    float meniscus = exp(-distToCrest * distToCrest / 14.0) * fillAmount;

    // 4. Traveling liquid caustics / specular ripples flowing through the letters
    float wave1 = sin(px * 0.22 - ubuf.phase * 3.5 + py * 0.2);
    float wave2 = cos(px * 0.12 - ubuf.phase * 2.0 - py * 0.15);
    float surge = pow(clamp(0.5 + 0.5 * (wave1 * 0.7 + wave2 * 0.3), 0.0, 1.0), 2.2);

    // Dynamic fluid color: blend base theme color with bright highlight / gleam
    vec3 gleamColor = mix(ubuf.fillColor.rgb, vec3(1.0, 1.0, 1.0), 0.75);
    vec3 activeLiquid = mix(ubuf.fillColor.rgb, gleamColor, surge * 0.55);
    activeLiquid = mix(activeLiquid, vec3(1.0, 1.0, 1.0), meniscus * 0.90);

    vec3 finalRgb = mix(ubuf.baseColor.rgb, activeLiquid, fillAmount);
    float finalA = textAlpha * ubuf.qt_Opacity;

    fragColor = vec4(finalRgb * finalA, finalA);
}

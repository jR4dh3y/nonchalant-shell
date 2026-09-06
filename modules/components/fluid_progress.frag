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

    float x = qt_TexCoord0.x;
    float y = qt_TexCoord0.y;

    // Fluid wave at progress edge (undulating fluid meniscus)
    float waveScale = smoothstep(0.0, 0.05, ubuf.progress) * (1.0 - smoothstep(0.96, 1.0, ubuf.progress));
    float waveAmp = 0.022 * waveScale;
    float waveFreq = 18.0;
    float fluidBoundary = ubuf.progress + sin(y * waveFreq + ubuf.phase) * waveAmp;

    // Smoothstep edge for anti-aliasing the liquid wave front
    float edgeWidth = 0.008;
    float fillAmount = 1.0 - smoothstep(fluidBoundary - edgeWidth, fluidBoundary + edgeWidth, x);

    // Live fluid wave/shimmer through the liquid fill
    float wave1 = sin(x * 22.0 - ubuf.phase * 2.4 + y * 6.0);
    float wave2 = cos(x * 12.0 - ubuf.phase * 1.5 - y * 4.0);
    float shimmer = 0.5 + 0.3 * wave1 + 0.2 * wave2;

    vec3 activeLiquidColor = mix(ubuf.fillColor.rgb, ubuf.highlightColor.rgb, clamp(shimmer, 0.0, 1.0) * 0.45);

    // Blend between active liquid color and base white text
    vec3 finalRgb = mix(ubuf.baseColor.rgb, activeLiquidColor, fillAmount);
    float finalA = textAlpha * ubuf.qt_Opacity;

    fragColor = vec4(finalRgb * finalA, finalA);
}

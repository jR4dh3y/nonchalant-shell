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

    // 1. Prominent liquid wave boundary (meniscus)
    float waveFreq = 8.0;
    float waveAmp = 0.065 * smoothstep(0.0, 0.04, ubuf.progress) * (1.0 - smoothstep(0.96, 1.0, ubuf.progress));
    float fluidBoundary = ubuf.progress + sin(y * waveFreq + ubuf.phase * 2.0) * waveAmp;

    // 2. Smooth liquid wave front
    float edgeWidth = 0.012;
    float fillAmount = 1.0 - smoothstep(fluidBoundary - edgeWidth, fluidBoundary + edgeWidth, x);

    // 3. Radiant, glowing specular meniscus right at the liquid crest
    float distToBoundary = abs(x - fluidBoundary);
    float meniscus = exp(-distToBoundary * distToBoundary / 0.0006) * fillAmount;

    // 4. Vibrant traveling fluid wave / specular light surge
    float wave1 = sin(x * 12.0 - ubuf.phase * 3.2 + y * 3.5);
    float wave2 = cos(x * 6.0 - ubuf.phase * 1.8 - y * 2.5);
    float surge = pow(max(0.0, 0.5 + 0.5 * (wave1 * 0.65 + wave2 * 0.35)), 2.0);

    // Bright specular highlight (gleaming light)
    vec3 brightHighlight = mix(ubuf.fillColor.rgb, vec3(1.0, 1.0, 1.0), 0.90);
    vec3 liquidColor = mix(ubuf.fillColor.rgb, brightHighlight, surge * 0.65);
    liquidColor = mix(liquidColor, vec3(1.0, 1.0, 1.0), meniscus * 0.95);

    vec3 finalRgb = mix(ubuf.baseColor.rgb, liquidColor, fillAmount);
    float finalA = textAlpha * ubuf.qt_Opacity;

    fragColor = vec4(finalRgb * finalA, finalA);
}

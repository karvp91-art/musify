#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uProgress;     // 0.0 to 1.0 (karaoke wipe progress)
uniform float uTime;         // Smooth time for continuous particle glint
uniform vec4 uActiveColor;   // Color for sung text
uniform vec4 uInactiveColor; // Color for unsung text
uniform vec4 uGlowColor;     // Specular neon crest color

out vec4 fragColor;

void main() {
    if (uResolution.x <= 0.0 || uResolution.y <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uResolution;

    float progress = clamp(uProgress, 0.0, 1.0);

    // Karaoke advancing wave front
    float edgeWidth = 0.06;
    float dist = uv.x - progress;

    // Transition factor from active (sung) to inactive (unsung)
    float t = smoothstep(-edgeWidth, edgeWidth, dist);
    vec4 baseText = mix(uActiveColor, uInactiveColor, t);

    // High-energy glowing specular wave right at the active singing front
    float waveDist = abs(dist);
    float waveGlow = exp(-waveDist * 30.0);

    // Micro-shimmer ripple glint
    float glint = sin((uv.x - progress) * 55.0 - uTime * 14.0) * 0.5 + 0.5;
    float shimmerIntensity = waveGlow * (0.65 + 0.35 * glint);

    // Composite specular neon glow
    vec3 finalRgb = baseText.rgb + uGlowColor.rgb * shimmerIntensity * 0.90;
    float finalAlpha = clamp(baseText.a + uGlowColor.a * shimmerIntensity * 0.30, 0.0, 1.0);

    fragColor = vec4(clamp(finalRgb, 0.0, 1.0) * finalAlpha, finalAlpha);
}

#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uProgress;
uniform float uTime;
uniform vec4 uColor;
uniform vec4 uGlowColor;

out vec4 fragColor;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uResolution;

    if (uResolution.x <= 0.0 || uResolution.y <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float progress = clamp(uProgress, 0.0, 1.0);
    if (progress <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    // Dampen waves near 0.0 and 1.0 so liquid settles gracefully
    float waveDamping = sin(progress * 3.14159265);
    if (progress >= 0.98) {
        waveDamping = max(0.0, (1.0 - progress) * 15.0);
    }

    // Dual-harmonic transverse wave along the advancing fluid meniscus
    float waveX = (sin(uv.y * 6.28318 + uTime * 4.5) * 0.018 +
                   sin(uv.y * 15.7079 - uTime * 6.5) * 0.009) * waveDamping;

    float fluidEdge = clamp(progress + waveX, 0.0, 1.0);

    float pixelWidth = 1.5 / uResolution.x;
    float alphaMask = 1.0 - smoothstep(fluidEdge - pixelWidth, fluidEdge + pixelWidth, uv.x);

    if (progress >= 0.999) {
        alphaMask = 1.0;
    }

    // Meniscus specular glow
    float crestDist = abs(uv.x - fluidEdge);
    float crestGlow = exp(-crestDist * 55.0) * max(waveDamping, 0.15);

    // Subtle gradient ramp from base color to glowing crest
    float progressNorm = clamp(uv.x / max(fluidEdge, 0.001), 0.0, 1.0);
    vec4 baseColor = mix(uColor, uGlowColor, progressNorm * 0.45);

    float finalAlpha = clamp(baseColor.a * alphaMask, 0.0, 1.0);
    vec3 finalRgb = (baseColor.rgb + uGlowColor.rgb * (crestGlow * 0.55)) * finalAlpha;

    fragColor = vec4(finalRgb, finalAlpha);
}

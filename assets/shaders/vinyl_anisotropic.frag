#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uAngle;        // Current rotation angle in radians
uniform float uInnerRadius;  // Normalized inner hole/label radius (0.0 to 0.5)
uniform float uOuterRadius;  // Normalized outer rim radius (0.0 to 0.5)
uniform vec4 uBaseColor;     // Base vinyl tone
uniform float uIntensity;    // Specular intensity factor (0.0 to 1.0)

out vec4 fragColor;

// Spectral rainbow palette for micro-groove diffraction
vec3 spectralPalette(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (t + vec3(0.0, 0.33, 0.67)));
}

void main() {
    if (uResolution.x <= 0.0 || uResolution.y <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 center = uResolution * 0.5;
    float minDim = min(uResolution.x, uResolution.y);
    vec2 p = (fragCoord - center) / minDim;
    float r = length(p);

    if (r < uInnerRadius - 0.01 || r > uOuterRadius + 0.01) {
        fragColor = vec4(0.0);
        return;
    }

    // Polar angle
    float theta = atan(p.y, p.x);

    // 1. Concentric Micro-Grooves (phonograph physical track rings)
    float grooveFreq = 160.0;
    float groove = sin(r * grooveFreq) * 0.5 + 0.5;
    float bandMod = sin(r * 24.0) * 0.15 + 0.85;
    groove = pow(groove, 1.4) * bandMod;

    // 2. Anisotropic Specular Highlight Cones (Bow-tie light reflex)
    // Simulates an overhead light source refracted along circular micro-grooves
    float lightAngle = 0.785398; // 45 degrees
    float relAngle = theta - lightAngle + uAngle;

    // Two opposite primary specular lobes
    float lobe1 = pow(abs(cos(relAngle)), 12.0);
    // Secondary softer cross-lobe simulating ambient fill light
    float lobe2 = pow(abs(sin(relAngle)), 18.0) * 0.35;
    float specHighlight = lobe1 + lobe2;

    // 3. Iridescent Diffraction Rainbow (diffraction grating interference)
    float dispersionPhase = fract((theta * 1.5 + r * 14.0 + uAngle * 0.85) / 6.28318);
    vec3 rainbow = spectralPalette(dispersionPhase);

    // 4. Combine base vinyl material + micro-grooves + specular rainbow sheen
    vec3 vinylBase = uBaseColor.rgb * (0.65 + 0.35 * groove);
    vec3 iridescentSheen = rainbow * specHighlight * 0.55 * uIntensity;
    vec3 whiteGlint = vec3(pow(specHighlight, 2.5)) * 0.45 * uIntensity;

    vec3 finalRgb = vinylBase + iridescentSheen + whiteGlint;

    // Smooth anti-aliased edge masking
    float pixelSize = 1.5 / minDim;
    float edgeAlpha = smoothstep(uInnerRadius, uInnerRadius + pixelSize, r) *
                      (1.0 - smoothstep(uOuterRadius - pixelSize, uOuterRadius, r));

    float finalAlpha = clamp(uBaseColor.a * edgeAlpha, 0.0, 1.0);
    fragColor = vec4(finalRgb * finalAlpha, finalAlpha);
}

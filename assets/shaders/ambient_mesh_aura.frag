#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform vec4 uColor1;       // Dominant album color
uniform vec4 uColor2;       // Companion vibrant color
uniform vec4 uColorBase;    // Neutral background base (AMOLED black or crisp white)
uniform float uIntensity;   // 0.0 to 1.0 intensity (damped during sheet open)

out vec4 fragColor;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
    for (int i = 0; i < 3; i++) {
        v += a * noise(p);
        p = rot * p * 2.0 + vec2(100.0);
        a *= 0.5;
    }
    return v;
}

void main() {
    if (uResolution.x <= 0.0 || uResolution.y <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uResolution;

    float t = uTime * 0.22;

    // Organic Domain Warping for fluid currents
    vec2 warp = vec2(
        fbm(uv * 2.5 + vec2(t * 0.5, -t * 0.35)),
        fbm(uv * 2.5 + vec2(-t * 0.45, t * 0.6))
    );

    vec2 p = uv + (warp - 0.5) * 0.32;

    // Rotating metaball centers in the upper half of screen (behind artwork)
    vec2 center1 = vec2(0.42 + 0.20 * sin(t * 1.1), 0.28 + 0.14 * cos(t * 0.85));
    vec2 center2 = vec2(0.58 + 0.22 * cos(t * 0.95), 0.34 + 0.15 * sin(t * 1.2));
    vec2 center3 = vec2(0.50 + 0.16 * sin(t * 0.7 + 2.0), 0.22 + 0.11 * cos(t * 1.05 + 1.0));

    float aspect = uResolution.x / uResolution.y;
    vec2 pAspect = vec2(p.x * aspect, p.y);
    vec2 c1Aspect = vec2(center1.x * aspect, center1.y);
    vec2 c2Aspect = vec2(center2.x * aspect, center2.y);
    vec2 c3Aspect = vec2(center3.x * aspect, center3.y);

    float d1 = length(pAspect - c1Aspect);
    float d2 = length(pAspect - c2Aspect);
    float d3 = length(pAspect - c3Aspect);

    float m1 = exp(-d1 * 3.4);
    float m2 = exp(-d2 * 3.7);
    float m3 = exp(-d3 * 4.1);

    float totalM = m1 + m2 + m3 + 0.001;
    vec3 fluidColor = (uColor1.rgb * (m1 + m3 * 0.5) + uColor2.rgb * (m2 + m3 * 0.5)) / totalM;

    // Vertical mask: strongest around upper half, dissolving before title and controls
    float verticalMask = smoothstep(0.92, 0.22, uv.y);
    float fieldIntensity = clamp((m1 * 1.1 + m2 * 1.0 + m3 * 0.7) * verticalMask * uIntensity, 0.0, 1.0);

    vec3 finalRgb = mix(uColorBase.rgb, fluidColor, fieldIntensity * 0.70);

    // Subtle atmospheric top glow
    float topGlow = exp(-uv.y * 3.0) * 0.14 * uIntensity;
    finalRgb += uColor1.rgb * topGlow;

    fragColor = vec4(clamp(finalRgb, 0.0, 1.0), 1.0);
}

// common.hlsl — shared constants for the hlsl-lighting library.
// Ported from gokayfem/shader-skills (GLSL, MIT) — see SKILL.md for the port notes
// and the GLSL->HLSL matrix-multiply translation rule used throughout this library.

static const float PI  = 3.14159265358979323846;
static const float TAU = 6.28318530717958647693;

// HLSL already has `saturate(x)` built in for scalar/float2/3/4 — the ported
// library's GLSL `saturate()` wrapper around clamp(x,0,1) is not re-declared.

// Squared length. Use: cheap distance comparisons, SDF internals.
float Dot2(float2 v) { return dot(v, v); }
float Dot2(float3 v) { return dot(v, v); }

// 2D rotation "matrix": apply with mul(v, Rot2(a)), NOT mul(Rot2(a), v) — see
// SKILL.md's GLSL->HLSL matrix rule. mul(v, Rot2(a)) rotates v counter-clockwise
// by a radians, matching GLSL's `rot2(a) * v`.
// (cos, sin) is renormalized since trig precision varies slightly across GPUs.
// Use: spinning parts, posing limbs, rotating octaves, camera roll.
float2x2 Rot2(float a)
{
    float2 cs = normalize(float2(cos(a), sin(a)));
    return float2x2(cs.x, cs.y, -cs.y, cs.x);
}

// Linear remap of x from [a,b] to [c,d] (unclamped).
// Use: converting ranges, rescaling noise.
float Remap(float x, float a, float b, float c, float d)
{
    return c + (d - c) * (x - a) / (b - a);
}

// Linear ramp from 0 at a to 1 at b, clamped.
// Use: masks whose falloff should not ease in or out.
float Linearstep(float a, float b, float x)
{
    return saturate((x - a) / (b - a));
}

// Smooth bump: 1 at x == c, falling to 0 at |x - c| >= w (cubic).
// Use: stripes, rings, highlights at one height, pulses in time.
float CubicPulse(float c, float w, float x)
{
    x = abs(x - c);
    if (x > w) return 0.0;
    x /= w;
    return 1.0 - x * x * (3.0 - 2.0 * x);
}

// Fast attack, exponential decay. Peaks at 1 when x == 1/k.
// Use: heartbeat motion, impacts, flashes, plucked-string envelopes.
float ExpImpulse(float x, float k)
{
    float h = k * x;
    return h * exp(1.0 - h);
}

// Contrast curve on [0,1] that keeps 0, 0.5 and 1 fixed. k > 1 adds contrast, k < 1 flattens.
// Use: tightening masks, adjusting animation easing.
float Gain(float x, float k)
{
    float a = 0.5 * pow(2.0 * ((x < 0.5) ? x : 1.0 - x), k);
    return (x < 0.5) ? a : 1.0 - a;
}

// 0 at x = 0 and x = 1, peak 1 at x = 0.5; k sharpens.
// Use: petal width along length, leaf profiles, arches.
float Parabola(float x, float k)
{
    return pow(4.0 * x * (1.0 - x), k);
}

// Returns x when x > m; smoothly bottoms out at n when x -> 0. Needs 2n < m.
// Use: avoiding hard zero in falloffs, soft floor on thickness.
float AlmostIdentity(float x, float m, float n)
{
    if (x > m) return x;
    float a = 2.0 * n - m;
    float b = 2.0 * m - 3.0 * n;
    float t = x / m;
    return (a * t + b) * t * t + n;
}

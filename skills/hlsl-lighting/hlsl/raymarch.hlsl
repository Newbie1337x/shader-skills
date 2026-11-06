// raymarch.hlsl — sphere tracing, normals, soft shadows and ambient occlusion
// for SDF scenes. Ported to HLSL from gokayfem/shader-skills' raymarch.glsl
// (GLSL, MIT). See SKILL.md for port notes.
// requires: none (the host shader provides Map(), see the contract below)
//
// SCENE CONTRACT: the including shader defines
//     float2 Map(float3 p);   // returns float2(distance, materialId)
// Packing the material into a float2 keeps every helper here generic.
//
// The GLSL source loops from `ZERO` (= min(iFrame, 0), always 0 but opaque to
// the compiler) instead of a literal 0, purely to stop the Shadertoy/WebGL
// GLSL compiler from inlining Map() into every loop iteration — that trick
// doesn't exist in HLSL and there's no iFrame equivalent. Loops below start
// at a plain 0; if FXC/DXC compile times or unrolling become a problem on a
// large Map(), add the `[loop]` attribute to the for-loop instead.

static const int RAYMARCH_MAX_STEPS = 256;

// Sphere-trace from ro along unit rd between tmin and tmax.
// Returns float3(t, materialId, stepCount). t is -1 on a miss.
// The hit threshold grows with t (about one pixel's footprint), so distant
// surfaces don't burn steps. stepScale is 1 for exact or bound fields; use < 1
// (e.g. 0.6) when Map() has Lipschitz > 1 (displacement, warps, twist).
// Use: every SDF raymarcher. See: https://iquilezles.org/articles/raymarchingdf/
float3 Raymarch(float3 ro, float3 rd, float tmin, float tmax, float stepScale)
{
    float t = tmin;
    [loop]
    for (int i = 0; i < RAYMARCH_MAX_STEPS; i++) {
        float2 h = Map(ro + rd * t);
        if (abs(h.x) < max(0.0002 * t, 1e-5)) return float3(t, h.y, float(i));
        t += h.x * stepScale;
        if (t > tmax) break;
    }
    return float3(-1.0, -1.0, float(RAYMARCH_MAX_STEPS));
}

// Surface normal from 4 tetrahedral samples (cheaper than 6 central
// differences, still centered). eps should scale with distance, e.g.
// 0.0005 * t: filters distant detail and avoids sparkling.
// Use: shading any SDF hit. See: https://iquilezles.org/articles/normalsSDF/
float3 CalcNormal(float3 p, float eps)
{
    float3 n = float3(0.0, 0.0, 0.0);
    [unroll]
    for (int i = 0; i < 4; i++) {
        float3 e = 0.5773 * (2.0 * float3((((i + 3) >> 1) & 1), ((i >> 1) & 1), (i & 1)) - 1.0);
        n += e * Map(p + e * eps).x;
    }
    return normalize(n);
}

// Soft shadow toward a light along unit rd. k controls sharpness (about
// 1 / light angular size: 8 soft, 32 hard). Uses the "closest approach
// between samples" estimate, which removes banding from sharp-cornered occluders.
// Returns 0 (full shadow) .. 1 (lit).
// Use: sun shadows, contact shadows, penumbrae. See: https://iquilezles.org/articles/rmshadows/
float SoftShadow(float3 ro, float3 rd, float tmin, float tmax, float k)
{
    float res = 1.0;
    float t = tmin;
    float ph = 1e10;
    [loop]
    for (int i = 0; i < 64; i++) {
        float h = Map(ro + rd * t).x;
        if (h < 0.0001) return 0.0;
        float y = h * h / (2.0 * ph);
        float d = sqrt(max(h * h - y * y, 0.0));
        res = min(res, k * d / max(t - y, 1e-4));
        ph = h;
        t += clamp(h, 0.005, 0.5);
        if (res < 0.001 || t > tmax) break;
    }
    res = saturate(res);
    return res * res * (3.0 - 2.0 * res);
}

// Ambient occlusion from 5 distance samples along the normal. Compares the
// expected distance with the actual one. scale is the sampling reach in
// scene units (about 0.12 for a unit-sized object). Returns 0 (occluded) .. 1 (open).
// Use: crevices, contact darkening, grounding objects on floors.
// See: https://iquilezles.org/articles/nvscene2008/rwwtt.pdf
float CalcAO(float3 p, float3 n, float scale)
{
    float occ = 0.0;
    float weight = 1.0;
    [unroll]
    for (int i = 0; i < 5; i++) {
        float h = 0.01 + scale * float(i) / 4.0;
        float d = Map(p + h * n).x;
        occ += (h - d) * weight;
        weight *= 0.95;
    }
    return saturate(1.0 - 3.0 * occ / max(scale / 0.12, 1e-3));
}

// Thickness behind a surface point, estimated by sampling the SDF inside
// along -n (an "inverse AO"). Returns 0 (thin, light passes through) .. 1
// (thick). maxDepth is the deepest sample in scene units.
// Use: translucency, subsurface tint, wax and jade, glowing thin edges.
float SdfThickness(float3 p, float3 n, float maxDepth)
{
    float acc = 0.0;
    [unroll]
    for (int i = 0; i < 4; i++) {
        float h = maxDepth * (float(i) + 1.0) / 4.0;
        acc += saturate(-Map(p - n * h).x / h);
    }
    return acc / 4.0;
}

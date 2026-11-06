// architecture.hlsl — stable building parameters and filtered facade fields.
// Ported to HLSL from gokayfem/shader-skills' architecture.glsl (GLSL, MIT).
// See SKILL.md for port notes.
// requires: hash.hlsl (Hash32, Hash12)
//
// Massing/material helpers, not a mesh generator or a full shape-grammar engine.
// Keep the generated footprint inside its parcel.

// Stable building profile: float4(height, half-width, half-depth, roof style
// 0/1/2) from an integer parcel ID. The same ID always gives the same profile.
// Use: city blocks, towers, deterministic chunk generation, architectural massing.
// See: Mueller et al., "Procedural Modeling of Buildings", SIGGRAPH 2006.
float4 BuildingProfile(float2 parcel, float2 heightRange, float2 halfWidthRange)
{
    float3 h = Hash32(parcel);
    return float4(lerp(heightRange.x, heightRange.y, h.x * h.x),
                  lerp(halfWidthRange.x, halfWidthRange.y, h.y),
                  lerp(halfWidthRange.x, halfWidthRange.y, h.z),
                  floor(3.0 * Hash12(parcel + float2(83.0, 19.0))));
}

// Box-filtered rectangular windows centered on integer facade coordinates.
// fill is the opening fraction per cell in [0,1]; footprint is the pixel's
// width/height in cell units. At large footprints it converges to fill.x*fill.y.
// Use: distant city facades, office windows, floor bands, architectural grids without moire. Range [0,1].
// See: https://iquilezles.org/articles/filterableprocedurals/
float FacadeWindowMask(float2 uv, float2 fill, float2 footprint)
{
    fill = saturate(fill);
    float2 w = max(footprint, float2(0.0001, 0.0001));
    float2 a = uv + 0.5 * fill + 0.5 * w;
    float2 b = uv + 0.5 * fill - 0.5 * w;
    float2 ia = floor(a) * fill + min(frac(a), fill);
    float2 ib = floor(b) * fill + min(frac(b), fill);
    float2 coverage = saturate((ia - ib) / w);
    return coverage.x * coverage.y;
}

// hash.hlsl — integer hashes and float wrappers for lattice ids, ported to HLSL
// from gokayfem/shader-skills' hash.glsl (GLSL, MIT). See SKILL.md for port notes.
// requires: none
//
// Naming: HashNM returns N floats from M inputs (Hash12 = 1 output, 2 inputs).
// Outputs are in [0,1). The float wrappers hash INTEGER-VALUED inputs (cell ids,
// pixel coords, frame numbers) — fractional parts are dropped deliberately.
// Integer mixers are pcg3d/pcg4d (Jarzynski & Olano, JCGT 2020) — bit-exact on
// every GPU/driver, unlike sin()-based hashes.

// PCG-style 1D integer hash. Use: seeding, per-instance randomness, other hashes.
uint PcgHash(uint v)
{
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

// 3D integer hash, three decorrelated outputs. Use: 3D cell ids, voxel jitter.
uint3 Pcg3D(uint3 v)
{
    v = v * 1664525u + 1013904223u;
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v ^= v >> 16u;
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    return v;
}

// 4D integer hash, four decorrelated outputs. Use: (pixel, frame, sample) streams.
uint4 Pcg4D(uint4 v)
{
    v = v * 1664525u + 1013904223u;
    v.x += v.y * v.w;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v.w += v.y * v.z;
    v ^= v >> 16u;
    v.x += v.y * v.w;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v.w += v.y * v.z;
    return v;
}

// Map a uint to [0,1) using the top 24 bits, so the result can never round up to 1.0.
float UintToUnit(uint h) { return float(h >> 8u) * (1.0 / 16777216.0); }
float2 UintToUnit(uint2 h) { return float2(h >> 8u) * (1.0 / 16777216.0); }
float3 UintToUnit(uint3 h) { return float3(h >> 8u) * (1.0 / 16777216.0); }
float4 UintToUnit(uint4 h) { return float4(h >> 8u) * (1.0 / 16777216.0); }

// Random float in [0,1) for an integer-valued input. Use: per-cell randomness.
float Hash11(float p) { return UintToUnit(PcgHash(uint(int(floor(p))))); }

// Random float in [0,1) for an integer-valued 2D input.
// Use: per-cell variation (color, height, rotation), sparse spots, star fields.
float Hash12(float2 p)
{
    uint2 q = uint2(int2(floor(p)));
    return UintToUnit(PcgHash(q.x + PcgHash(q.y)));
}

// Random float in [0,1) for an integer-valued 3D input.
// Use: per-voxel randomness, per-pixel-per-frame noise via Hash13(float3(pixel, frameNumber)).
float Hash13(float3 p)
{
    uint3 q = uint3(int3(floor(p)));
    return UintToUnit(PcgHash(q.x + PcgHash(q.y + PcgHash(q.z))));
}

// Random float2 in [0,1)^2 for an integer-valued 2D input. Use: Voronoi feature points, 2D jitter.
float2 Hash22(float2 p)
{
    int2 q = int2(floor(p));
    return UintToUnit(Pcg3D(uint3(q.x, q.y, 0x2545u))).xy;
}

// Random float3 in [0,1)^3 for an integer-valued 3D input. Use: 3D Voronoi points, random colors per cell.
float3 Hash33(float3 p) { return UintToUnit(Pcg3D(uint3(int3(floor(p))))); }

// Random float4 in [0,1)^4 for an integer-valued 4D input. Use: per-pixel/frame/sample random numbers.
float4 Hash44(float4 p) { return UintToUnit(Pcg4D(uint4(int4(floor(p))))); }

// Random float3 in [0,1)^3 for an integer-valued 2D input.
// Use: per-tile random color, per-cell (offset, rotation, scale) triples.
float3 Hash32(float2 p)
{
    int2 q = int2(floor(p));
    return UintToUnit(Pcg3D(uint3(q.x, q.y, 0x9E37u)));
}

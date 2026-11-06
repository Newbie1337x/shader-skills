// noise.hlsl — value, gradient and simplex noise (2D/3D, analytic derivatives),
// fBm, turbulence and billow, domain warping, curl flow, Voronoi, dithering.
// Ported to HLSL from gokayfem/shader-skills' noise.glsl (GLSL, MIT). See
// SKILL.md for port notes.
// requires: common.hlsl (TAU, Rot2, Dot2), hash.hlsl (Hash12, Hash13, Hash22, Hash33)
//
// Texture-free. Noise built on integer hashes stays stable at large
// coordinates until float precision runs out (|p| around 1e5). Re-center
// long animations with fmod/frac on time.

// Quintic fade 6t^5 - 15t^4 + 10t^3: C2-continuous interpolation weights for lattice noise.
float2 QuinticFade(float2 f) { return f * f * f * (f * (f * 6.0 - 15.0) + 10.0); }
float3 QuinticFade(float3 f) { return f * f * f * (f * (f * 6.0 - 15.0) + 10.0); }

// Derivative of QuinticFade: 30 t^2 (t - 1)^2.
float2 QuinticFadeDeriv(float2 f) { return 30.0 * f * f * (f * (f - 2.0) + 1.0); }
float3 QuinticFadeDeriv(float3 f) { return 30.0 * f * f * (f * (f - 2.0) + 1.0); }

// 2D value noise with analytic derivatives. Returns float3(value, d/dx, d/dy).
// Use: terrain base layers, cheap clouds, anything needing normals without finite differences. Range [0,1].
float3 ValueNoiseD(float2 p)
{
    float2 i = floor(p), f = frac(p);
    float2 u = QuinticFade(f), du = QuinticFadeDeriv(f);
    float a = Hash12(i);
    float b = Hash12(i + float2(1.0, 0.0));
    float c = Hash12(i + float2(0.0, 1.0));
    float d = Hash12(i + float2(1.0, 1.0));
    float k1 = b - a, k2 = c - a, k3 = a - b - c + d;
    return float3(a + k1 * u.x + k2 * u.y + k3 * u.x * u.y,
                  du * float2(k1 + k3 * u.y, k2 + k3 * u.x));
}

// 2D value noise. Use: soft blotches, low-frequency color variation. Range [0,1].
float ValueNoise(float2 p) { return ValueNoiseD(p).x; }

// 3D value noise. Use: volumetric density, animated 2D noise (use z = time). Range [0,1].
float ValueNoise(float3 p)
{
    float3 i = floor(p), f = frac(p);
    float3 u = QuinticFade(f);
    return lerp(lerp(lerp(Hash13(i + float3(0, 0, 0)), Hash13(i + float3(1, 0, 0)), u.x),
                     lerp(Hash13(i + float3(0, 1, 0)), Hash13(i + float3(1, 1, 0)), u.x), u.y),
                lerp(lerp(Hash13(i + float3(0, 0, 1)), Hash13(i + float3(1, 0, 1)), u.x),
                     lerp(Hash13(i + float3(0, 1, 1)), Hash13(i + float3(1, 1, 1)), u.x), u.y), u.z);
}

// Unit gradient for a 2D lattice point.
float2 LatticeGradient(float2 cell)
{
    float a = TAU * Hash12(cell);
    return float2(cos(a), sin(a));
}

// 2D gradient (Perlin-style) noise with analytic derivatives. Returns float3(value, d/dx, d/dy).
// Less grid-aligned blockiness than value noise; prefer it for fBm.
// Use: fBm, terrain with analytic normals, curl flow, marble and wood distortions. Range about [-0.7,0.7].
float3 GradientNoiseD(float2 p)
{
    float2 i = floor(p), f = frac(p);
    float2 u = QuinticFade(f), du = QuinticFadeDeriv(f);
    float2 ga = LatticeGradient(i);
    float2 gb = LatticeGradient(i + float2(1.0, 0.0));
    float2 gc = LatticeGradient(i + float2(0.0, 1.0));
    float2 gd = LatticeGradient(i + float2(1.0, 1.0));
    float va = dot(ga, f);
    float vb = dot(gb, f - float2(1.0, 0.0));
    float vc = dot(gc, f - float2(0.0, 1.0));
    float vd = dot(gd, f - float2(1.0, 1.0));
    float k = va - vb - vc + vd;
    float value = va + u.x * (vb - va) + u.y * (vc - va) + u.x * u.y * k;
    float2 deriv = ga + u.x * (gb - ga) + u.y * (gc - ga) + u.x * u.y * (ga - gb - gc + gd)
                 + du * (float2(vb - va, vc - va) + u.yx * k);
    return float3(value, deriv);
}

// 2D gradient noise. Use: general-purpose smooth noise. Range about [-0.7,0.7].
float GradientNoise(float2 p) { return GradientNoiseD(p).x; }

// 2D simplex noise with analytic gradient. Returns float3(value, d/dx, d/dy).
// rotation (radians) spins every lattice gradient; animating it gives flow
// noise that churns in place instead of sliding (Perlin & Neyret 2001).
// Use: flowing water/lava (animate rotation), ripples with analytic normals, isotropic fBm. Range [-1,1].
float3 SimplexNoiseD(float2 p, float rotation)
{
    const float SKEW = 0.36602540378;
    const float UNSKEW = 0.21132486541;
    float2 cell = floor(p + (p.x + p.y) * SKEW);
    float2 d0 = p - cell + (cell.x + cell.y) * UNSKEW;
    float2 o = (d0.x > d0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float2 corners[3] = { cell, cell + o, cell + 1.0 };
    float2 offsets[3] = { d0, d0 - o + UNSKEW, d0 - 1.0 + 2.0 * UNSKEW };
    float2x2 spin = Rot2(rotation);
    float3 sum = float3(0.0, 0.0, 0.0);
    for (int k = 0; k < 3; k++) {
        float2 d = offsets[k];
        float t = max(0.5 - dot(d, d), 0.0);
        float2 g = mul(LatticeGradient(corners[k]), spin);
        float gd = dot(g, d);
        float t3 = t * t * t;
        sum += float3(t3 * t * gd, t3 * t * g - 8.0 * t3 * gd * d);
    }
    return 99.2 * sum;
}
float3 SimplexNoiseD(float2 p) { return SimplexNoiseD(p, 0.0); }

// 2D simplex noise. Use: isotropic smooth noise, fBm layers without grid alignment. Range [-1,1].
float SimplexNoise(float2 p) { return SimplexNoiseD(p, 0.0).x; }

// Dot product of a hashed 3D gradient with the offset to its lattice corner.
float LatticeGradDot(float3 cell, float3 corner, float3 f)
{
    float3 g = Hash33(cell + corner) * 2.0 - 1.0;
    return dot(g, f - corner);
}

// 3D gradient noise. Use: clouds, smoke, solid textures (marble, wood), animated 2D noise (z = time). Range about [-1,1].
float GradientNoise(float3 p)
{
    float3 i = floor(p), f = frac(p);
    float3 u = QuinticFade(f);
    return lerp(lerp(lerp(LatticeGradDot(i, float3(0, 0, 0), f), LatticeGradDot(i, float3(1, 0, 0), f), u.x),
                     lerp(LatticeGradDot(i, float3(0, 1, 0), f), LatticeGradDot(i, float3(1, 1, 0), f), u.x), u.y),
                lerp(lerp(LatticeGradDot(i, float3(0, 0, 1), f), LatticeGradDot(i, float3(1, 0, 1), f), u.x),
                     lerp(LatticeGradDot(i, float3(0, 1, 1), f), LatticeGradDot(i, float3(1, 1, 1), f), u.x), u.y), u.z);
}

// 3D gradient noise with analytic derivatives. Returns float4(value, d/dx, d/dy, d/dz);
// value equals GradientNoise(p).
// Use: normals of noise-displaced surfaces without extra samples, 3D curl flow, slope-aware 3D fBm. Range about [-1,1].
float4 GradientNoiseD(float3 p)
{
    float3 i = floor(p), f = frac(p);
    float3 u = QuinticFade(f), du = QuinticFadeDeriv(f);
    float3 g000 = Hash33(i) * 2.0 - 1.0;
    float3 g100 = Hash33(i + float3(1, 0, 0)) * 2.0 - 1.0;
    float3 g010 = Hash33(i + float3(0, 1, 0)) * 2.0 - 1.0;
    float3 g110 = Hash33(i + float3(1, 1, 0)) * 2.0 - 1.0;
    float3 g001 = Hash33(i + float3(0, 0, 1)) * 2.0 - 1.0;
    float3 g101 = Hash33(i + float3(1, 0, 1)) * 2.0 - 1.0;
    float3 g011 = Hash33(i + float3(0, 1, 1)) * 2.0 - 1.0;
    float3 g111 = Hash33(i + float3(1, 1, 1)) * 2.0 - 1.0;
    float v000 = dot(g000, f);
    float v100 = dot(g100, f - float3(1, 0, 0));
    float v010 = dot(g010, f - float3(0, 1, 0));
    float v110 = dot(g110, f - float3(1, 1, 0));
    float v001 = dot(g001, f - float3(0, 0, 1));
    float v101 = dot(g101, f - float3(1, 0, 1));
    float v011 = dot(g011, f - float3(0, 1, 1));
    float v111 = dot(g111, f - float3(1, 1, 1));
    float kx = v100 - v000, ky = v010 - v000, kz = v001 - v000;
    float kxy = v000 - v100 - v010 + v110;
    float kyz = v000 - v010 - v001 + v011;
    float kzx = v000 - v100 - v001 + v101;
    float kxyz = -v000 + v100 + v010 - v110 + v001 - v101 - v011 + v111;
    float value = v000 + kx * u.x + ky * u.y + kz * u.z
                + kxy * u.x * u.y + kyz * u.y * u.z + kzx * u.z * u.x + kxyz * u.x * u.y * u.z;
    float3 grad = g000 + (g100 - g000) * u.x + (g010 - g000) * u.y + (g001 - g000) * u.z
                + (g000 - g100 - g010 + g110) * u.x * u.y
                + (g000 - g010 - g001 + g011) * u.y * u.z
                + (g000 - g100 - g001 + g101) * u.z * u.x
                + (-g000 + g100 + g010 - g110 + g001 - g101 - g011 + g111) * u.x * u.y * u.z
                + du * float3(kx + kxy * u.y + kzx * u.z + kxyz * u.y * u.z,
                              ky + kxy * u.x + kyz * u.z + kxyz * u.x * u.z,
                              kz + kyz * u.y + kzx * u.x + kxyz * u.x * u.y);
    return float4(value, grad);
}

static const int FBM_MAX_OCTAVES = 12;

// Fractional Brownian motion over 2D gradient noise. Each octave is rotated
// to hide lattice alignment. persistence 0.5 is the classic look (H = 1).
// Use: clouds, terrain, dirt, roughness breakup, warping input. Range about [-1,1].
float Fbm(float2 p, int octaves, float lacunarity, float persistence)
{
    const float2x2 octaveRotation = float2x2(0.8, 0.6, -0.6, 0.8);
    float sum = 0.0, amp = 1.0, norm = 0.0;
    for (int i = 0; i < FBM_MAX_OCTAVES; i++) {
        if (i >= octaves) break;
        sum += amp * GradientNoise(p);
        norm += amp;
        amp *= persistence;
        p = lacunarity * mul(p, octaveRotation) + float2(17.13, -3.71);
    }
    return 1.4 * sum / norm;
}

// 2D fBm with the usual defaults (lacunarity 2.01, persistence 0.5).
// Use: quick organic variation. Range about [-1,1].
float Fbm(float2 p, int octaves) { return Fbm(p, octaves, 2.01, 0.5); }

// fBm over 3D gradient noise. Use: clouds, smoke, nebulae, solid marble. Range about [-1,1].
float Fbm(float3 p, int octaves, float lacunarity, float persistence)
{
    const float3x3 octaveRotation = float3x3(0.00, 0.80, 0.60,
                                              -0.80, 0.36, -0.48,
                                              -0.60, -0.48, 0.64);
    float sum = 0.0, amp = 1.0, norm = 0.0;
    for (int i = 0; i < FBM_MAX_OCTAVES; i++) {
        if (i >= octaves) break;
        sum += amp * GradientNoise(p);
        norm += amp;
        amp *= persistence;
        p = lacunarity * mul(p, octaveRotation) + float3(17.13, -3.71, 5.29);
    }
    return sum / norm;
}

// Terrain fBm where each octave is damped by the accumulated slope, so detail
// settles in valleys and steep slopes stay smooth — an eroded look without simulation.
// Use: mountains, dunes, rocky ground. Range about [-0.5,1].
float ErodedFbm(float2 p, int octaves)
{
    const float2x2 octaveRotation = float2x2(0.8, 0.6, -0.6, 0.8);
    float h = 0.0, amp = 0.5;
    float2 slope = float2(0.0, 0.0);
    for (int i = 0; i < FBM_MAX_OCTAVES; i++) {
        if (i >= octaves) break;
        float3 n = GradientNoiseD(p);
        slope += n.yz;
        h += amp * n.x / (1.0 + dot(slope, slope));
        amp *= 0.5;
        p = 2.0 * mul(p, octaveRotation);
    }
    return 2.0 * h;
}

// Ridged multifractal: inverted |noise| creates sharp crests; each octave is
// weighted by the previous one, so detail gathers along ridges.
// Use: mountain ridges, lightning-like veins, canyons, eroded rock, alien landscapes. Range about [0,1].
float RidgedFbm(float2 p, int octaves)
{
    const float2x2 octaveRotation = float2x2(0.8, 0.6, -0.6, 0.8);
    float sum = 0.0, amp = 0.5, weight = 1.0, norm = 0.0;
    for (int i = 0; i < FBM_MAX_OCTAVES; i++) {
        if (i >= octaves) break;
        float n = 1.0 - abs(GradientNoise(p) * 1.4);
        n *= n;
        sum += amp * n * weight;
        norm += amp;
        weight = saturate(n * 2.0);
        amp *= 0.5;
        p = 2.01 * mul(p, octaveRotation) + float2(17.13, -3.71);
    }
    return sum / norm;
}

// Perlin's turbulence: fBm of |noise|. The absolute value folds every zero
// crossing into a sharp crease, at every scale.
// Use: fire, marble veins (sin(x + k*turbulence)), smoke wisps, electric glow, lava cracks. Range [0,1].
float Turbulence(float2 p, int octaves)
{
    const float2x2 octaveRotation = float2x2(0.8, 0.6, -0.6, 0.8);
    float sum = 0.0, amp = 1.0, norm = 0.0;
    for (int i = 0; i < FBM_MAX_OCTAVES; i++) {
        if (i >= octaves) break;
        sum += amp * abs(GradientNoise(p));
        norm += amp;
        amp *= 0.5;
        p = 2.01 * mul(p, octaveRotation) + float2(17.13, -3.71);
    }
    return 1.4 * sum / norm;
}
float Turbulence(float3 p, int octaves)
{
    const float3x3 octaveRotation = float3x3(0.00, 0.80, 0.60,
                                              -0.80, 0.36, -0.48,
                                              -0.60, -0.48, 0.64);
    float sum = 0.0, amp = 1.0, norm = 0.0;
    for (int i = 0; i < FBM_MAX_OCTAVES; i++) {
        if (i >= octaves) break;
        sum += amp * min(abs(GradientNoise(p)), 1.0);
        norm += amp;
        amp *= 0.5;
        p = 2.01 * mul(p, octaveRotation) + float3(17.13, -3.71, 5.29);
    }
    return sum / norm;
}

// Billowy multifractal: |noise| per octave makes puffy rounded lobes split by
// sharp creases (the inverse of RidgedFbm).
// Use: cumulus/cauliflower tops, puffy smoke, foam clumps, rock piles, cotton. Range [0,1].
float BillowFbm(float2 p, int octaves)
{
    const float2x2 octaveRotation = float2x2(0.8, 0.6, -0.6, 0.8);
    float sum = 0.0, amp = 0.5, weight = 1.0, norm = 0.0;
    for (int i = 0; i < FBM_MAX_OCTAVES; i++) {
        if (i >= octaves) break;
        float n = abs(GradientNoise(p) * 1.4);
        n = n * (2.0 - n);
        sum += amp * n * weight;
        norm += amp;
        weight = saturate(n * 1.5);
        amp *= 0.5;
        p = 2.01 * mul(p, octaveRotation) + float2(17.13, -3.71);
    }
    return sum / norm;
}
float BillowFbm(float3 p, int octaves)
{
    const float3x3 octaveRotation = float3x3(0.00, 0.80, 0.60,
                                              -0.80, 0.36, -0.48,
                                              -0.60, -0.48, 0.64);
    float sum = 0.0, amp = 0.5, weight = 1.0, norm = 0.0;
    for (int i = 0; i < FBM_MAX_OCTAVES; i++) {
        if (i >= octaves) break;
        float n = min(abs(GradientNoise(p)) * 1.4, 1.0);
        n = n * (2.0 - n);
        sum += amp * n * weight;
        norm += amp;
        weight = saturate(n * 1.5);
        amp *= 0.5;
        p = 2.01 * mul(p, octaveRotation) + float3(17.13, -3.71, 5.29);
    }
    return sum / norm;
}

// Two-level domain warp f(p + s*r), r = fbm(p + s*q), q = fbm(p). Writes the
// intermediate warp vectors so they can drive color. Cost is 5 fBm calls.
// Use: marble, smoke, agate, alien skies, painterly backgrounds. Range about [-1,1].
float WarpedFbm(float2 p, float strength, int octaves, out float2 q, out float2 r)
{
    q = float2(Fbm(p, octaves), Fbm(p + float2(3.1, 7.4), octaves));
    r = float2(Fbm(p + strength * q + float2(9.7, 2.6), octaves),
               Fbm(p + strength * q + float2(6.3, 1.9), octaves));
    return Fbm(p + strength * r, octaves);
}

// Divergence-free 2D flow field: the curl of scalar gradient noise. Particles
// advected by it swirl without bunching up.
// Use: smoke advection, flowing paint, hair/fur flow direction, wind.
float2 CurlNoise(float2 p)
{
    float3 n = GradientNoiseD(p);
    return float2(n.z, -n.y);
}

// Divergence-free 3D flow field: the curl of a vector potential whose
// components are three decorrelated GradientNoiseD fields.
// Use: smoke/fire advection, swirling particles and sparks, wisps, magic trails.
float3 CurlNoise(float3 p)
{
    float3 a = GradientNoiseD(p).yzw;
    float3 b = GradientNoiseD(p + float3(31.416, -47.853, 12.793)).yzw;
    float3 c = GradientNoiseD(p + float3(-23.719, 18.274, -56.183)).yzw;
    return float3(c.y - b.z, a.z - c.x, b.x - a.y);
}

// Cellular (Worley/Voronoi) noise. Returns float4(F1, F2, nearestCell.xy).
// F1 = distance to nearest feature point, F2 = second nearest. jitter in [0,1]
// (0 = regular grid). Searches 3x3 cells.
// Use: cells, scales, stones, cracked mud (F2-F1), caustics, foam, sparkles. Range F1 in [0, ~1.2].
float4 Voronoi(float2 p, float jitter)
{
    float2 ip = floor(p), fp = frac(p);
    float f1 = 8.0, f2 = 8.0;
    float2 nearest = float2(0.0, 0.0);
    for (int j = -1; j <= 1; j++)
    for (int i = -1; i <= 1; i++) {
        float2 g = float2(float(i), float(j));
        float2 r = g + jitter * Hash22(ip + g) - fp;
        float d = dot(r, r);
        if (d < f1) { f2 = f1; f1 = d; nearest = ip + g; }
        else if (d < f2) { f2 = d; }
    }
    return float4(sqrt(f1), sqrt(f2), nearest);
}

// Exact distance to Voronoi cell borders, found in two passes: nearest point,
// then nearest bisector. Returns float3(borderDistance, vectorToNearestPoint).
// Use: cell walls, stained glass leading, cracked earth, leaf-vein patterns, crackle glaze.
float3 VoronoiBorder(float2 p, float jitter)
{
    float2 ip = floor(p), fp = frac(p);
    float2 mg = float2(0.0, 0.0), mr = float2(0.0, 0.0);
    float md = 8.0;
    for (int j = -1; j <= 1; j++)
    for (int i = -1; i <= 1; i++) {
        float2 g = float2(float(i), float(j));
        float2 r = g + jitter * Hash22(ip + g) - fp;
        float d = dot(r, r);
        if (d < md) { md = d; mr = r; mg = g; }
    }
    md = 8.0;
    for (int j = -2; j <= 2; j++)
    for (int i = -2; i <= 2; i++) {
        float2 g = mg + float2(float(i), float(j));
        float2 r = g + jitter * Hash22(ip + g) - fp;
        if (Dot2(mr - r) > 1e-5) {
            md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
        }
    }
    return float3(md, mr);
}

// Smooth Voronoi: a soft-min of distances to feature points. Cells become
// blobs with no creases. k controls smoothness (large = sharper; ~8-32).
// Searches 5x5 cells so low k has no seams.
// Use: organic cell clusters, bubbles, lumpy surfaces, skin pores.
float SmoothVoronoi(float2 p, float k)
{
    float2 ip = floor(p), fp = frac(p);
    float acc = 0.0;
    for (int j = -2; j <= 2; j++)
    for (int i = -2; i <= 2; i++) {
        float2 g = float2(float(i), float(j));
        float2 r = g + Hash22(ip + g) - fp;
        acc += exp2(-k * length(r));
    }
    return -log2(acc) / k;
}

// Bounded hybrid terrain recipe: broad gradient fBm, warped ridged detail and
// cellular breakup. This is an artistic composition, not a named algorithm.
// Use: game heightmaps, rocky islands, biome elevation masks, alien terrain. Range [0,1].
float HybridTerrainHeight(float2 p, int octaves)
{
    int count = clamp(octaves, 1, FBM_MAX_OCTAVES);
    float2 warp = float2(Fbm(p * 0.35, count), Fbm(p * 0.35 + float2(19.1, -7.3), count));
    float2 q = p + 0.8 * warp;
    float broad = 0.5 + 0.5 * Fbm(q * 0.45, count);
    float ridges = RidgedFbm(q * 1.7, count);
    float cells = 1.0 - saturate(Voronoi(q * 2.5, 0.75).x);
    return saturate(0.45 * broad + 0.45 * ridges + 0.10 * cells);
}

// Interleaved gradient noise: cheap per-pixel noise whose 3x3 neighborhoods
// are nearly stratified. Not a hash. pixel must be integer pixel coordinates
// (floor(SV_Position.xy)). The frame overload animates it for accumulation/TAA.
// Use: removing banding before 8-bit output, jittering ray start offsets. Range [0,1).
float InterleavedGradientNoise(float2 pixel)
{
    return frac(52.9829189 * frac(dot(pixel, float2(0.06711056, 0.00583715))));
}
float InterleavedGradientNoise(float2 pixel, int frame)
{
    return InterleavedGradientNoise(pixel + 5.588238 * float(frame % 64));
}

// R2 low-discrepancy dither mask (plastic-constant sequence), folded by a
// triangle wave for an even spread.
// Use: ordered dithering without textures, posterized/retro looks, sample offsets. Range [0,1).
float R2Dither(float2 pixel)
{
    float v = frac(dot(pixel, float2(0.7548776662, 0.5698402910)));
    return v < 0.5 ? 2.0 * v : 2.0 - 2.0 * v;
}

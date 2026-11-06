// operators.hlsl — combine distances (booleans, smooth blends, chamfers,
// stairs) and reshape them (round, onion, extrude, revolve, elongate). Ported
// to HLSL from gokayfem/shader-skills' operators.glsl (GLSL, MIT). See
// SKILL.md for port notes.
// requires: none
//
// Arguments a, b are distances already evaluated at the same point.
// Exactness: union (min) is exact outside but too deep inside; intersection and
// subtraction (max) are exact inside but underestimate outside. Smooth and
// decorative combinations are bounds, all Lipschitz <= 1 (safe to raymarch).
// Smooth unions are not associative: blend in a fixed order.

// Union of two shapes. @bound. Use: combining parts.
float OpUnion(float a, float b) { return min(a, b); }

// Shape a with shape b cut out of it. @bound. Use: holes, windows, carving, bites.
float OpSubtract(float a, float b) { return max(a, -b); }

// Region inside both shapes. @bound. Use: clipping, lens shapes, trimming with half-spaces.
float OpIntersect(float a, float b) { return max(a, b); }

// Smooth union (polynomial, C1). Blends where |a - b| < k, with a max bulge of k/4.
// @bound. Use: organic joins (neck to head, limbs to torso), melting shapes, blobby forms.
float Smin(float a, float b, float k)
{
    float h = saturate(0.5 + 0.5 * (b - a) / k);
    return lerp(b, a, h) - k * h * (1.0 - h);
}

// Smooth intersection, the mirror of Smin. @bound. Use: soft clipping, pillowy cuts.
float Smax(float a, float b, float k) { return -Smin(-a, -b, k); }

// Smooth subtraction: a with b carved out, with filleted edges.
// @bound. Use: eye sockets, nostrils, soft grooves, scooped bowls, worn edges.
float SmoothSubtract(float a, float b, float k) { return Smax(a, -b, k); }

// Smooth union with a C2 (cubic) transition, so specular highlights and
// normals have no visible seam. Blends where |a - b| < k, max bulge k/6.
// @bound. Use: close-up organic surfaces, glossy blends, fluids.
float SminCubic(float a, float b, float k)
{
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * h * k * (1.0 / 6.0);
}

// Smooth union that also returns the blend weight. Returns float2(distance, weight) —
// weight is 1 when fully a, 0 when fully b. Use the weight to mix material colors across the blend.
// @bound. Use: skin-to-cloth transitions, color bleeding across blended parts.
float2 SminBlend(float a, float b, float k)
{
    float h = saturate(0.5 + 0.5 * (b - a) / k);
    return float2(lerp(b, a, h) - k * h * (1.0 - h), h);
}

// Union with a 45-degree chamfer of size r at the seam.
// @bound. Use: machined parts, architecture, sci-fi panels, bevelled joins.
float OpChamferUnion(float a, float b, float r)
{
    return min(min(a, b), (a + b - r) * 0.70710678);
}

// Union with n stair steps of total size r at the seam.
// @bound. Use: terraces, stepped pyramids, ziggurats, layered rock, rice paddies.
float OpStairsUnion(float a, float b, float r, float n)
{
    float s = r / n;
    float u = b - r;
    return min(min(a, b), 0.5 * (u + a + abs(fmod(u - a + s, 2.0 * s) - s)));
}

// Engrave a groove of depth r into a, following the zero set of b.
// @bound. Use: panel lines, carved text paths, seams, grout lines on a surface.
float OpEngrave(float a, float b, float r)
{
    return max(a, (a + r - abs(b)) * 0.70710678);
}

// Round a shape by r. Grows it outward; shrink the inner shape by r first to keep its size.
// @exact. Use: softening any primitive, pebbles from boxes, inflated look.
float OpRound(float d, float r) { return d - r; }

// Hollow shell of thickness 2t around the surface. Apply repeatedly for concentric layers.
// @exact. Use: shells, pipes, rings, onion layers, outlines in 2D.
float OpOnion(float d, float t) { return abs(d) - t; }

// Extrude a 2D distance d2 (evaluated at p.xy) along Z by half-length h.
// @exact. Use: 3D text and logos, cookie cutters, coins from 2D shapes, extruded profiles.
float OpExtrude(float3 p, float d2, float h)
{
    float2 w = float2(d2, abs(p.z) - h);
    return min(max(w.x, w.y), 0.0) + length(max(w, 0.0));
}

// Revolve around Y. Returns the 2D point to evaluate a profile at. Offset o
// moves the profile away from the axis.
// @exact. Use: vases, bottles, chess pieces, lathe-turned objects, tori with custom profiles.
float2 OpRevolve(float3 p, float o) { return float2(length(p.xz) - o, p.y); }

// Elongate: stretch a shape by inserting a straight section of half-size h,
// keeping exact distances inside too. Returns float4(q, w). Evaluate the
// original shape at q.xyz and add w: SdSphere(e.xyz, r) + e.w is a capsule.
// @exact. Use: pills from spheres, long rounded boxes, stretched characters, stadium shapes.
float4 OpElongate(float3 p, float3 h)
{
    float3 q = abs(p) - h;
    return float4(max(q, 0.0), min(max(q.x, max(q.y, q.z)), 0.0));
}

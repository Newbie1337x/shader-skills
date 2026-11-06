// sdf3d.hlsl — 3D signed distance primitives. Ported to HLSL from
// gokayfem/shader-skills' sdf3d.glsl (GLSL, MIT). See SKILL.md for port notes.
// requires: common.hlsl (Dot2), for a couple of functions
//
// Each primitive is centered at the origin unless noted. Move or rotate the
// point before calling (SdBox(p - center, size)), never the result.
// Tags: @exact true Euclidean distance (safe for blending/AO/shadows/offsets),
// @bound never overestimates (Lipschitz <= 1, safe to raymarch),
// @approx exact zero set but may overestimate in places.

// Sphere of radius r. @exact. Use: heads, eyes, fruit, planets, bubbles, joints.
float SdSphere(float3 p, float r) { return length(p) - r; }

// Axis-aligned box with half-extents b. @exact. Use: buildings, crates, bricks, furniture.
float SdBox(float3 p, float3 b)
{
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

// Box with rounded edges. Outer size stays b; r is the edge radius (r <= min(b)).
// @exact. Use: toys, product shots, soft architecture, dice, phone-like slabs.
float SdRoundBox(float3 p, float3 b, float r)
{
    float3 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

// Wireframe box: edges of a box with half-extents b and edge thickness e.
// @exact. Use: scaffolding, cages, display frames, sci-fi structures.
float SdBoxFrame(float3 p, float3 b, float e)
{
    p = abs(p) - b;
    float3 q = abs(p + e) - e;
    return min(min(
        length(max(float3(p.x, q.y, q.z), 0.0)) + min(max(p.x, max(q.y, q.z)), 0.0),
        length(max(float3(q.x, p.y, q.z), 0.0)) + min(max(q.x, max(p.y, q.z)), 0.0)),
        length(max(float3(q.x, q.y, p.z), 0.0)) + min(max(q.x, max(q.y, p.z)), 0.0));
}

// Torus in the XZ plane. t.x = major radius, t.y = tube radius. @exact. Use: rings, donuts, tires, halos.
float SdTorus(float3 p, float2 t)
{
    float2 q = float2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// Partial torus (arc) in the XY plane, symmetric about +Y. sc = float2(sin, cos)
// of the half-aperture angle, ra = major radius, rb = tube radius.
// @exact. Use: horns, handles, eyebrows, arches, croissant shapes, magnets.
float SdCappedTorus(float3 p, float2 sc, float ra, float rb)
{
    p.x = abs(p.x);
    float k = (sc.y * p.x > sc.x * p.y) ? dot(p.xy, sc) : length(p.xy);
    return sqrt(max(dot(p, p) + ra * ra - 2.0 * ra * k, 0.0)) - rb;
}

// Chain link: a torus stretched along Y by le. r1 = major radius, r2 = tube radius.
// @exact. Use: chains, rings, jewelry, fences.
float SdLink(float3 p, float le, float r1, float r2)
{
    float3 q = float3(p.x, max(abs(p.y) - le, 0.0), p.z);
    return length(float2(length(q.xy) - r1, q.z)) - r2;
}

// Infinite plane through the origin offset by h along unit normal n: dot(p, n) + h.
// @exact. Use: ground, walls, water surface, clipping half-spaces.
float SdPlane(float3 p, float3 n, float h) { return dot(p, n) + h; }

// Capsule: segment a-b swept by radius r. @exact. Use: limbs, fingers, branches, hair strands.
float SdCapsule(float3 p, float3 a, float3 b, float r)
{
    float3 pa = p - a, ba = b - a;
    float h = saturate(dot(pa, ba) / dot(ba, ba));
    return length(pa - ba * h) - r;
}

// Vertical capsule from y = 0 to y = h, radius r. @exact. Use: upright limbs, posts, bottles, candles.
float SdVerticalCapsule(float3 p, float h, float r)
{
    p.y -= clamp(p.y, 0.0, h);
    return length(p) - r;
}

// Vertical capped cylinder from y = -h to y = +h, radius r. @exact. Use: columns, cans, coins, logs.
float SdCylinder(float3 p, float h, float r)
{
    float2 d = abs(float2(length(p.xz), p.y)) - float2(r, h);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

// Capped cone (frustum) from y = -h (radius r1) to y = +h (radius r2). Set
// r2 = 0 for a pointed cone. Exact everywhere, including the base cap.
// @exact. Use: trees, roofs, spikes, lampshades, volcanoes, party hats, vases.
float SdCappedCone(float3 p, float h, float r1, float r2)
{
    float2 q = float2(length(p.xz), p.y);
    float2 top = float2(r2, h);
    float2 side = float2(r2 - r1, 2.0 * h);
    float2 toCap = float2(q.x - min(q.x, (q.y < 0.0) ? r1 : r2), abs(q.y) - h);
    float2 toSide = q - top + side * saturate(dot(top - q, side) / Dot2(side));
    float s = (toSide.x < 0.0 && toCap.y < 0.0) ? -1.0 : 1.0;
    return s * sqrt(min(Dot2(toCap), Dot2(toSide)));
}

// Pointed cone with its base disk (radius r) at y = 0 and apex at y = h.
// @exact. Use: evergreen trees, spikes, horns, mountains, wizard hats.
float SdCone(float3 p, float h, float r)
{
    return SdCappedCone(p - float3(0.0, 0.5 * h, 0.0), 0.5 * h, r, 0.0);
}

// Round cone: sphere r1 at y = 0 smoothly hulled with sphere r2 at y = h.
// @exact. Use: limbs, fingers, tree trunks, carrots, teardrops, tentacle segments.
float SdRoundCone(float3 p, float r1, float r2, float h)
{
    float b = (r1 - r2) / h;
    float a = sqrt(1.0 - b * b);
    float2 q = float2(length(p.xz), p.y);
    float k = dot(q, float2(-b, a));
    if (k < 0.0) return length(q) - r1;
    if (k > a * h) return length(q - float2(0.0, h)) - r2;
    return dot(q, float2(a, b)) - r1;
}

// Ellipsoid with semi-axes r. Fast approximation: zero set exact, field is a
// bound outside for aspect ratios up to about 2:1. March with stepScale
// 0.7-0.8 for stretched ellipsoids, or build long shapes from SdCapsule/SdRoundCone instead.
// @approx. Use: heads, bodies, eggs, pebbles, leaves (flat), muscles, clouds of blobs.
float SdEllipsoid(float3 p, float3 r)
{
    float k0 = length(p / r);
    float k1 = length(p / (r * r));
    if (k1 < 1e-8) return -min(r.x, min(r.y, r.z));
    return k0 * (k0 - 1.0) / k1;
}

// Hollow spherical cap (bowl) of radius r, cut by the plane y = h, with shell
// thickness t. The opening faces +Y.
// @exact. Use: bowls, cups, helmets, shells, satellite dishes, eye sockets.
float SdCutHollowSphere(float3 p, float r, float h, float t)
{
    float w = sqrt(r * r - h * h);
    float2 q = float2(length(p.xz), p.y);
    return ((h * q.x < w * q.y) ? length(q - float2(w, h)) : abs(length(q) - r)) - t;
}

// Hexagonal prism along Z. h.x = inradius of the hexagon, h.y = half-length.
// @exact. Use: pencils, bolts, crystals, basalt columns, honeycomb cells.
float SdHexPrism(float3 p, float2 h)
{
    const float3 k = float3(-0.8660254, 0.5, 0.57735027);
    p = abs(p);
    p.xy -= 2.0 * min(dot(k.xy, p.xy), 0.0) * k.xy;
    float2 d = float2(length(p.xy - float2(clamp(p.x, -k.z * h.x, k.z * h.x), h.x)) * sign(p.y - h.x),
                       p.z - h.y);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

// Regular octahedron with "radius" s (vertex distance from center). @bound. Use: gems, crystals, diamonds.
float SdOctahedron(float3 p, float s)
{
    p = abs(p);
    return (p.x + p.y + p.z - s) * 0.57735027;
}

// Gyroid sheet with cell scale `scale` and half-thickness t. The infinite
// triply-periodic surface sin(x)cos(y) + sin(y)cos(z) + sin(z)cos(x) = 0.
// Intersect with a bounding shape.
// @bound. Use: lattices, coral, bone interiors, sponges, sci-fi infill, organic architecture.
float SdGyroid(float3 p, float scale, float t)
{
    p *= scale;
    float g = dot(sin(p), cos(p.yzx));
    return (abs(g) / scale - t) * 0.57735027;
}

// Sphere of radius r cut by the plane y = h, keeping the cap ABOVE the plane.
// h = 0 gives a dome on the ground; negative h keeps more than half. Needs |h| < r.
// @exact. Use: domes, mushroom caps, half-buried rocks, igloos, bread loaves.
float SdCutSphere(float3 p, float r, float h)
{
    float w = sqrt(max(r * r - h * h, 0.0));
    float2 q = float2(length(p.xz), p.y);
    float s = max((h - r) * q.x * q.x + w * w * (h + r - 2.0 * q.y), h * q.x - w * q.y);
    return (s < 0.0) ? length(q) - r : (q.x < w) ? h - q.y : length(q - float2(w, h));
}

// Sphere ra at the origin with sphere rb at (d, 0, 0) carved out, exact
// including the crease rim. A plain OpSubtract of two spheres is only a bound.
// @exact. Use: eye sockets, craters, bitten fruit, nostrils, scooped shapes.
float SdDeathStar(float3 p, float ra, float rb, float d)
{
    float a = (ra * ra - rb * rb + d * d) / (2.0 * d);
    float b = sqrt(max(ra * ra - a * a, 0.0));
    float2 q = float2(p.x, length(p.yz));
    if (q.x * b - q.y * a > d * max(b - q.y, 0.0)) return length(q - float2(a, b));
    return max(length(q) - ra, -(length(q - float2(d, 0.0)) - rb));
}

// Unsigned distance to a 3D quadratic Bezier curve A-B-C; subtract a radius for a tube.
// Solves the closest-point cubic analytically. Falls back to a segment when the curve is straight.
// @exact. Use: hair strands, tentacles, stems, whiskers, horns, cables, curved tubes.
float SdQuadraticBezier(float3 pos, float3 A, float3 B, float3 C)
{
    float3 a = B - A;
    float3 b = A - 2.0 * B + C;
    float3 c = a * 2.0;
    float3 d = A - pos;
    float bb = dot(b, b);
    if (bb < 1e-10) {
        float3 pa = pos - A, ca = C - A;
        return length(pa - ca * saturate(dot(pa, ca) / dot(ca, ca)));
    }
    float kk = 1.0 / bb;
    float kx = kk * dot(a, b);
    float ky = kk * (2.0 * dot(a, a) + dot(d, b)) / 3.0;
    float kz = kk * dot(d, a);
    float pp = ky - kx * kx;
    float q = kx * (2.0 * kx * kx - 3.0 * ky) + kz;
    float h = q * q + 4.0 * pp * pp * pp;
    float res;
    if (h >= 0.0) {
        h = sqrt(h);
        float2 x = (float2(h, -h) - q) / 2.0;
        float2 uv = sign(x) * pow(abs(x), float2(1.0 / 3.0, 1.0 / 3.0));
        float t = saturate(uv.x + uv.y - kx);
        res = Dot2(d + (c + b * t) * t);
    } else {
        float z = sqrt(-pp);
        float v = acos(clamp(q / (pp * z * 2.0), -1.0, 1.0)) / 3.0;
        float m = cos(v);
        float n = sin(v) * 1.7320508;
        float2 t = saturate(float2(m + m, -n - m) * z - kx);
        res = min(Dot2(d + (c + b * t.x) * t.x), Dot2(d + (c + b * t.y) * t.y));
    }
    return sqrt(res);
}

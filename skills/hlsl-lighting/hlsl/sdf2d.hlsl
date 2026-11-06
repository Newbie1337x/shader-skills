// sdf2d.hlsl — 2D signed distance primitives for posters, icons, UI, motion
// graphics, and as profiles for OpExtrude / OpRevolve. Ported to HLSL from
// gokayfem/shader-skills' sdf2d.glsl (GLSL, MIT). See SKILL.md for port notes.
// requires: common.hlsl (Dot2), for a couple of functions
//
// Centered at the origin unless noted. Negative inside.
// Tags: @exact true distance, @bound never overestimates, @approx exact zero
// set but may overestimate in places.

// Circle of radius r. @exact. Use: dots, eyes, suns, bubbles, rings (with OpOnion).
float SdCircle(float2 p, float r) { return length(p) - r; }

// Axis-aligned rectangle with half-extents b. @exact. Use: panels, bars, windows, buttons.
float SdBox(float2 p, float2 b)
{
    float2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// Rectangle with half-extents b and per-corner radii r = (top-right, bottom-right, top-left, bottom-left).
// @exact. Use: UI cards, buttons, speech bubbles, tags, rounded windows.
float SdRoundedBox(float2 p, float2 b, float4 r)
{
    r.xy = (p.x > 0.0) ? r.xy : r.zw;
    r.x = (p.y > 0.0) ? r.x : r.y;
    float2 q = abs(p) - b + r.x;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
}

// Unsigned distance to segment a-b. Subtract a width to get a stroke. @exact. Use: lines, strokes, stems.
float SdSegment(float2 p, float2 a, float2 b)
{
    float2 pa = p - a, ba = b - a;
    float h = saturate(dot(pa, ba) / dot(ba, ba));
    return length(pa - ba * h);
}

// Tapered capsule: circle r1 at origin hulled with circle r2 at (0, h).
// @exact. Use: petals, tails, teardrops, brush dabs, fingers, flames.
float SdUnevenCapsule(float2 p, float r1, float r2, float h)
{
    p.x = abs(p.x);
    float b = (r1 - r2) / h;
    float a = sqrt(1.0 - b * b);
    float k = dot(p, float2(-b, a));
    if (k < 0.0) return length(p) - r1;
    if (k > a * h) return length(p - float2(0.0, h)) - r2;
    return dot(p, float2(a, b)) - r1;
}

// Circular arc symmetric about +Y. sc = float2(sin, cos) of the half-aperture,
// ra = radius, rb = stroke half-width. @exact. Use: smiles, eyebrows, rainbows, gauges.
float SdArc(float2 p, float2 sc, float ra, float rb)
{
    p.x = abs(p.x);
    return ((sc.y * p.x > sc.x * p.y) ? length(p - sc * ra) : abs(length(p) - ra)) - rb;
}

// Equilateral triangle with circumradius-like size r, pointing up.
// @exact. Use: play icons, warning signs, mountains, arrows, tri-patterns.
float SdEquilateralTriangle(float2 p, float r)
{
    const float k = 1.7320508;
    p.x = abs(p.x) - r;
    p.y = p.y + r / k;
    if (p.x + k * p.y > 0.0) p = float2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
    p.x -= clamp(p.x, -2.0 * r, 0.0);
    return -length(p) * sign(p.y);
}

// Arbitrary triangle p0, p1, p2 (any winding). @exact. Use: shards, low-poly art, arrowheads.
float SdTriangle(float2 p, float2 p0, float2 p1, float2 p2)
{
    float2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
    float2 v0 = p - p0, v1 = p - p1, v2 = p - p2;
    float2 pq0 = v0 - e0 * saturate(dot(v0, e0) / dot(e0, e0));
    float2 pq1 = v1 - e1 * saturate(dot(v1, e1) / dot(e1, e1));
    float2 pq2 = v2 - e2 * saturate(dot(v2, e2) / dot(e2, e2));
    float s = sign(e0.x * e2.y - e0.y * e2.x);
    float2 d = min(min(float2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
                       float2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
                       float2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}

// Regular n-gon with circumradius r, one vertex pointing up.
// @exact. Use: badges, hexagonal tiles, pentagons, stop signs, gems (2D).
float SdRegularPolygon(float2 p, float r, int n)
{
    float an = PI / float(n);
    float2 acs = float2(cos(an), sin(an));
    float len = length(p);
    if (len < 1e-12) return -r * acs.x;
    float bn = fmod(atan2(p.x, p.y), 2.0 * an) - an;
    p = len * float2(cos(bn), abs(sin(bn)));
    p -= r * acs;
    p.y += clamp(-p.y, 0.0, r * acs.y);
    return length(p) * sign(p.x);
}

// Star with n points and outer radius r. m in [2, n] sets the inner angle:
// m = 2 is the spikiest and m = n is a regular n-gon.
// @exact. Use: stars, sparkles, badges, flowers (with OpRound).
float SdStar(float2 p, float r, int n, float m)
{
    float an = PI / float(n);
    float en = PI / m;
    float2 acs = float2(cos(an), sin(an));
    float2 ecs = float2(cos(en), sin(en));
    float len = length(p);
    if (len < 1e-12) return -r * acs.x;
    float bn = fmod(atan2(p.x, p.y), 2.0 * an) - an;
    p = len * float2(cos(bn), abs(sin(bn)));
    p -= r * acs;
    p += ecs * clamp(-dot(p, ecs), 0.0, r * acs.y / ecs.y);
    return length(p) * sign(p.x);
}

// Vesica (lens): intersection of two circles of radius r whose centers sit at
// (+-d, 0). Points along Y. Needs d < r.
// @exact. Use: leaves, petals, eyes, fish bodies, almond shapes, gothic arches.
float SdVesica(float2 p, float r, float d)
{
    p = abs(p);
    float b = sqrt(r * r - d * d);
    return ((p.y - b) * d > p.x * b) ? length(p - float2(0.0, b))
                                     : length(p - float2(-d, 0.0)) - r;
}

// Crescent: disk ra at origin minus disk rb at (d, 0). @exact. Use: moons, claws, bananas (bent).
float SdMoon(float2 p, float d, float ra, float rb)
{
    p.y = abs(p.y);
    float a = (ra * ra - rb * rb + d * d) / (2.0 * d);
    float b = sqrt(max(ra * ra - a * a, 0.0));
    if (d * (p.x * b - p.y * a) > d * d * max(b - p.y, 0.0)) return length(p - float2(a, b));
    return max(length(p) - ra, -(length(p - float2(d, 0.0)) - rb));
}

// Heart with its bottom tip at the origin, about 1 unit tall. @exact. Use: hearts, valentines, health icons.
float SdHeart(float2 p)
{
    p.x = abs(p.x);
    if (p.y + p.x > 1.0) return sqrt(Dot2(p - float2(0.25, 0.75))) - 0.35355339;
    return sqrt(min(Dot2(p - float2(0.0, 1.0)), Dot2(p - 0.5 * max(p.x + p.y, 0.0)))) * sign(p.x - p.y);
}

// Rhombus with half-diagonals b. @exact. Use: diamonds, kites, card suits, argyle.
float SdRhombus(float2 p, float2 b)
{
    p = abs(p);
    float2 t = b - 2.0 * p;
    float h = clamp((t.x * b.x - t.y * b.y) / dot(b, b), -1.0, 1.0);
    float d = length(p - 0.5 * b * float2(1.0 - h, 1.0 + h));
    return d * sign(p.x * b.y + p.y * b.x - b.x * b.y);
}

// Ellipse with semi-axes r. Fast approximation: exact zero set, a bound outside
// up to about 2:1 aspect. @approx. Use: eyes, pupils, ovals, shadows under objects.
float SdEllipse(float2 p, float2 r)
{
    float k0 = length(p / r);
    float k1 = length(p / (r * r));
    if (k1 < 1e-8) return -min(r.x, r.y);
    return k0 * (k0 - 1.0) / k1;
}

// Unsigned distance to a quadratic Bezier curve A-B-C. Solves the closest-point
// cubic analytically. Falls back to a segment when the curve degenerates to a line.
// @exact. Use: brush strokes, hair, calligraphy, tendrils, eyelashes, font-like curves.
float SdQuadraticBezier(float2 pos, float2 A, float2 B, float2 C)
{
    float2 a = B - A;
    float2 b = A - 2.0 * B + C;
    float2 c = a * 2.0;
    float2 d = A - pos;
    float bb = dot(b, b);
    if (bb < 1e-10) return SdSegment(pos, A, C);
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

// Pie slice (circular sector) of radius r, symmetric about +Y. sc = float2(sin, cos)
// of the half-aperture, which may go up to pi (a full disk); past pi/2 the slice is concave.
// @exact. Use: pie charts, pac-man-style wedges, fans, radar sweeps, clock wedges.
float SdPie(float2 p, float2 sc, float r)
{
    p.x = abs(p.x);
    float toArc = length(p) - r;
    float toEdge = length(p - sc * clamp(dot(p, sc), 0.0, r));
    float side = sign(sc.y * p.x - sc.x * p.y);
    return max(toArc, toEdge * side);
}

// Horseshoe: an arc of radius r over the top (half-aperture sc, as in SdArc)
// whose ends run on as straight legs of length legLength along the arc's
// tangent, stroked with half-width w and round ends. The legs must not cross
// the Y axis (keep legLength * |cos(aperture)| below r * sin(aperture)).
// @exact. Use: horseshoes, magnets, U-bends, arches with posts, handles.
float SdHorseshoe(float2 p, float2 sc, float r, float legLength, float w)
{
    p.x = abs(p.x);
    float2 end = r * sc;
    float leg = SdSegment(p, end, end + legLength * float2(sc.y, -sc.x));
    return min(SdArc(p, sc, r, 0.0), leg) - w;
}

// Parabolic arch: the region under y = h (1 - x^2 / w^2) and above y = 0, so
// half-width w at the base and height h. Closest point found via a closed-form
// depressed cubic.
// @exact. Use: arches, bridges, tunnels, domes, bullets, gothic windows, tents.
float SdParabolaSegment(float2 p, float w, float h)
{
    p.x = abs(p.x);
    float k = h / (w * w);
    float P = (1.0 - 2.0 * k * (h - p.y)) / (2.0 * k * k);
    float Q = -p.x / (2.0 * k * k);
    float disc = 0.25 * Q * Q + P * P * P / 27.0;
    float x;
    if (disc >= 0.0) {
        float u = pow(-0.5 * Q + sqrt(disc), 1.0 / 3.0);
        float v = -P / (3.0 * max(u, 1e-20));
        x = -Q / max(u * u - u * v + v * v, 1e-30);
    } else {
        float m = sqrt(-P / 3.0);
        x = 2.0 * m * cos(acos(clamp(-Q / (2.0 * m * m * m), -1.0, 1.0)) / 3.0);
    }
    x = clamp(x, 0.0, w);
    float d = min(length(p - float2(x, h - k * x * x)), length(p - float2(min(p.x, w), 0.0)));
    return (p.y > 0.0 && p.y < h - k * p.x * p.x) ? -d : d;
}

// Egg built from four tangent arcs (Moss-style): a bottom half-disk of radius
// ra centered at the origin, a top cap of radius rb, and two side arcs of
// radius 2*ra joining them. rb = ra is a disk; smaller rb makes a pointier egg.
// Needs 0 < rb <= ra.
// @exact. Use: eggs, droplets, pebbles, seeds, cartoon heads and bodies, onion domes (flip y).
float SdEgg(float2 p, float ra, float rb)
{
    p.x = abs(p.x);
    float c = sqrt((2.0 * ra - rb) * (2.0 * ra - rb) - ra * ra);
    if (p.y < 0.0) return length(p) - ra;
    if (ra * p.y > c * (p.x + ra)) return length(p - float2(0.0, c)) - rb;
    return length(p + float2(ra, 0.0)) - 2.0 * ra;
}

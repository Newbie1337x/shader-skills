// domain.hlsl — transform the point BEFORE evaluating a distance (repetition,
// mirroring, polar sectors, folds, twist, bend). Ported to HLSL from
// gokayfem/shader-skills' domain.glsl (GLSL, MIT). See SKILL.md for port notes.
// requires: common.hlsl (Rot2, TAU)
//
// Rigid transforms (repeat, mirror, rotate, fold) keep distances exact. Twist
// and bend stretch space, so their results are only bounds after scaling (see
// each function). Repetition uses floor(x + 0.5) rather than round() to avoid
// GLSL's implementation-defined round(0.5) — kept as-is in HLSL too for parity,
// though HLSL's round() is well-defined (round-half-to-even); floor(x+0.5) is
// round-half-up, a different tie rule, so don't swap them casually.

// Cell index for repetition with period s (integer-valued; use with hash functions).
// Use: per-instance variation: Hash12(DomRepeatId(p.xz, s)).
float DomRepeatId(float p, float s) { return floor(p / s + 0.5); }
float2 DomRepeatId(float2 p, float2 s) { return floor(p / s + 0.5); }
float3 DomRepeatId(float3 p, float3 s) { return floor(p / s + 0.5); }

// Infinite repetition with period s. Returns the local coordinate centered in its cell.
// Exact only while each instance stays inside its own cell.
// Use: forests, columns, tiles, crowds, star fields, city blocks.
float DomRepeat(float p, float s) { return p - s * floor(p / s + 0.5); }
float2 DomRepeat(float2 p, float2 s) { return p - s * floor(p / s + 0.5); }
float3 DomRepeat(float3 p, float3 s) { return p - s * floor(p / s + 0.5); }

// Repetition limited to cells -lim..+lim on each axis (2*lim + 1 copies).
// Use: rows of windows, fence posts, a finite grid of buttons, colonnades.
float2 DomRepeatLimited(float2 p, float2 s, float2 lim) { return p - s * clamp(floor(p / s + 0.5), -lim, lim); }
float3 DomRepeatLimited(float3 p, float3 s, float3 lim) { return p - s * clamp(floor(p / s + 0.5), -lim, lim); }

// Mirrored repetition: every other cell is flipped, so shapes touching the cell border join seamlessly.
// Use: tiled ornaments, symmetric wallpaper, seamless pipes and rails.
float2 DomRepeatMirror(float2 p, float2 s)
{
    float2 cell = floor(p / s + 0.5);
    float2 local = p - s * cell;
    return local * (1.0 - 2.0 * fmod(cell, 2.0));
}

// Polar repetition into n sectors around the origin. Returns p rotated into the
// sector centered on +X. Single evaluation: exact for shapes symmetric about
// their sector's center line.
// Use: petals, spokes, gears, clock marks, radial ornaments, columns around a tower.
float2 DomPolar(float2 p, float n)
{
    if (dot(p, p) < 1e-20) return p;
    float sector = TAU / n;
    float id = floor(atan2(p.y, p.x) / sector + 0.5);
    return mul(p, Rot2(-id * sector));
}

// Sector index in [0, n) for DomPolar. Use: varying each petal, spoke or column.
float DomPolarId(float2 p, float n)
{
    if (dot(p, p) < 1e-20) return 0.0;
    float sector = TAU / n;
    return fmod(floor(atan2(p.y, p.x) / sector + 0.5), n);
}

// Neighbor-checked polar repetition: ids (in [0, n)) of the sector holding p and
// of the adjacent sector p leans toward. Evaluate the shape in both with
// DomPolarSector and take the min — use when sectors vary (per-id length, tilt,
// color) or are asymmetric.
// Use: varied petals, tilted fan blades, gear teeth of mixed sizes, radial crowds.
float2 DomPolarPair(float2 p, float n)
{
    if (dot(p, p) < 1e-20) return float2(0.0, 1.0);
    float sector = TAU / n;
    float a = atan2(p.y, p.x) / sector;
    float id = floor(a + 0.5);
    return fmod(float2(id, id + ((a >= id) ? 1.0 : -1.0)), n);
}

// Rotate p into the frame of polar sector id (its center line on +X).
// DomPolarSector(p, DomPolarId(p, n), n) equals DomPolar(p, n).
// Use: the second half of DomPolarPair: evaluate a sector's shape by id.
float2 DomPolarSector(float2 p, float id, float n) { return mul(p, Rot2(-id * TAU / n)); }

// Fold space across the plane through the origin with unit normal n. Points
// behind the plane are reflected.
// Use: kaleidoscopes, symmetric creatures, KIFS fractals, mirrored architecture.
float3 DomFold(float3 p, float3 n) { return p - 2.0 * min(dot(p, n), 0.0) * n; }

// Twist around Y: rotate XZ by k * y. Divide the resulting distance by
// L = a/2 + sqrt(1 + a*a/4), a = k * R, where R is the shape's max distance
// from the Y axis — without that, the march overshoots.
// Use: twisted columns, drills, licorice, DNA-like spirals, towels.
float3 DomTwist(float3 p, float k)
{
    float2 xz = mul(p.xz, Rot2(k * p.y));
    return float3(xz.x, p.y, xz.y);
}

// Bend in XY: rotate XY by k * x. Divide the resulting distance by about
// 1 + k * R (R = max |p.xy| of the shape).
// Use: bent beams, arches from boxes, bananas, curved horns.
float3 DomBend(float3 p, float k)
{
    float2 xy = mul(p.xy, Rot2(k * p.x));
    return float3(xy, p.z);
}

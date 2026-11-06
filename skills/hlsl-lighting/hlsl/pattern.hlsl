// pattern.hlsl — tilings and antialiased procedural patterns. Ported to HLSL
// from gokayfem/shader-skills' pattern.glsl (GLSL, MIT). See SKILL.md for port notes.
// requires: hash.hlsl (Hash12)
//
// The filtered versions integrate the pattern over the pixel footprint (box
// filter), so floors and stripes stay clean in the distance with no supersampling.

// Triangle wave, the integral of a square wave. Use: writing new filtered patterns.
float2 TriangleWave(float2 x) { return 1.0 - 2.0 * abs(frac(x * 0.5) - 0.5); }

// Box-filtered checkerboard with unit squares: 0 or 1 up close, fading to 0.5
// where squares are smaller than a pixel. Compute the footprint before any
// branching: w = fwidth(p).
// Use: floors, chessboards, test patterns, racing flags, tablecloths. Range [0,1].
float FilteredChecker(float2 p, float2 w)
{
    w = max(w, 1e-4);
    float2 i = (TriangleWave(p + 0.5 * w) - TriangleWave(p - 0.5 * w)) / w;
    return 0.5 - 0.5 * i.x * i.y;
}

// Box-filtered grid lines (unit cells, line width = 1/n of a cell). Returns 1
// on lines, 0 inside cells.
// Use: blueprints, graph paper, tiles with grout, sci-fi floors, synthwave grids. Range [0,1].
float FilteredGrid(float2 p, float2 w, float n)
{
    w = max(w, 1e-4);
    float2 a = p + 0.5 * w;
    float2 b = p - 0.5 * w;
    float2 i = (floor(a) + min(frac(a) * n, 1.0) - floor(b) - min(frac(b) * n, 1.0)) / (n * w);
    return 1.0 - (1.0 - i.x) * (1.0 - i.y);
}

// Box-filtered stripes along x with period 1 and duty cycle 0.5. Returns 0..1.
// Use: awnings, candy, zebra (warp x first), barcodes, road markings. Range [0,1].
float FilteredStripes(float x, float w)
{
    w = max(w, 1e-4);
    float a = x + 0.5 * w, b = x - 0.5 * w;
    float ia = floor(a) * 0.5 + max(frac(a) - 0.5, 0.0);
    float ib = floor(b) * 0.5 + max(frac(b) - 0.5, 0.0);
    return (ia - ib) / w;
}

// Hexagonal tiling with unit spacing between neighboring centers. Neighbors
// sit left/right, so hexes are pointy-top. Returns float4(local offset from
// the hex center, integer-valued hex id).
// Use: honeycomb, scales, tiles, game boards, hex pixelation.
float4 HexGrid(float2 p)
{
    const float2 s = float2(1.0, 1.7320508);
    float2 a = fmod(p, s) - 0.5 * s;
    float2 b = fmod(p - 0.5 * s, s) - 0.5 * s;
    float2 local = (dot(a, a) < dot(b, b)) ? a : b;
    float2 center = p - local;
    float2 id = floor(float2(center.x * 2.0, center.y * 1.1547005) + 0.5);
    return float4(local, id);
}

// Distance from a HexGrid local coordinate to its hexagon's edge (0.5 at the
// center, 0 on the edge). Use: hex borders, bevels, edge wear on tiles.
float HexEdgeDistance(float2 local)
{
    float2 a = abs(local);
    return 0.5 - max(a.x, dot(a, float2(0.5, 0.8660254)));
}

// Truchet tiling of quarter-circle arcs, randomly flipped per cell. Returns
// signed distance to arcs of half-width w.
// Use: maze-like ornaments, pipes, Celtic-style weaves, procedural circuitry.
float TruchetArcs(float2 p, float w)
{
    float2 id = floor(p);
    float2 f = frac(p) - 0.5;
    if (Hash12(id) < 0.5) f.x = -f.x;
    float2 q = f - 0.5 * sign(f.x + f.y + 1e-6);
    return abs(length(q) - 0.5) - w;
}

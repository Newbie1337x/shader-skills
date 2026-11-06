// post.hlsl — antialiasing helpers, supersampling offsets, lens effects, grain
// and dithering, all single-pass. Ported to HLSL from gokayfem/shader-skills'
// post.glsl (GLSL, MIT). See SKILL.md for port notes.
// requires: hash.hlsl (Hash22)
//
// Order of a finished frame: (per AA sample) exposure, vignette, grain ->
// tonemap -> average samples -> LinearToSrgb (color.hlsl) -> dither.
// HLSL's ddx/ddy are the same operations as GLSL's dFdx/dFdy; fwidth exists
// in HLSL under the same name.

// Antialiased fill of a 2D SDF: 1 inside, 0 outside, box-filtered across one
// pixel. Uses screen derivatives, so call it outside non-uniform branches and
// loops — for a fixed pixel size use FillAA(d, px) instead.
// Use: 2D shapes, icons, text-like strokes, UI, masks with crisp edges.
float FillAA(float d)
{
    float w = length(float2(ddx(d), ddy(d)));
    return saturate(0.5 - d / max(w, 1e-6));
}

// Antialiased fill with an explicit pixel size px (e.g. 2.0 / screenHeightPx
// for a centered uv). Safe in loops and branches.
// Use: 2D shapes evaluated inside loops, layered compositions.
float FillAA(float d, float px) { return saturate(0.5 - d / px); }

// Antialiased stroke of half-width hw around the zero line of a 2D SDF.
// Use: outlines, line art, rings, wireframes, contour lines.
float StrokeAA(float d, float hw, float px) { return FillAA(abs(d) - hw, px); }

// Subpixel offset in [-0.5, 0.5)^2 for sample i of a supersampling loop (R2
// low-discrepancy sequence). Better coverage than a regular grid for any sample count.
// Use: AA loops over multiple sub-pixel samples per output pixel.
float2 AaOffset(int i)
{
    return frac(0.5 + float(i) * float2(0.7548776662, 0.5698402910)) - 0.5;
}

// Natural (cos^4) vignette for a pinhole camera: uv is the screen point,
// focal the camera focal length. Wider lenses vignette more. Multiply HDR
// color before tonemapping.
// Use: photographic falloff, framing, cinematic looks.
float Vignette(float2 uv, float focal)
{
    float f2 = focal * focal;
    float k = f2 / (f2 + dot(uv, uv));
    return k * k;
}

// Signal-dependent film grain: noise grows with sqrt(intensity), as photon
// noise does. n should be zero-mean noise (e.g. Hash13(float3(pixel, frame)) * 2 - 1).
// Apply in linear HDR before tonemapping.
// Use: filmic texture, hiding banding, analog looks.
float3 FilmGrain(float3 col, float amount, float n)
{
    return col + amount * sqrt(max(col, 0.0)) * n;
}

// Triangular-PDF dither of +-1 LSB for 8-bit output. Add AFTER LinearToSrgb,
// right before writing the output color.
// Use: removing banding in skies, fog, vignettes and dark gradients.
float3 DitherTPDF(float2 pixelCoord, int frame)
{
    float2 r = Hash22(floor(pixelCoord) + 7919.0 * float(frame % 1024));
    return float3((r.x + r.y - 1.0) / 255.0, (r.x + r.y - 1.0) / 255.0, (r.x + r.y - 1.0) / 255.0);
}

// color.hlsl — transfer functions, perceptual color (Oklab/OkLCh), palettes,
// luminance, blackbody light colors. Ported to HLSL from gokayfem/shader-skills'
// color.glsl (GLSL, MIT). See SKILL.md for the GLSL->HLSL matrix-multiply rule
// this file depends on.
//
// Light, shade and mix in LINEAR color. Picked hex colors, palettes and texture
// samples are sRGB-encoded, so decode with SrgbToLinear before lighting. Encode
// once at the very end with LinearToSrgb.
//
// #include "common.hlsl" for TAU before using this file.

// Exact sRGB decode (EOTF): encoded [0,1] -> linear.
// Use: decoding picked colors, palettes used as albedo, and texture samples
// that were NOT already loaded through an sRGB-aware texture format.
float3 SrgbToLinear(float3 c)
{
    c = max(c, 0.0);
    return lerp(c / 12.92, pow((c + 0.055) / 1.055, float3(2.4, 2.4, 2.4)), step(0.04045, c));
}

// Exact sRGB encode (OETF): linear -> display [0,1]. Apply exactly once, after tonemapping.
// pow(c, 1/2.2) is visibly wrong near black. Skip this if the back buffer / swap
// chain is already an sRGB format (it encodes for you on write).
// Use: final output.
float3 LinearToSrgb(float3 c)
{
    c = max(c, 0.0);
    return lerp(c * 12.92, 1.055 * pow(c, float3(1.0 / 2.4, 1.0 / 2.4, 1.0 / 2.4)) - 0.055, step(0.0031308, c));
}

// Relative luminance of linear Rec.709 / sRGB color.
// Use: desaturation, brightness masks, luminance-based effects.
float Luminance(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }

// Scale saturation around luminance: 0 = grey, 1 = unchanged, > 1 = more saturated.
// Use: grading, fading distant objects, stylization.
float3 Saturation(float3 c, float s) { float l = Luminance(c); return lerp(float3(l, l, l), c, s); }

// Linear sRGB -> Oklab (L in [0,1], a/b around [-0.4, 0.4]).
// Matrices from Bjorn Ottosson (public domain / MIT).
// Use: perceptual gradients, even-lightness palettes, hue and chroma edits.
// See: https://bottosson.github.io/posts/oklab/
float3 LinearSrgbToOklab(float3 c)
{
    static const float3x3 M1 = float3x3(
        0.4122214708, 0.5363325363, 0.0514459929,
        0.2119034982, 0.6806995451, 0.1073969566,
        0.0883024619, 0.2817188376, 0.6299787005);
    float3 lms = mul(M1, c);
    lms = sign(lms) * pow(abs(lms), float3(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0));
    static const float3x3 M2 = float3x3(
        0.2104542553, 0.7936177850, -0.0040720468,
        1.9779984951, -2.4285922050, 0.4505937099,
        0.0259040371, 0.7827717662, -0.8086757660);
    return mul(M2, lms);
}

// Oklab -> linear sRGB. The result can fall outside [0,1] for saturated colors,
// so clamp after tonemapping.
// Use: converting perceptual edits back for lighting or output.
float3 OklabToLinearSrgb(float3 lab)
{
    static const float3x3 M1 = float3x3(
        1.0, 0.3963377774, 0.2158037573,
        1.0, -0.1055613458, -0.0638541728,
        1.0, -0.0894841775, -1.2914855480);
    float3 lms = mul(M1, lab);
    lms = lms * lms * lms;
    static const float3x3 M2 = float3x3(
        4.0767416621, -3.3077115913, 0.2309699292,
        -1.2684380046, 2.6097574011, -0.3413193965,
        -0.0041960863, -0.7034186147, 1.7076147010);
    return mul(M2, lms);
}

// Mix two linear colors in Oklab. Avoids the muddy mid-tones of RGB lerps and
// the hue detours of HSV.
// Use: gradients, sky ramps, color transitions over time, blending materials.
float3 MixOklab(float3 a, float3 b, float t)
{
    return OklabToLinearSrgb(lerp(LinearSrgbToOklab(a), LinearSrgbToOklab(b), t));
}

// OkLCh (lightness, chroma, hue in radians) -> linear sRGB. Hue sweeps keep
// lightness constant. L about 0.4-0.9, C about 0.05-0.2 stays mostly in gamut.
// Use: harmonious palettes, rainbow ramps with even brightness, per-instance hue variation.
float3 OklchToLinearSrgb(float3 lch)
{
    return OklabToLinearSrgb(float3(lch.x, lch.y * cos(lch.z), lch.y * sin(lch.z)));
}

// Cosine palette a + b * cos(2*pi*(c*t + d)). Output is display-like (sRGB-ish),
// so decode it for albedo. Integer c values loop seamlessly over t in [0,1].
// Use: quick gradients, heat maps, psychedelic color cycling, per-id colors.
// See: https://iquilezles.org/articles/palettes/
float3 CosinePalette(float t, float3 a, float3 b, float3 c, float3 d)
{
    return a + b * cos(TAU * (c * t + d));
}

// Approximate linear sRGB color of a blackbody at temperature kelvin
// (1000-15000 K), normalized to max channel 1.
// Uses the Krystek (1985) Planckian-locus fit -> XYZ -> sRGB.
// Use: fire, embers, lava, stars, incandescent lamps, sunset light, molten metal.
float3 Blackbody(float kelvin)
{
    float T = clamp(kelvin, 1000.0, 15000.0);
    float u = (0.860117757 + 1.54118254e-4 * T + 1.28641212e-7 * T * T) / (1.0 + 8.42420235e-4 * T + 7.08145163e-7 * T * T);
    float v = (0.317398726 + 4.22806245e-5 * T + 4.20481691e-8 * T * T) / (1.0 - 2.89741816e-5 * T + 1.61456053e-7 * T * T);
    float x = 3.0 * u / (2.0 * u - 8.0 * v + 4.0);
    float y = 2.0 * v / (2.0 * u - 8.0 * v + 4.0);
    float3 xyz = float3(x / y, 1.0, (1.0 - x - y) / y);
    static const float3x3 M = float3x3(
        3.2406, -1.5372, -0.4986,
        -0.9689, 1.8758, 0.0415,
        0.0557, -0.2040, 1.0570);
    float3 rgb = mul(M, xyz);
    rgb = max(rgb, 0.0);
    return rgb / max(max(rgb.r, rgb.g), max(rgb.b, 1e-6));
}

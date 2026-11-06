// tonemap.hlsl — map scene-linear HDR to display range. Ported to HLSL from
// gokayfem/shader-skills' tonemap.glsl (GLSL, MIT). See SKILL.md for the
// GLSL->HLSL matrix-multiply rule this file depends on.
//
// Every function here takes linear input (after exposure) and returns LINEAR
// [0,1]. Then apply LinearToSrgb (color.hlsl) exactly once, unless the swap
// chain format already does sRGB encode on write.
// Recommended chain: col *= exposure; col = TonemapAgX(col); col = LinearToSrgb(col); add dither.
// Choosing: AgX (default) for 3D scenes, glows, fire, suns and volumes — highlights
// roll off to white without hue skews. TonemapNeutral for 2D/UI/product-faithful
// work. ACES for the saturated filmic look (classic "game HDR").

// AgX: log encoding plus a sigmoid inside an inset/outset gamut. Mid-grey 0.18
// maps to about 0.5 display. Minimal implementation after Troy Sobotka's AgX
// and Benjamin Wrensch's polynomial fit (both MIT).
// Use: default tonemapper for 3D, emissive glows, fire, neon, skies, clouds.
// See: https://iolite-engine.com/blog_posts/minimal_agx_implementation
float3 TonemapAgX(float3 c)
{
    static const float3x3 inset = float3x3(
        0.842479062253094, 0.0423282422610123, 0.0423756549057051,
        0.0784335999999992, 0.878468636469772, 0.0784336,
        0.0792237451477643, 0.0791661274605434, 0.879142973793104);
    static const float3x3 outset = float3x3(
        1.19687900512017, -0.0528968517574562, -0.0529716355144438,
        -0.0980208811401368, 1.15190312990417, -0.0980434501171241,
        -0.0990297440797205, -0.0989611768448433, 1.15107367264116);
    static const float minEv = -12.47393;
    static const float maxEv = 4.026069;

    c = mul(max(c, 0.0), inset);
    c = saturate((log2(max(c, 1e-10)) - minEv) / (maxEv - minEv));
    float3 x2 = c * c, x4 = x2 * x2;
    c = 15.5 * x4 * x2 - 40.14 * x4 * c + 31.96 * x4 - 6.868 * x2 * c + 0.4298 * x2 + 0.1191 * c - 0.00232;
    c = mul(c, outset);
    return pow(max(c, 0.0), float3(2.2, 2.2, 2.2));
}

// AgX with the "punchy" look (more contrast and saturation) for stylized art.
// Use: stylized 3D, saturated sunsets, toy-like renders.
float3 TonemapAgXPunchy(float3 c)
{
    static const float3x3 inset = float3x3(
        0.842479062253094, 0.0423282422610123, 0.0423756549057051,
        0.0784335999999992, 0.878468636469772, 0.0784336,
        0.0792237451477643, 0.0791661274605434, 0.879142973793104);
    static const float3x3 outset = float3x3(
        1.19687900512017, -0.0528968517574562, -0.0529716355144438,
        -0.0980208811401368, 1.15190312990417, -0.0980434501171241,
        -0.0990297440797205, -0.0989611768448433, 1.15107367264116);
    static const float minEv = -12.47393;
    static const float maxEv = 4.026069;

    c = mul(max(c, 0.0), inset);
    c = saturate((log2(max(c, 1e-10)) - minEv) / (maxEv - minEv));
    float3 x2 = c * c, x4 = x2 * x2;
    c = 15.5 * x4 * x2 - 40.14 * x4 * c + 31.96 * x4 - 6.868 * x2 * c + 0.4298 * x2 + 0.1191 * c - 0.00232;
    c = pow(max(c, 0.0), float3(1.35, 1.35, 1.35));
    float luma = dot(c, float3(0.2126, 0.7152, 0.0722));
    c = luma + 1.4 * (c - luma);
    c = mul(c, outset);
    return pow(max(c, 0.0), float3(2.2, 2.2, 2.2));
}

// Khronos PBR Neutral: leaves [0, ~0.76] almost untouched and compresses only
// highlights, preserving hue.
// Use: 2D art, palette-faithful scenes, product renders, UI glow.
// See: https://github.com/KhronosGroup/ToneMapping
float3 TonemapNeutral(float3 c)
{
    static const float startCompression = 0.76;
    static const float desaturation = 0.15;
    c = max(c, 0.0);
    float x = min(c.r, min(c.g, c.b));
    float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
    c -= offset;
    float peak = max(c.r, max(c.g, c.b));
    if (peak < startCompression) return c;
    const float d = 1.0 - startCompression;
    float newPeak = 1.0 - d * d / (peak + d - startCompression);
    c *= newPeak / peak;
    float g = 1.0 - 1.0 / (desaturation * (peak - newPeak) + 1.0);
    return lerp(c, float3(newPeak, newPeak, newPeak), g);
}

// Stephen Hill's ACES fit (RRT + ODT, sRGB primaries). Contrasty and saturated;
// blues drift purple when very bright. Darker than AgX at the same exposure:
// multiply the input by about 1.6 to compensate.
// Use: the classic "filmic game" look.
// See: https://github.com/TheRealMJP/BakingLab/blob/master/BakingLab/ACES.hlsl
float3 TonemapACES(float3 c)
{
    static const float3x3 M1 = float3x3(
        0.59719, 0.35458, 0.04823,
        0.07600, 0.90834, 0.01566,
        0.02840, 0.13383, 0.83777);
    static const float3x3 M2 = float3x3(
        1.60475, -0.53108, -0.07367,
        -0.10208, 1.10813, -0.00605,
        -0.00327, -0.07276, 1.07602);
    c = mul(M1, max(c, 0.0));
    c = (c * (c + 0.0245786) - 0.000090537) / (c * (0.983729 * c + 0.4329510) + 0.238081);
    c = mul(M2, c);
    return saturate(c);
}

// Extended Reinhard on luminance: maps `white` to 1 and preserves hue.
// Use: quick previews, soft low-contrast looks.
float3 TonemapReinhard(float3 c, float white)
{
    c = max(c, 0.0);
    float l = dot(c, float3(0.2126, 0.7152, 0.0722));
    float lt = l * (1.0 + l / (white * white)) / (1.0 + l);
    return saturate(c * (lt / max(l, 1e-6)));
}

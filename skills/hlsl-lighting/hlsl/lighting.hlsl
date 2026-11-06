// lighting.hlsl — BRDF terms and practical lighting models, ported to HLSL from
// gokayfem/shader-skills' shading.glsl (GLSL, MIT). See SKILL.md for port notes.
//
// Vectors are unit length: n = normal, v = toward the viewer (-rd), l = toward the
// light. Units are "artist units" with pi folded in: a light of color C lights a
// white Lambert surface facing it to C. Every function returns radiance per unit
// light color, already including NoL. Physically based terms follow Filament
// (https://google.github.io/filament/Filament.md.html).
//
// #include "common.hlsl" for PI before using this file.

// Schlick Fresnel. u is VoH for lights and NoV for environment reflections/rims.
// f0 = 0.04 for dielectrics (plastic, skin, stone; water ~0.02); for metals f0 = base color.
// Use: reflections that strengthen at grazing angles, rim brightening, water/glass.
float3 FresnelSchlick(float u, float3 f0)
{
    float m = saturate(1.0 - u);
    float m2 = m * m;
    return f0 + (1.0 - f0) * (m2 * m2 * m);
}

// GGX / Trowbridge-Reitz normal distribution. alpha = roughness^2.
// Use: specular highlight shape (inside SpecularGGX).
float DistributionGGX(float NoH, float alpha)
{
    float a2 = alpha * alpha;
    float d = NoH * NoH * (a2 - 1.0) + 1.0;
    return a2 / (PI * d * d);
}

// Height-correlated Smith visibility. Already contains the 1 / (4 NoL NoV) term.
// Use: specular shadowing-masking (inside SpecularGGX).
float VisibilitySmithGGX(float NoV, float NoL, float alpha)
{
    float a2 = alpha * alpha;
    float gv = NoL * sqrt(NoV * NoV * (1.0 - a2) + a2);
    float gl = NoV * sqrt(NoL * NoL * (1.0 - a2) + a2);
    return 0.5 / max(gv + gl, 1e-6);
}

// Microfacet specular for one light: pi * D * V * F * NoL (artist units).
// roughness is perceptual, in [0,1].
// Use: glossy plastic, metal, wet surfaces, car paint, ceramics.
float3 SpecularGGX(float3 n, float3 v, float3 l, float roughness, float3 f0)
{
    float3 h = normalize(v + l);
    float NoL = saturate(dot(n, l));
    float NoV = max(dot(n, v), 1e-4);
    float NoH = saturate(dot(n, h));
    float VoH = saturate(dot(v, h));
    float alpha = max(roughness, 0.045);
    alpha *= alpha;
    return PI * DistributionGGX(NoH, alpha) * VisibilitySmithGGX(NoV, NoL, alpha) * FresnelSchlick(VoH, f0) * NoL;
}

// Complete metallic-roughness shading for one light (diffuse + specular, NoL
// included, artist units). Multiply by light color and shadow. Keep albedo
// around 0.05-0.7 (linear); brighten lights, not albedo.
// Use: hero objects, anything that needs believable materials.
float3 ShadePBR(float3 n, float3 v, float3 l, float3 albedo, float roughness, float metallic)
{
    float3 f0 = lerp(float3(0.04, 0.04, 0.04), albedo, metallic);
    float NoL = saturate(dot(n, l));
    float3 F = FresnelSchlick(max(dot(n, v), 0.0), f0);
    float3 diffuse = albedo * (1.0 - metallic) * (1.0 - F) * NoL;
    return diffuse + SpecularGGX(n, v, l, roughness, f0);
}

// Split-sum environment specular without a lookup texture (Karis 2014, after Lazarov).
// Multiply by the sky/environment color in the reflection direction.
// Use: sky reflections on glossy surfaces, ambient specular.
float3 EnvBRDFApprox(float3 f0, float NoV, float roughness)
{
    float4 r = roughness * float4(-1.0, -0.0275, -0.572, 0.022) + float4(1.0, 0.0425, 1.04, -0.04);
    float a = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
    float2 ab = float2(-1.04, 1.04) * a + r.zw;
    return f0 * ab.x + ab.y;
}

// Energy-conserving wrap diffuse: light wraps past the terminator by w (0 = Lambert, 0.5 = soft).
// Use: skin, foliage, cloth, soft stylized shading, fur.
// See: https://blog.selfshadow.com/2011/12/31/righting-wrap-part-1/
float WrapDiffuse(float3 n, float3 l, float w)
{
    return max((dot(n, l) + w) / ((1.0 + w) * (1.0 + w)), 0.0);
}

// Hemisphere light: sky color from above blended to ground color from below.
// Use: ambient fill, outdoor sky light, studio fill.
float3 HemisphereLight(float3 n, float3 skyColor, float3 groundColor)
{
    return lerp(groundColor, skyColor, 0.5 + 0.5 * n.y);
}

// Fast translucency (Barre-Brisebois and Bouchard 2011): light passing through
// thin parts, seen from the back. distortion bends the light along the normal
// (0.2-0.5). thickness is 0 (thin) .. 1 (thick).
// Use: leaves, ears, wax, jade, marble, backlit petals, jellyfish.
float Translucency(float3 n, float3 v, float3 l, float distortion, float power, float thickness)
{
    float3 h = normalize(l + n * distortion);
    return pow(saturate(dot(v, -h)), power) * (1.0 - thickness);
}

// Rim light from the viewing angle: strongest at silhouettes.
// Use: character separation from background, fresnel-like glow, stylized outlines.
float RimLight(float3 n, float3 v, float power)
{
    return pow(saturate(1.0 - dot(n, v)), power);
}

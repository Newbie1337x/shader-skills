// water.hlsl — finite-depth wave dispersion, analytic wave derivatives, exact
// dielectric Fresnel and RGB attenuation. Ported to HLSL from
// gokayfem/shader-skills' water.glsl (GLSL, MIT). See SKILL.md for port notes.
// requires: common.hlsl (TAU)
//
// Units must agree: wavelength/depth/path in meters, gravity in m/s^2,
// extinction in 1/m. No textures or scene state.

// Angular frequency sqrt(g*k*tanh(k*depth)) for finite-depth gravity waves.
// Nonpositive inputs are clamped.
// Use: shallow coasts, ocean swell, lake waves with depth-dependent speed. Range nonnegative.
float WaterDispersion(float k, float depth, float gravity)
{
    k = max(k, 0.0);
    float e = exp(-2.0 * k * max(depth, 0.0));
    return sqrt(max(gravity, 0.0) * k * (1.0 - e) / (1.0 + e));
}

// One sinusoidal wave: float4(height, dh/dx, dh/dz, Laplacian). Direction is
// normalized internally; zero uses +X. wavelength > 0, amplitude in meters.
// footprint filters waves below 2-6 pixels; derivatives hold it constant.
// Use: analytic water normals, layered swell/chop, curvature foam, finite-depth lake/coastal waves.
float4 WaterWaveD(float2 xz, float time, float2 direction, float wavelength, float amplitude, float depth, float footprint)
{
    float dl = length(direction);
    float2 dir = dl > 0.000001 ? direction / dl : float2(1.0, 0.0);
    float lengthM = max(wavelength, 0.0001);
    float k = TAU / lengthM;
    float keep = smoothstep(2.0, 6.0, lengthM / max(footprint, 0.000001));
    float phase = k * dot(dir, xz) - WaterDispersion(k, depth, 9.81) * time;
    float h = amplitude * keep * sin(phase);
    return float4(h, amplitude * keep * k * cos(phase) * dir, -k * k * h);
}

// Exact unpolarized dielectric Fresnel for a positive incident cosine and
// positive refractive indices. Returns 1 for total internal reflection.
// Use: air-water interfaces (1.0,1.333), underwater views (1.333,1.0), glass. Range [0,1].
float FresnelDielectric(float cosIncident, float etaIncident, float etaTransmitted)
{
    float ci = saturate(abs(cosIncident));
    float ei = max(etaIncident, 0.000001), et = max(etaTransmitted, 0.000001);
    if (abs(ei - et) < 0.0000001) return 0.0;
    float sinT2 = (ei * ei) / (et * et) * max(0.0, 1.0 - ci * ci);
    if (sinT2 >= 1.0) return 1.0;
    float ct = sqrt(max(0.0, 1.0 - sinT2));
    float rs = (ei * ci - et * ct) / max(ei * ci + et * ct, 0.000001);
    float rp = (et * ci - ei * ct) / max(et * ci + ei * ct, 0.000001);
    return saturate(0.5 * (rs * rs + rp * rp));
}

// Beer-Lambert RGB transmittance exp(-extinction*pathLength). Use the
// refracted optical path, not vertical water depth. Attenuation alone does
// not add scattered light.
// Use: depth-colored water, underwater visibility, tinted glass, homogeneous fog. Range [0,1].
float3 BeerTransmittance(float3 extinction, float pathLength)
{
    return exp(-max(extinction, 0.0) * max(pathLength, 0.0));
}

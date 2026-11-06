// volume.hlsl — participating media (fog, smoke, clouds, haze). Ported to
// HLSL from gokayfem/shader-skills' volume.glsl (GLSL, MIT). See SKILL.md for
// port notes.
// requires: common.hlsl (PI)
//
// mu = dot(rd, l): cosine between the view ray and the direction TOWARD the
// light, so forward scattering peaks when looking at the light.

// Isotropic phase function (scatters equally in all directions). Use: dusty fog, thick smoke interiors.
float PhaseIsotropic() { return 1.0 / (4.0 * PI); }

// Rayleigh phase function. Use: sky scattering by air molecules (blue sky).
float PhaseRayleigh(float mu) { return 3.0 / (16.0 * PI) * (1.0 + mu * mu); }

// Henyey-Greenstein phase function. g in (-1, 1): > 0 forward (silver linings), < 0 backward.
// Use: clouds (g ~ 0.6-0.85), fog glow around lights, underwater light shafts.
float PhaseHG(float mu, float g)
{
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * PI * pow(max(1.0 + g2 - 2.0 * g * mu, 1e-6), 1.5));
}

// Two-lobe Henyey-Greenstein: forward lobe gF and backward lobe gB, mixed by w
// (weight of the forward lobe). Keeps the silver lining while clouds lit from
// behind the camera still show detail.
// Use: clouds, smoke lit from varying angles.
float PhaseDualHG(float mu, float gF, float gB, float w)
{
    return lerp(PhaseHG(mu, gB), PhaseHG(mu, gF), w);
}

// Cornette-Shanks phase (a better-normalized Mie approximation). g = 0.8 for atmospheric haze.
// Use: sun halo in hazy skies, aerosols.
float PhaseCornetteShanks(float mu, float g)
{
    float g2 = g * g;
    return 3.0 / (8.0 * PI) * (1.0 - g2) * (1.0 + mu * mu)
         / ((2.0 + g2) * pow(max(1.0 + g2 - 2.0 * g * mu, 1e-6), 1.5));
}

// Beer-Powder lighting term for clouds: 2 e^-d (1 - e^-2d), where d is optical
// depth toward the sun. Darkens cloud edges that face the light like powdered
// sugar. Not energy-conserving; use it on the direct term only.
// Use: cumulus clouds, puffy smoke.
float BeerPowder(float d) { return 2.0 * exp(-d) * (1.0 - exp(-2.0 * d)); }

// One energy-conserving step of volume integration. sigmaT is extinction per
// unit length (RGB for tinted media), inScatter is in-scattered radiance at
// this point, ds is step length. Accumulates into radiance and transmittance.
// Stable for dense media, unlike radiance += T * S * ds.
// Use: any raymarched volume: clouds, smoke, fog, fire, nebulae.
void VolumeStep(inout float3 radiance, inout float3 transmittance, float3 sigmaT, float3 inScatter, float ds)
{
    float3 stepT = exp(-sigmaT * ds);
    float3 integral = (inScatter - inScatter * stepT) / max(sigmaT, float3(1e-7, 1e-7, 1e-7));
    radiance += transmittance * integral;
    transmittance *= stepT;
}

// Distance fog amount (0 = clear, 1 = fully fogged) for distance t. Use: depth cueing, haze, underwater murk.
float DistanceFog(float t, float density) { return 1.0 - exp(-t * density); }

// Analytic height fog for density a * exp(-b * y) along the ray segment [0, t].
// Thick near the ground, thin above. Returns the fog amount in [0,1].
// Use: valley mist, ground fog, layered haze in landscapes.
float HeightFog(float3 ro, float3 rd, float t, float a, float b)
{
    float base = a * exp(-ro.y * b);
    float amount = (abs(rd.y) < 1e-4) ? base * t
                                       : base * (1.0 - exp(-t * rd.y * b)) / (rd.y * b);
    return 1.0 - exp(-max(amount, 0.0));
}

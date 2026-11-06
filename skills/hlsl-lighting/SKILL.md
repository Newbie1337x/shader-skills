---
name: hlsl-lighting
description: "HLSL/D3D11 lighting and color library — PBR/GGX shading, wrap diffuse, rim/translucency, Oklab color math, AgX/ACES/Neutral tonemapping, and a cheap analytic sky, for writing a custom lighting system from scratch in HLSL (e.g. a d3d8to11-style forward renderer). Ported by hand from gokayfem/shader-skills (GLSL) since that skill explicitly does not cover HLSL."
argument-hint: "[lighting|color|tonemap|sky|all]"
---

# HLSL Lighting

A hand-ported fork, for HLSL/D3D11 projects, of the GLSL function library from
[gokayfem/shader-skills](https://github.com/gokayfem/shader-skills) (MIT). That
skill is excellent but is scoped to Shadertoy/WebGL2 GLSL ES and explicitly
excludes HLSL — this skill exists because our lighting is written from scratch
in HLSL against a D3D11 backend (d3d8to11-style), so the GLSL source can't be
dropped in as-is.

**This is a reference library + usage guidance, not a static-analysis tool.**
When the user asks to write or fix lighting/color/tonemapping code in an HLSL
shader:

1. Read the relevant file(s) under `hlsl/` for the functions that apply
   (`lighting.hlsl`, `color.hlsl`, `tonemap.hlsl`, `sky.hlsl`).
2. Use the functions directly (copy the ones needed into the target shader, or
   `#include` the file if the project's shader build supports includes) rather
   than reinventing the math.
3. Follow the usage notes in each function's comment (valid ranges, what to
   multiply by, linear-vs-sRGB expectations) — these are the same notes from
   the original GLSL library, adjusted where the port changed semantics.

## Files

The port is now complete: every function-bearing GLSL module from the source
repo's `shader-art-coding` skill has a HLSL counterpart here (one exception
noted under `hlsl/sky.hlsl` below). `templates/` (full Shadertoy scenes) and
`references/*.md` (prose guides) were not ported — see "Deliberately not
ported" at the end of this section.

- `hlsl/common.hlsl` — `PI`, `TAU`, `Dot2`, `Rot2` (2D rotation — **apply with
  `mul(v, Rot2(a))`, not `mul(Rot2(a), v)`**, see the matrix-order rule below),
  `Remap`, `Linearstep`, `CubicPulse`, `ExpImpulse`, `Gain`, `Parabola`,
  `AlmostIdentity`. (HLSL's built-in `saturate()` replaces the source's custom
  `saturate()` wrapper — not re-declared.)
- `hlsl/hash.hlsl` — `PcgHash`, `Pcg3D`, `Pcg4D`, `UintToUnit`, `Hash11`,
  `Hash12`, `Hash13`, `Hash22`, `Hash33`, `Hash44`, `Hash32`.
- `hlsl/lighting.hlsl` — Schlick Fresnel, GGX distribution/visibility,
  `SpecularGGX`, `ShadePBR` (full metallic-roughness single-light shading),
  `EnvBRDFApprox` (split-sum env specular, no LUT), `WrapDiffuse`,
  `HemisphereLight`, `Translucency`, `RimLight`.
- `hlsl/color.hlsl` — `SrgbToLinear`/`LinearToSrgb`, `Luminance`, `Saturation`,
  Oklab/OkLCh conversions (`LinearSrgbToOklab`, `OklabToLinearSrgb`,
  `MixOklab`, `OklchToLinearSrgb`), `CosinePalette`, `Blackbody` (light color
  from Kelvin temperature).
- `hlsl/tonemap.hlsl` — `TonemapAgX` (default for 3D), `TonemapAgXPunchy`,
  `TonemapNeutral` (Khronos PBR Neutral), `TonemapACES`, `TonemapReinhard`.
- `hlsl/sky.hlsl` — `SimpleSky` (cheap gradient + sun glow), `SunDisk`
  (antialiased disk with limb darkening), and now also `AtmosphereDensity`,
  `AtmosphereExtinction`, `AtmosphereSky` (Hillaire EGSR 2020 single-scattering
  raymarch — needs `intersect.hlsl` and `volume.hlsl`, see requires-comment at
  the top of the file).
- `hlsl/intersect.hlsl` — `IPlane`, `ISphere`, `IBox` (analytic ray/primitive intersections).
- `hlsl/volume.hlsl` — `PhaseIsotropic`, `PhaseRayleigh`, `PhaseHG`,
  `PhaseDualHG`, `PhaseCornetteShanks`, `BeerPowder`, `VolumeStep`,
  `DistanceFog`, `HeightFog`.
- `hlsl/water.hlsl` — `WaterDispersion`, `WaterWaveD` (analytic wave height +
  derivatives), `FresnelDielectric`, `BeerTransmittance`.
- `hlsl/camera.hlsl` — `CameraMatrix`, `FovToFocal`, `CameraRay`,
  `ThinLensRay` (depth of field), `OrthoRay`. **Read the matrix-order note at
  the top of this file before touching it** — `CameraMatrix`'s result must be
  used with `mul(vec, cam)`, not `mul(cam, vec)`.
- `hlsl/domain.hlsl` — `DomRepeatId`, `DomRepeat`, `DomRepeatLimited`,
  `DomRepeatMirror`, `DomPolar`, `DomPolarId`, `DomPolarPair`,
  `DomPolarSector`, `DomFold`, `DomTwist`, `DomBend` (transform a point before
  evaluating an SDF: repetition, mirroring, polar sectors, folds, twist, bend).
- `hlsl/operators.hlsl` — `OpUnion`, `OpSubtract`, `OpIntersect`, `Smin`,
  `Smax`, `SmoothSubtract`, `SminCubic`, `SminBlend`, `OpChamferUnion`,
  `OpStairsUnion`, `OpEngrave`, `OpRound`, `OpOnion`, `OpExtrude`, `OpRevolve`,
  `OpElongate` (combine/reshape SDF distances).
- `hlsl/sdf2d.hlsl` — 2D signed distance primitives: `SdCircle`, `SdBox`,
  `SdRoundedBox`, `SdSegment`, `SdUnevenCapsule`, `SdArc`,
  `SdEquilateralTriangle`, `SdTriangle`, `SdRegularPolygon`, `SdStar`,
  `SdVesica`, `SdMoon`, `SdHeart`, `SdRhombus`, `SdEllipse`,
  `SdQuadraticBezier`, `SdPie`, `SdHorseshoe`, `SdParabolaSegment`, `SdEgg`.
- `hlsl/sdf3d.hlsl` — 3D signed distance primitives: `SdSphere`, `SdBox`,
  `SdRoundBox`, `SdBoxFrame`, `SdTorus`, `SdCappedTorus`, `SdLink`, `SdPlane`,
  `SdCapsule`, `SdVerticalCapsule`, `SdCylinder`, `SdCappedCone`, `SdCone`,
  `SdRoundCone`, `SdEllipsoid`, `SdCutHollowSphere`, `SdHexPrism`,
  `SdOctahedron`, `SdGyroid`, `SdCutSphere`, `SdDeathStar`, `SdQuadraticBezier`.
- `hlsl/raymarch.hlsl` — `Raymarch`, `CalcNormal`, `SoftShadow`, `CalcAO`,
  `SdfThickness`. **Scene contract:** the including shader must define
  `float2 Map(float3 p)` returning `(distance, materialId)`. The source's
  Shadertoy-only `#define ZERO (min(iFrame,0))` compiler-inlining workaround
  was dropped (no HLSL/no iFrame equivalent) — use the `[loop]` attribute on
  the for-loop instead if FXC/DXC compile times or unrolling become a problem.
- `hlsl/pattern.hlsl` — `TriangleWave`, `FilteredChecker`, `FilteredGrid`,
  `FilteredStripes`, `HexGrid`, `HexEdgeDistance`, `TruchetArcs`.
- `hlsl/post.hlsl` — `FillAA`, `StrokeAA`, `AaOffset`, `Vignette`,
  `FilmGrain`, `DitherTPDF`. (GLSL's `dFdx`/`dFdy`/`fwidth` map directly to
  HLSL's `ddx`/`ddy`/`fwidth` — same names, same semantics.)
- `hlsl/noise.hlsl` — the big one: `QuinticFade`(+`Deriv`), `ValueNoiseD`,
  `ValueNoise` (2D/3D), `LatticeGradient`, `GradientNoiseD`/`GradientNoise`
  (2D/3D), `SimplexNoiseD`/`SimplexNoise`, `Fbm` (2D/3D), `ErodedFbm`,
  `RidgedFbm`, `Turbulence` (2D/3D), `BillowFbm` (2D/3D), `WarpedFbm`,
  `CurlNoise` (2D/3D), `Voronoi`, `VoronoiBorder`, `SmoothVoronoi`,
  `HybridTerrainHeight`, `InterleavedGradientNoise`, `R2Dither`.
- `hlsl/architecture.hlsl` — `BuildingProfile`, `FacadeWindowMask` (massing/
  material helpers for city blocks and facades — not a mesh generator).
- `hlsl/debug.hlsl` — `DebugDistance`, `DebugNormal`, `DebugIdColor`,
  `DebugHeat`. The source's `DEBUG_MODE` convention (switch what the shader
  outputs via a `#define`) needs a project-specific equivalent in HLSL — a
  `#define` + separate technique/pass, or a cbuffer flag; there's no
  Shadertoy-style custom-uniform shortcut.

### Deliberately not ported

- `templates/*.glsl` from the source repo — full Shadertoy demo scenes (ocean,
  procedural city, volumetric clouds, etc.), not reusable functions.
- `references/*.md` — prose guides (noise use-cases, SDF library guide,
  terrain production, water quality, rendering pipeline order). Worth reading
  in the original repo if a specific technique's *usage* is unclear; the
  function-level `@use`/range notes already carried over into this port's
  comments cover most of what's needed day to day.

## Recommended chain

```hlsl
#include "common.hlsl"
#include "lighting.hlsl"
#include "color.hlsl"
#include "tonemap.hlsl"

// ... accumulate linear HDR radiance per light with ShadePBR / WrapDiffuse / etc,
// add HemisphereLight or SimpleSky-sampled ambient ...

col *= exposure;
col = TonemapAgX(col);       // or TonemapNeutral for UI/2D-faithful work
col = LinearToSrgb(col);     // skip this line if the render target / swap chain
                              // format already does sRGB encode on write
```

## Porting notes (for anything new, e.g. a future shader-skills update)

Everything in the source repo's function library is ported (see "Deliberately
not ported" above for the two exceptions, which are templates/docs, not
functions). If the upstream repo adds something new, or a project needs a
function this port got wrong, here's the mechanical GLSL→HLSL recipe used
throughout:

- `vec2/vec3/vec4` → `float2/float3/float4`; `mat3` → `float3x3`
- `mix` → `lerp`; `fract` → `frac`; `clamp(x,0,1)` → prefer `saturate(x)`
- **Matrix multiply order is the one real gotcha.** GLSL `mat3` constructors
  fill columns, and GLSL's `*` has a left/right-dependent transpose built in.
  The net effect, worked out and verified against every matrix in this
  library: write the HLSL `float3x3` with the *same textual numbers in the
  same order* as the GLSL constructor, then
  - GLSL `v * mat3(...)` → HLSL `mul(M, v)`
  - GLSL `mat3(...) * v` → HLSL `mul(v, M)`
  (Note the arguments to `mul` are swapped relative to which side the GLSL
  matrix was written on.) Verify any new matrix port against a known output
  (e.g. white point, a specific color) before trusting it — a flipped `mul`
  order silently produces a *different valid-looking* but wrong matrix.
- GLSL fragment output / `gl_FragColor` → HLSL `return float4(...) : SV_TARGET`
  on the pixel shader entry point.

## Credit

Math and comments adapted from gokayfem/shader-skills
(https://github.com/gokayfem/shader-skills), MIT licensed. See that repo's
`CREDITS.md` for the original research/author credits behind each technique
(Filament, Ottosson's Oklab, Sobotka's AgX, Hill's ACES fit, etc.).

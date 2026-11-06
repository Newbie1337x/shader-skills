// camera.hlsl — look-at frames, primary rays, field of view, thin-lens depth
// of field. Ported to HLSL from gokayfem/shader-skills' camera.glsl (GLSL, MIT).
// See SKILL.md for port notes.
// requires: common.hlsl (TAU)
//
// Convention: uv = (2.0 * pixelCoord - resolution.xy) / resolution.y, so
// uv.y spans [-1, 1] and aspect is kept.
//
// IMPORTANT matrix-order note: CameraMatrix returns a float3x3 whose ROWS are
// (right, up, forward) — because the GLSL source builds `mat3(u, v, w)` (u,v,w
// as whole columns) and is then used as `cam * vec3(...)` (mat*vec). Per the
// GLSL->HLSL rule in SKILL.md, that becomes `mul(vec3(...), cam)` in HLSL, NOT
// `mul(cam, vec3(...))`. Every function below that uses `cam` follows that
// convention; don't flip the mul() argument order when adding new camera code.
// cam[2] still reads the forward vector w, matching the GLSL cam[2] (its
// third column) numerically, since cam's third ROW here equals that column.

// Camera-to-world frame looking from ro toward ta, with roll in radians.
// Rows are (right, up, forward) — use with mul(vec3(...), cam), see note above.
// Use: every 3D shader.
float3x3 CameraMatrix(float3 ro, float3 ta, float roll)
{
    float3 w = normalize(ta - ro);
    float3 up = float3(sin(roll), cos(roll), 0.0);
    float3 u = normalize(cross(w, up));
    float3 v = cross(u, w);
    return float3x3(u, v, w);
}

// Focal length (the z of the view-space ray) for a vertical field of view in degrees.
// Use: matching a reference photo, wide (90) vs telephoto (20) framing.
float FovToFocal(float fovDegrees) { return 1.0 / tan(radians(fovDegrees) * 0.5); }

// Primary ray direction for screen point uv. focal is about 1.5-2.5 for natural framing (see FovToFocal).
// Use: every 3D shader.
float3 CameraRay(float3x3 cam, float2 uv, float focal)
{
    return normalize(mul(float3(uv, focal), cam));
}

// Thin-lens depth of field. Moves the ray origin over a lens disk of radius
// aperture, and re-aims it so that points at distance focusDist stay sharp.
// xi is a pair of uniform random numbers in [0,1) (e.g. a hash of the pixel
// and frame). Average many samples (AA loop or multipass accumulation).
// Use: macro shots, product renders, cinematic focus pulls, bokeh.
void ThinLensRay(float3x3 cam, float2 uv, float focal, float aperture, float focusDist, float2 xi,
                  inout float3 ro, out float3 rd)
{
    float3 dir = normalize(mul(float3(uv, focal), cam));
    float ft = focusDist / dot(dir, cam[2]);
    float3 focusPoint = ro + dir * ft;
    float a = TAU * xi.x;
    float r = aperture * sqrt(xi.y);
    ro += mul(float3(r * cos(a), r * sin(a), 0.0), cam);
    rd = normalize(focusPoint - ro);
}

// Orthographic ray: parallel rays from a plane of half-height `size` centered on ro.
// Use: isometric scenes, technical illustrations, flat diorama looks.
void OrthoRay(float3x3 cam, float2 uv, float size, inout float3 ro, out float3 rd)
{
    ro += mul(float3(uv * size, 0.0), cam);
    rd = cam[2];
}

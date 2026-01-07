#include <metal_stdlib>
using namespace metal;

//  LavaShader.metal
//  Portfolio-App
//
//  Unified lava + chat bubble shader (single Metal field).

struct BlobData {
    float2 position;  // normalized 0..1
    float2 size;      // circle: size.x = radius normalized (by container height). rect: width/height normalized.
    float4 params;    // x: type (0=circle, 1=chat-rect), y: role (0=assistant, 1=user), z: seed, w: unused
};

struct Uniforms {
    float2 resolution;
    int blobCount;
    float threshold;
    float time;
};

vertex float4 vertex_lava_main(uint vertexID [[vertex_id]],
                               constant float2 *vertices [[buffer(0)]]) {
    return float4(vertices[vertexID], 0.0, 1.0);
}

// --- BACKGROUND FUNCTION (Radial Gradient + Dots) ---
static inline float3 getBackground(float2 uv, float aspect) {
    float3 centerColor = float3(0.12, 0.13, 0.15);
    float3 edgeColor = float3(0.0, 0.0, 0.0);
    float3 dotColor = float3(0.35, 0.35, 0.4);

    float2 centerPos = float2(0.5 * aspect, 0.5);
    float2 curPos = float2(uv.x * aspect, uv.y);
    float dist = length(curPos - centerPos);

    float radial = 1.0 - smoothstep(0.0, 1.2, dist);
    float3 bg = mix(edgeColor, centerColor, radial);

    float2 gridSpace = uv * 35.0;
    gridSpace.x *= aspect;

    float2 grid = fract(gridSpace) - 0.5;
    float d = length(grid);

    float dotMask = 1.0 - smoothstep(0.06, 0.1, d);
    return mix(bg, dotColor, dotMask * radial * 0.3);
}

// Signed distance to a rounded rectangle centered at origin.
static inline float sdRoundedBox(float2 p, float2 b, float r) {
    float2 q = abs(p) - (b - float2(r));
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

struct FieldResult {
    float total;
    float2 grad;
    float rect;
    float rectRoleWeighted;
    float seedWeighted;
};

static inline float2 signNotZero(float2 v) {
    return float2(v.x < 0.0 ? -1.0 : 1.0, v.y < 0.0 ? -1.0 : 1.0);
}

// Approx SDF gradient for rounded box (sufficient for lighting).
static inline void sdRoundedBoxWithGrad(float2 p, float2 b, float r, thread float &sd, thread float2 &g) {
    float2 q = abs(p) - (b - float2(r));
    float2 outside = max(q, 0.0);
    float distOutside = length(outside);
    float distInside = min(max(q.x, q.y), 0.0);
    sd = distOutside + distInside - r;

    float2 s = signNotZero(p);

    if (distOutside > 1e-6) {
        g = (outside / distOutside) * s;
    } else {
        // Inside: normal points to closest face (axis with larger q)
        if (q.x > q.y) {
            g = float2(s.x, 0.0);
        } else {
            g = float2(0.0, s.y);
        }
    }
}

static inline FieldResult computeFieldAndGrad(float2 aspectUV,
                                              float aspect,
                                              float time,
                                              constant BlobData *blobs,
                                              int blobCount) {
    FieldResult out;
    out.total = 0.0;
    out.grad = float2(0.0);
    out.rect = 0.0;
    out.rectRoleWeighted = 0.0;
    out.seedWeighted = 0.0;

    constexpr float eps = 0.002;
    const float eps2 = eps * eps;

    for (int i = 0; i < blobCount; i++) {
        float type = blobs[i].params.x;
        float seed = blobs[i].params.z;

        if (type < 0.5) {
            // Circle: influence = r^2 / (|d|^2 + eps^2)
            float2 p = blobs[i].position;
            float2 pos = float2(p.x * aspect, p.y);
            float r = max(blobs[i].size.x, 0.001);
            float2 d = aspectUV - pos;

            // Deform circle into an oriented oval (ellipse) without changing overall size.
            // Area-preserving anisotropy: scaleX = s, scaleY = 1/s (so determinant stays 1).
            float phase = seed * 6.2831853;
            float s = 1.0 + 0.22 * sin(time * 0.85 + phase);
            s = max(s, 0.35);

            float ang = phase * 0.37; // fixed orientation per blob
            float c = cos(ang);
            float sn = sin(ang);
            float2x2 rot = float2x2(c, -sn, sn, c);
            float2 dRot = rot * d;
            float2 dWarp = float2(dRot.x * s, dRot.y / s);

            float dist2 = dot(dWarp, dWarp);
            float denom = dist2 + eps2;
            float r2 = r * r;
            float influence = r2 / denom;
            out.total += influence;
            out.seedWeighted += influence * seed;

            // grad(influence) = -2*r^2 * (A^T * dWarp) / denom^2, where dWarp = A*d
            float k = (-2.0 * r2) / (denom * denom);
            float2 scaled = float2(dWarp.x * s, dWarp.y / s);
            float2x2 rotT = float2x2(c, sn, -sn, c);
            float2 gradVec = rotT * scaled;
            out.grad += gradVec * k;
        } else {
            // Rounded rect: treat chat bubbles as "filled" density to avoid a hollow outline.
            float2 p = blobs[i].position;
            float2 pos = float2(p.x * aspect, p.y);
            float2 size = max(blobs[i].size, float2(0.0));
            float2 halfSize = 0.5 * float2(size.x * aspect, size.y);
            float corner = min(halfSize.y * 0.7, 0.06);

            float sd;
            float2 g;
            sdRoundedBoxWithGrad(aspectUV - pos, halfSize, corner, sd, g);

            // Chat rectangles: filled density (strong inside, soft falloff outside).
            constexpr float kSoft = 0.012;
            constexpr float density = 0.95;

            float t = clamp(sd / kSoft, -20.0, 20.0);
            float influence = density / (1.0 + exp(t));
            out.total += influence;
            out.rect += influence;
            out.rectRoleWeighted += influence * clamp(blobs[i].params.y, 0.0, 1.0);
            out.seedWeighted += influence * seed;

            // d/dsd logistic = -(density/k) * p * (1-p), where p=influence/density
            float p01 = influence / max(density, 1e-4);
            float dInf_dSd = -(density / kSoft) * p01 * (1.0 - p01);
            out.grad += g * dInf_dSd;
        }
    }

    return out;
}

fragment float4 fragment_lava_main(float4 position [[position]],
                                   constant Uniforms &uniforms [[buffer(0)]],
                                   constant BlobData *blobs [[buffer(1)]]) {
    float2 uv = position.xy / uniforms.resolution;
    float aspect = uniforms.resolution.x / max(uniforms.resolution.y, 1.0);
    float2 aspectUV = float2(uv.x * aspect, uv.y);

    float3 background = getBackground(uv, aspect);

    FieldResult field0 = computeFieldAndGrad(aspectUV, aspect, uniforms.time, blobs, uniforms.blobCount);
    float field = field0.total;

    float threshold = max(uniforms.threshold, 0.001);
    // Use an iso-surface distance approximation for a stable, smooth merge.
    float gradLen = length(field0.grad);
    float sd = (threshold - field) / max(gradLen, 1e-3);

    // Derivative-based AA makes the boundary stable while moving/merging.
    float aa = max(fwidth(sd), 1.0 / max(uniforms.resolution.y, 1.0));
    float blobAlpha = smoothstep(aa, -aa, sd);
    if (blobAlpha < 0.001) {
        return float4(background, 1.0);
    }

    float2 gradN = field0.grad / max(gradLen, 1e-3);
    float3 normal = normalize(float3(gradN, 1.2));
    float3 viewDir = float3(0.0, 0.0, 1.0);

    // Damp refraction right at the boundary to reduce shimmer during merges.
    float dIn = -sd; // positive inside
    float boundaryDamp = mix(0.55, 1.0, smoothstep(0.0, 6.0 / max(uniforms.resolution.y, 1.0), dIn));
    float2 refOffset = normal.xy * 0.12 * boundaryDamp;

    float2 rUV = uv + refOffset * 0.98;
    float2 gUV = uv + refOffset * 1.00;
    float2 bUV = uv + refOffset * 1.02;

    float r = getBackground(rUV, aspect).r;
    float g = getBackground(gUV, aspect).g;
    float b = getBackground(bUV, aspect).b;
    float3 refractedColor = float3(r, g, b);
    refractedColor = mix(refractedColor, float3(0.95, 0.95, 1.0), 0.06);

    float rectSum = field0.rect;
    float roleMix = (rectSum > 0.0001) ? clamp(field0.rectRoleWeighted / rectSum, 0.0, 1.0) : 0.0;
    float3 assistantTint = float3(0.92, 0.93, 0.96);
    float3 userTint = float3(0.80, 0.90, 1.00);
    float3 chatTint = mix(assistantTint, userTint, roleMix);
    float chatMask = clamp(rectSum / max(field, 0.0001), 0.0, 1.0);
    float3 baseGlass = mix(refractedColor, refractedColor * chatTint, chatMask * 0.35);

    // --- Internal Shadow & Fresnel ---
    float ndotv = clamp(dot(normal, viewDir), 0.0, 1.0);
    float fresnel = pow(1.0 - ndotv, 3.0);
    float3 innerGlow = float3(1.0) * fresnel * 0.10;

    // --- Sharp Specular (The 'Sheen') ---
    float3 lightDir = normalize(float3(-0.4, 0.6, 1.0));
    float spec = pow(max(dot(normal, lightDir), 0.0), 140.0);
    float3 highlight = float3(1.0) * spec * 0.22;

    // Thin edge band for a clear border (dark, not a white halo).
    float borderWidth = 2.5 / max(uniforms.resolution.y, 1.0);
    float edgeIn = smoothstep(0.0, aa, dIn);
    float edgeOut = smoothstep(borderWidth, borderWidth + aa, dIn);
    float edgeBand = edgeIn * (1.0 - edgeOut);
    float borderDarken = 1.0 - (edgeBand * 0.12);

    // Inset shadow feel: smooth falloff inward (avoid a second outline band).
    float insetWidth = 18.0 / max(uniforms.resolution.y, 1.0);
    float insetShadow = (1.0 - smoothstep(0.0, insetWidth, dIn)) * 0.12;

    // Edge-lit glass: keep the shine tight to the boundary (avoid a full halo).
    float rim = edgeBand * 0.95 + fresnel * 0.12;
    float3 rimColor = float3(1.0) * rim * 0.30;

    float3 blobColor = (baseGlass + innerGlow + highlight) * borderDarken;
    blobColor = blobColor * (1.0 - insetShadow) + rimColor;
    float3 finalPixel = mix(background, blobColor, blobAlpha);
    return float4(finalPixel, 1.0);
}

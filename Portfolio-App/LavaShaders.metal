#include <metal_stdlib>
using namespace metal;

struct BlobData {
    float2 position;  // normalized 0..1 (all blob types)
    float2 size;      // circle: size.x = radius normalized (by container height). rect: width/height normalized.
    float4 params;    // x: type (0=circle, 1=rect), y: role (0=assistant, 1=user), z: seed, w: upwardSpeed (normalized/sec)
};

struct Uniforms {
    float2 resolution;
    int blobCount;
    float threshold;
    float time;
};

vertex float4 vertex_lava_main(uint vertexID [[vertex_id]],
                          constant float2 *vertices [[buffer(0)]]) {
    return float4(vertices[vertexID], 0, 1);
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
// p and b are in the same coordinate system (we use aspect-compensated UV space).
static inline float sdRoundedBox(float2 p, float2 b, float r) {
    float2 q = abs(p) - (b - float2(r));
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

struct FieldResult {
    float total;
    float rect;
    float rectRoleWeighted; // sum(influence * role)
};

static inline FieldResult computeField(float2 aspectUV,
                                       float aspect,
                                       constant BlobData *blobs,
                                       int blobCount,
                                       float time) {
    FieldResult out;
    out.total = 0.0;
    out.rect = 0.0;
    out.rectRoleWeighted = 0.0;

    // Kernel tuning: higher -> tighter edges, less "goo".
    // We use an inverse-square field to enable merging/interactions.
    constexpr float eps = 0.002;

    for (int i = 0; i < blobCount; i++) {
        float type = blobs[i].params.x;
        float seed = blobs[i].params.z;
        // Upward speed in normalized units / second; scaled into [0..1] intensity.
        // Stronger mapping so the effect reads clearly at typical rise speeds.
        float up = clamp(blobs[i].params.w * 10.0, 0.0, 1.0);

        if (type < 0.5) {
            // Circle blob
            float2 p = blobs[i].position;
            float2 pos = float2(p.x * aspect, p.y);
            float radius = max(blobs[i].size.x, 0.001);

            float2 d = aspectUV - pos;

            // Buoyancy deformation (subtle): bend sideways + micro ripple while rising.
            // Kept small to avoid a watery look.
            float phase = (time * 2.2) + (seed * 0.17);

            // Bend: x-offset proportional to vertical position within blob.
            float bend = up * 0.18 * sin(phase);
            d.x += bend * (d.y / radius) * radius;

            // Ripple: tiny lateral scallop, stronger near lower half (trailing region).
            float trailing = smoothstep(0.0, 1.0, (d.y / radius) * 0.6 + 0.5);
            float ripple = up * 0.060 * sin((d.y / radius) * 6.5 + phase * 1.3);
            d.x += ripple * trailing * radius;

            // Stretch: slightly elongate in rise direction.
            float stretchY = 1.0 + up * 0.30;
            float squashX = 1.0 - up * 0.16;

            // Midsection pull ("waist" pinch) while rising.
            // This narrows the blob around its center without looking watery.
            float yN = d.y / radius; // -1..1 (approx)
            float mid = exp(-pow(yN / 0.55, 2.0)); // peak at center, fades toward ends
            float pinch = up * (0.22 + 0.06 * sin(phase * 0.7)) * mid;
            squashX *= (1.0 - pinch);
            squashX = max(squashX, 0.50);

            float2 dm = float2(d.x / max(squashX, 0.65), d.y / max(stretchY, 1.0));

            float dist = length(dm);
            float denom = max(dist * dist, eps * eps);
            float influence = (radius * radius) / denom;
            out.total += influence;
        } else {
            // Rect (chat bubble): rounded-rect SDF contributes to the same field.
            float2 p = blobs[i].position;
            float2 pos = float2(p.x * aspect, p.y);
            float2 size = max(blobs[i].size, float2(0.0));
            float2 halfSize = 0.5 * float2(size.x * aspect, size.y);
            // Corner radius: proportional to height, but capped.
            float r = min(halfSize.y * 0.7, 0.06);

            float2 q = aspectUV - pos;

            // Same buoyancy feel for chat bubbles, but extra subtle.
            float phase = (time * 2.0) + (seed * 0.13);
            // Requested: make chat deformation much stronger.
            // Note: we clamp squash to keep the rounded-rect SDF stable.
            constexpr float chatBoost = 20.0;
            float bend = up * (0.10 * chatBoost) * sin(phase);
            q.x += bend * (q.y / max(halfSize.y, 0.001)) * halfSize.y;

            float stretchY = 1.0 + up * (0.16 * chatBoost);
            float squashX = 1.0 - up * (0.10 * chatBoost);

            // Midsection pull for chat bubbles while rising.
            float yN = q.y / max(halfSize.y, 0.001);
            float mid = exp(-pow(yN / 0.65, 2.0));
            float pinch = up * (0.14 * chatBoost) * mid;
            squashX *= (1.0 - pinch);

            float2 q2 = float2(
                q.x / max(squashX, 0.55),
                q.y / max(stretchY, 1.0)
            );

            float sd = sdRoundedBox(q2, halfSize, r);
            float dist = max(sd, 0.0);
            float denom = max(dist * dist, eps * eps);
            // Weight by min dimension so small bubbles don't vanish.
            float w = max(min(halfSize.x, halfSize.y), 0.01);
            // Rects use a slightly weaker kernel so the threshold contour hugs the rounded-rect boundary.
            // This makes bend/pinch deformation visually readable (without looking watery).
            constexpr float rectInfluenceScale = 0.06;
            float influence = (w * w * rectInfluenceScale) / denom;

            out.total += influence;
            out.rect += influence;
            out.rectRoleWeighted += influence * clamp(blobs[i].params.y, 0.0, 1.0);
        }
    }

    return out;
}

// ========== MAIN FRAGMENT SHADER ==========

fragment float4 fragment_lava_main(float4 position [[position]],
                              constant Uniforms &uniforms [[buffer(0)]],
                              constant BlobData *blobs [[buffer(1)]]) {

    float2 uv = position.xy / uniforms.resolution;
    float aspect = uniforms.resolution.x / max(uniforms.resolution.y, 1.0);
    float2 aspectUV = float2(uv.x * aspect, uv.y);

    // 1) Background
    float3 background = getBackground(uv, aspect);

    // 2) Field + alpha
    FieldResult field0 = computeField(aspectUV, aspect, blobs, uniforms.blobCount, uniforms.time);
    float field = field0.total;

    // Threshold here is in "influence" units. Lower -> thicker blobs.
    float threshold = max(uniforms.threshold, 0.001);
    float blobAlpha = smoothstep(threshold, threshold + 0.15, field);
    if (blobAlpha < 0.001) {
        return float4(background, 1.0);
    }

    // 3) Gradient-based normal (numeric) for stable glass — no wobble.
    float px = 1.0 / max(uniforms.resolution.y, 1.0);
    float2 e = float2(px, 0.0);

    float fx1 = computeField(aspectUV + float2(e.x * aspect, 0.0), aspect, blobs, uniforms.blobCount, uniforms.time).total;
    float fx0 = computeField(aspectUV - float2(e.x * aspect, 0.0), aspect, blobs, uniforms.blobCount, uniforms.time).total;
    float fy1 = computeField(aspectUV + float2(0.0, e.x), aspect, blobs, uniforms.blobCount, uniforms.time).total;
    float fy0 = computeField(aspectUV - float2(0.0, e.x), aspect, blobs, uniforms.blobCount, uniforms.time).total;

    float2 grad = float2(fx1 - fx0, fy1 - fy0) / (2.0 * e.x);
    float3 normal = normalize(float3(grad, 1.2));
    float3 viewDir = float3(0.0, 0.0, 1.0);

    // 4) Refraction & subtle chromatic aberration (glass morphism)
    float2 refOffset = normal.xy * 0.12;

    float2 rUV = uv + refOffset * 0.98;
    float2 gUV = uv + refOffset * 1.00;
    float2 bUV = uv + refOffset * 1.02;

    float r = getBackground(rUV, aspect).r;
    float g = getBackground(gUV, aspect).g;
    float b = getBackground(bUV, aspect).b;
    float3 refractedColor = float3(r, g, b);
    refractedColor = mix(refractedColor, float3(0.95, 0.95, 1.0), 0.06);

    // 5) Role tint (only affects regions dominated by chat rectangles)
    float rectSum = field0.rect;
    float roleMix = (rectSum > 0.0001) ? clamp(field0.rectRoleWeighted / rectSum, 0.0, 1.0) : 0.0;
    float3 assistantTint = float3(0.92, 0.93, 0.96);
    float3 userTint = float3(0.80, 0.90, 1.00);
    float3 chatTint = mix(assistantTint, userTint, roleMix);
    float chatMask = saturate(rectSum / max(field, 0.0001));
    float3 baseGlass = mix(refractedColor, refractedColor * chatTint, chatMask * 0.35);

    // 6) Lighting
    float fresnel = pow(1.0 - dot(normal, viewDir), 4.0);
    float3 insetGlow = float3(1.0) * fresnel * 0.08;

    float3 lightDir = normalize(float3(-0.5, 0.6, 1.0));
    float spec = pow(max(dot(normal, lightDir), 0.0), 60.0);
    float3 specularColor = float3(1.0) * spec * 0.55;

    // Subtle border stroke from field slope
    float edge = 1.0 - smoothstep(threshold, threshold + 0.25, field);
    float3 borderStroke = float3(1.0) * edge * 0.65;

    float3 blobColor = baseGlass + insetGlow + specularColor + borderStroke;
    float3 finalPixel = mix(background, blobColor, blobAlpha);
    return float4(finalPixel, 1.0);
}

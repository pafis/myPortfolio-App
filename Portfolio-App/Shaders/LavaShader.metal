#include <metal_stdlib>
using namespace metal;

//  LavaShader.metal
//  Portfolio-App
//  Technique: 2D SDF + "Convex Squircle" Height Mapping.
//  Visual Style: Dark Mode (Apple-like) + Optical Refraction.

struct BlobData {
    float2 position;
    float2 size;
    float4 params;
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

// --- BACKGROUND GENERATOR (Restored Dark Mode) ---
static inline float3 getBackground(float2 uv, float aspect) {
    // Deep, sleek dark background
    float3 c1 = float3(0.12, 0.13, 0.15); // Dark Slate
    float3 c2 = float3(0.02, 0.02, 0.03); // Almost Black
    
    // Vertical gradient
    float3 bg = mix(c2, c1, uv.y + 0.5);
    
    // Grid dots (Subtle, for depth reference)
    float2 grid = fract(uv * 30.0 * float2(aspect, 1.0)) - 0.5;
    float d = length(grid);
    float dots = smoothstep(0.06, 0.04, d);
    
    // Add dots in a slightly lighter grey
    bg += float3(0.15) * dots;
    
    return bg;
}

// --- SDF PRIMITIVES ---

static inline float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

static inline float sdCircle(float2 p, float r) {
    return length(p) - r;
}

// Cheap angular ripple to break perfect circles (surface-tension-like wobble).
static inline float radiusRipple(float2 q, float t, float seed) {
    float ang = atan2(q.y, q.x);
    float w1 = sin(ang * 3.0 + t * 0.55 + seed);
    float w2 = sin(ang * 5.0 - t * 0.35 + seed * 1.7);
    // Increased amplitude to match the visible wobble of BlobModalView
    return (w1 * 0.15 + w2 * 0.08);
}

static inline float sdBox(float2 p, float2 b, float r) {
    float2 d = abs(p) - b + float2(r);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - r;
}

// --- CORE DISTANCE FUNCTION ---
static inline float getDistance(float2 p, float aspect, float time, constant BlobData *blobs, int blobCount) {
    float dLava = 100.0;
    float dRect = 100.0;
    
    for (int i = 0; i < blobCount; i++) {
        float type = blobs[i].params.x;
        float2 center = float2(blobs[i].position.x * aspect, blobs[i].position.y);
        
        if (type < 0.5) {
            // Lava
            // NOTE: `blobs[i].size.x` is already a normalized radius.
            // Keep only a small extra "soft aura" so blobs don't balloon to screen-filling sizes.
            float rawTemp = blobs[i].params.y;
            bool isDebris = (rawTemp < 0.0);

            // Smaller aura for debris bubbles so they don't glue together.
            float aura = isDebris ? 0.006 : 0.010;
            float r = max(blobs[i].size.x, 0.001) + aura;
            // Wobble is applied on the Swift side (so text + blob stay perfectly aligned).
            // Here we add *shape* dynamics: velocity-based stretch + subtle boundary ripples.
            float temp = clamp(rawTemp, 0.0, 1.0);
            float seed = blobs[i].params.z;
            float speedN = max(0.0, blobs[i].params.w);

            // Interfacial tension pulls toward spherical when motion is low.
            // When rising fast + hot, allow more elongation and instability.
            float tension = 1.0 - smoothstep(0.02, 0.10, speedN);
            float buoyStretch = clamp(speedN * (6.0 + 4.0 * temp), 0.0, 0.35);
            float stretch = mix(buoyStretch, 0.06, tension);

            float2 q = p - center;

            // Elongate slightly along the motion axis (upward motion => vertical stretch).
            // Scaling the coordinate shrinks/expands the distance field accordingly.
            float2 qWarp = q;
            qWarp.y *= (1.0 - stretch);
            qWarp.x *= (1.0 + stretch * 0.35);

            // Break perfect circles with a small angular ripple (stronger when hot).
            float ripple = radiusRipple(q, time, seed);
            // Increased wobble amount mix for more organic feel
            float rippleAmt = mix(0.15, 0.35, temp);
            float rWarp = r * (1.0 + ripple * rippleAmt);

            // Rayleigh–Taylor pinching: hot + rising blobs form necks and split into lobes.
            float instability = smoothstep(0.45, 0.95, temp) * smoothstep(0.015, 0.08, speedN);
            float lobeOffset = instability * rWarp * 0.95;

            float d0 = sdCircle(qWarp, rWarp);
            float d1 = sdCircle(qWarp - float2(0.0, lobeOffset), rWarp * 0.90);
            float d2 = sdCircle(qWarp + float2(0.0, lobeOffset), rWarp * 0.90);

            float dLobes = smin(d1, d2, rWarp * 0.70);
            float dist = smin(d0, dLobes, rWarp * 0.55);
            // Smaller smoothing => harder merges (less continuous "river").
            // Make the reservoir (offscreen pool, y>1) even harder to merge into the column.
            float mergeK = (blobs[i].position.y > 1.02) ? 0.04 : 0.06;
            // Debris should stay separated: much harder to merge.
            mergeK = isDebris ? 0.02 : mergeK;
            dLava = smin(dLava, dist, mergeK);
        } else {
            // Rect
            float2 size = max(blobs[i].size, float2(0.001));
            float2 b = float2(size.x * aspect, size.y) * 0.5;
            
            float role = blobs[i].params.y;
            float seed = blobs[i].params.z;

            // Larger corner radius for the big detail/background rect.
            float cornerR = (role > 1.5) ? 0.075 : 0.02;

            // Keep the big detail/background rect stable (no wobble), but allow wobble for other rects.
            float rectRippleAmt = (role > 1.5) ? 0.0 : 0.08;
            float ripple = radiusRipple(p - center, time, seed);

            float dist = sdBox(p - center, b, cornerR);
            dist -= ripple * rectRippleAmt * min(size.x, size.y);
            
            dRect = min(dRect, dist);
        }
    }
    
    return smin(dLava, dRect, 0.04);
}

// --- SQUIRCLE HEIGHT PROFILE ---
// y = (1 - (1-x)^4)^0.25
static inline float getSquircleHeight(float distFromEdge, float bezelWidth) {
    float x = clamp(distFromEdge / bezelWidth, 0.0, 1.0);
    float invX = 1.0 - x;
    float val = 1.0 - (invX * invX * invX * invX);
    return pow(val, 0.25);
}

fragment float4 fragment_lava_main(float4 position [[position]],
                                   constant Uniforms &uniforms [[buffer(0)]],
                                   constant BlobData *blobs [[buffer(1)]]) {
    
    float2 uv = position.xy / uniforms.resolution;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    float2 p = uv;
    p.x *= aspect;
    
    // 1. Base Distance
    float d = getDistance(p, aspect, uniforms.time, blobs, uniforms.blobCount);
    
    // 2. Alpha Mask
    float alpha = 1.0 - smoothstep(-0.001, 0.001, d);
    if (alpha < 0.001) return float4(getBackground(uv, aspect), 1.0);
    
    // 3. HEIGHT FIELD
    float bezelWidth = 0.10;
    float height = getSquircleHeight(-d, bezelWidth);
    
    // 4. NORMAL CALCULATION (optimized, stabilized)
    // Take screen-space derivatives of the *height field* directly, but scale them to match the
    // original fixed-step sampling (e = 0.001 in p-space). This keeps the bevel/band thickness.
    float e = 0.001;
    float pixelsPerEx = (e * uniforms.resolution.x) / aspect;
    float pixelsPerEy = (e * uniforms.resolution.y);
    float dhx = dfdx(height) * pixelsPerEx;
    float dhy = dfdy(height) * pixelsPerEy;
    float3 normal = normalize(float3(-dhx, -dhy, 0.05));

    // 5. LIQUID GLASS SHADING (Adjusted for Dark Mode)
    
    // A. Refraction
    // In dark mode, we want the "lens" to pull in brighter parts of the background
    float2 refractionOffset = normal.xy * -0.06;
    float3 bgRefracted = getBackground(uv + refractionOffset, aspect);
    
    // B. Specular Highlights
    float3 lightDir = normalize(float3(-0.5, -0.8, 1.0));
    float spec = pow(max(dot(normal, lightDir), 0.0), 60.0);
    float3 highlight = float3(1.0) * spec * 0.8;
    
    // C. Internal Tint
    // Darker glass for the sleek look.
    // Mixes slightly blue/white at the "thickest" parts (center) to simulate volume.
    float3 glassTint = float3(0.85, 0.90, 1.0);
    float3 bodyColor = bgRefracted * mix(float3(0.95), glassTint, height * 0.3);
    
    // D. Rim Light
    float rim = smoothstep(0.5, 0.8, 1.0 - normal.z);
    float3 rimColor = float3(1.0) * rim * 0.3;
    
    // E. Edge Darkening (Crucial for dark mode separation)
    float edgeDarken = smoothstep(0.0, 0.04, height);
    float contrastBorder = 0.6 + 0.4 * edgeDarken;
    
    float3 finalColor = (bodyColor + highlight + rimColor) * contrastBorder;

    return float4(mix(getBackground(uv, aspect), finalColor, alpha), 1.0);
}

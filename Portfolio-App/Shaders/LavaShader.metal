//
//  LavaShader.metal
//  Portfolio-App
//
//  Created by Pascal Fischer on 1/3/26.
//

#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float2 resolution;
    int blobCount;
    float threshold;
    float time;
};

// --- BACKGROUND FUNCTION (Radial Gradient + Dots) ---
float3 getBackground(float2 uv, float aspect) {
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
    
    float3 finalColor = mix(bg, dotColor, dotMask * radial * 0.3);
    
    return finalColor;
}

vertex float4 vertex_main(uint vertexID [[vertex_id]],
                          constant float2 *vertices [[buffer(0)]]) {
    return float4(vertices[vertexID], 0, 1);
}

fragment float4 fragment_main(float4 position [[position]],
                              constant Uniforms &uniforms [[buffer(0)]],
                              constant float4 *blobs [[buffer(1)]]) {

    float2 uv = position.xy / uniforms.resolution;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    float2 aspectUV = uv;
    aspectUV.x *= aspect;

    // --- 1. RENDER BACKGROUND ---
    float3 background = getBackground(uv, aspect);

    // --- 2. BLOB FIELD CALCULATION ---
    float field = 0.0;
    float2 grad = float2(0.0);
    float t = uniforms.time;

    for (int i = 0; i < uniforms.blobCount; i++) {
        float2 p = blobs[i].xy;
        p.x *= aspect;
        
        float2 d = aspectUV - p;
        float dist = length(d);
        float angle = atan2(d.y, d.x);

        float uniqueOffset = blobs[i].w;
        
        float distortion = sin(angle * 2.0 + t * 1.5 + uniqueOffset) * 0.12;
        distortion += sin(angle + t * 0.5) * 0.03;
        
        float baseRadius = blobs[i].z * 3.1;
        float radius = baseRadius * (1.0 + distortion);

        if (dist < radius) {
            float x = dist / radius;
            float f = 1.0 - x * x;
            float f3 = f * f * f;
            field += f3;
            float g = -6.0 * f * f / (radius * max(dist, 0.0001));
            grad += d * g;
        }
    }

    float blobAlpha = smoothstep(uniforms.threshold, uniforms.threshold + 0.005, field);

    if (blobAlpha < 0.001) {
        return float4(background, 1.0);
    }

    // --- 3. SURFACE TURBULENCE ---
    float wave1 = sin(uv.x * 10.0 + t * 2.0);
    float wave2 = cos(uv.y * 12.0 + t * 2.5);
    float turbulence = (wave1 + wave2) * 0.5;
    
    float3 wobbleNormal = float3(turbulence * 0.05, turbulence * 0.05, 0.0);
    float3 baseNormal = normalize(float3(grad, 1.2));
    float3 normal = normalize(baseNormal + wobbleNormal);
    float3 viewDir = float3(0.0, 0.0, 1.0);
    
    // --- 4. REFRACTION & ABERRATION ---
    float2 refOffset = normal.xy * 0.15;
    
    float2 rUV = uv + refOffset * 0.98;
    float r = getBackground(rUV, aspect).r;
    float2 gUV = uv + refOffset * 1.0;
    float g = getBackground(gUV, aspect).g;
    float2 bUV = uv + refOffset * 1.02;
    float b = getBackground(bUV, aspect).b;
    
    float3 refractedColor = float3(r, g, b);
    refractedColor = mix(refractedColor, float3(0.95, 0.95, 1.0), 0.05);

    // --- 5. LIGHTING ---
    float borderFactor = smoothstep(uniforms.threshold, uniforms.threshold + 0.01, field);
    float edgeMask = 1.0 - borderFactor;
    float3 borderStroke = float3(1.0) * edgeMask * 0.9;

    float topHighlight = smoothstep(0.1, 1, normal.y) * 0.01;
    float leftHighlight = smoothstep(0.1, 1, normal.x) * 0.02;
    float3 directionalLighting = float3(1.0) * (topHighlight + leftHighlight);

    float fresnel = pow(1.0 - dot(normal, viewDir), 4.0);
    float3 insetGlow = float3(1.0) * fresnel * 0.07;

    float3 lightDir = normalize(float3(-0.5, 0.5, 1.0));
    float spec = pow(max(dot(normal, lightDir), 0.0), 50.0);
    float3 specularColor = float3(1.0) * spec * 0.6;

    float3 blobColor = refractedColor + directionalLighting + insetGlow + borderStroke + specularColor;
    float3 finalPixel = mix(background, blobColor, blobAlpha);

    return float4(finalPixel, 1.0);
}

#include <metal_stdlib>
using namespace metal;

struct Blob {
    float2 position;
    float radius;
    float padding;
};

struct Uniforms {
    float2 resolution;
    int blobCount;
    float threshold;
};

vertex float4 vertex_main(uint vertexID [[vertex_id]],
                          constant float2 *vertices [[buffer(0)]]) {
    // Output position in Clip Space (NDC -1 to 1)
    return float4(vertices[vertexID], 0, 1);
}

fragment float4 fragment_main(float4 position [[position]],
                              constant Uniforms &uniforms [[buffer(0)]],
                              constant Blob *blobs [[buffer(1)]]) {
    
    float2 uv = position.xy;
    float influence = 0.0;
    
    for (int i = 0; i < uniforms.blobCount; i++) {
        float2 blobPos = blobs[i].position;
        
        // FIX: Removed the Y-Flip.
        // iOS Metal and SwiftUI both use Top-Left origin for pixel coordinates.
        
        float dist = distance(uv, blobPos);
        dist = max(dist, 0.1);
        
        influence += (blobs[i].radius * blobs[i].radius) / (dist * dist);
    }
    
    if (influence > uniforms.threshold) {
        float value = smoothstep(uniforms.threshold, uniforms.threshold + 0.05, influence);
        
        float3 darkColor = float3(0.8, 0.1, 0.0); // Deeper Red
        float3 lightColor = float3(1.0, 0.6, 0.1); // Bright Orange
        
        // Calculate glow based on how "deep" we are inside the threshold
        float3 color = mix(darkColor, lightColor, min(1.0, (influence - uniforms.threshold) * 0.5));
        
        return float4(color, 1.0);
    } else {
        return float4(0, 0, 0, 0);
    }
}

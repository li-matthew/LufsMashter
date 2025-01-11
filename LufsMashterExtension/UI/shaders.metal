//
//  shaders.metal
//  LoudMashter
//
//  Created by mashen on 12/11/24.
//

#include <metal_stdlib>
using namespace metal;

constant uint bufferLength [[function_constant(0)]];

struct VertexOut {
    float4 position [[position]];
    float4 color;
    bool isValid;
};

vertex VertexOut vertexData(const device float *vertices [[ buffer(0) ]],
                          uint vertexID [[ vertex_id ]]) {
    VertexOut out;
    
    float x = 1.0 - (float(vertexID) / float(bufferLength - 1) * 2.0); // Map to [-1, 1]
    float y = 2.0 * vertices[vertexID] - 1.0;
    out.isValid = (vertices[vertexID] != 0.0 && vertices[vertexID] != 1.0);
    out.position = float4(x, y, 0.0, 1.0);
    return out;
}

vertex float4 gridData(const device float *hor [[ buffer(0) ]],
                       uint vertexID [[ vertex_id ]]) {

    uint lineIndex = vertexID / 2;
    bool isStartVertex = (vertexID % 2 == 0);
    
    float x = isStartVertex ? -1.0 : 1.0;
    float y = 2 * hor[lineIndex] - 1;
    
    return float4(x, y, 0.0, 1.0);
}

fragment float4 fragmentData(constant float4 &color [[buffer(1)]]) {
    return color;
}

//
//  shaders.metal
//  LoudMashter
//
//  Created by mashen on 12/11/24.
//

#include <metal_stdlib>
using namespace metal;

vertex float4 vertexData(const device float2 *vertices [[ buffer(0) ]],
                          uint vertexID [[ vertex_id ]]) {
    return float4(vertices[vertexID], 0.0, 1.0);
}

fragment float4 fragmentData() {
    return float4(1.0, 1.0, 1.0, 1.0); // White color
}

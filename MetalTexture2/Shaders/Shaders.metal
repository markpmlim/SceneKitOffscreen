//  Created by Mark Lim Pak Mun on 31/03/2019.
//  Copyright © 2019 Incremental Innovation. All rights reserved.

#include <metal_stdlib>
using namespace metal;
#include <SceneKit/scn_metal>

// A node with a geometry of class SCNPlane was instantiated.
struct myPlaneNodeBuffer {
    float4x4 modelTransform;
    float4x4 modelViewTransform;
    float4x4 normalTransform;
    float4x4 modelViewProjectionTransform;
    float2x3 boundingBox;
};

typedef struct {
    float3 position     [[ attribute(SCNVertexSemanticPosition) ]];
    float2 texCoords    [[ attribute(SCNVertexSemanticTexcoord0) ]];
} VertexInput;

struct Uniforms
{
    float2 resolution;
};

struct SimpleVertexWithUV
{
    float4 position [[position]];   // clip space
    float2 texCoords;
};

vertex SimpleVertexWithUV
vertex_function(VertexInput                 in          [[ stage_in ]],
                constant SCNSceneBuffer&    scn_frame   [[buffer(0)]],
                constant myPlaneNodeBuffer& scn_node    [[buffer(1)]])
{
    SimpleVertexWithUV vert;
    vert.position = scn_node.modelViewProjectionTransform * float4(in.position, 1.0);
    // pass the texture coords to fragment function.
    vert.texCoords = in.texCoords;
    return vert;
}

fragment half4
fragment_function(SimpleVertexWithUV                interpolated    [[stage_in]],
                  texture2d<float, access::sample>  diffuseTexture  [[texture(0)]])
{
/*
    float4 fragColor = interpolated.position;
    fragColor += 1.0; // move from range -1..1 to 0..2
    fragColor *= 0.5; // scale from range 0..2 to 0..1

    return half4(fragColor);
*/
    constexpr sampler sampler2d(coord::normalized,
                                filter::linear, address::repeat);
    float4 color = diffuseTexture.sample(sampler2d,
                                         interpolated.texCoords);
    return half4(color);

}

//=========
void kernel kernel_function(uint2                           gid         [[ thread_position_in_grid ]],
                            texture2d<float, access::write> outTexture  [[texture(0)]])
{
    // Check if the pixel is within the bounds of the output texture
    if ((gid.x >= outTexture.get_width()) ||
        (gid.y >= outTexture.get_height()))
    {
        // Return early if the pixel is out of bounds
        return;
    }
    float2 resolution = float2(outTexture.get_width(),
                               outTexture.get_height());
    float2 position = float2(gid);
    float4 pixelColor = float4(position/resolution, 0.0, 1.0);
    pixelColor.y = 1.0 - pixelColor.y;  // Invert the green component.
    outTexture.write(pixelColor, gid);
}

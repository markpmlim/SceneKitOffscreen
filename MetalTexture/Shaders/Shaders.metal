//  Created by Mark Lim Pak Mun on 31/03/2019.
//  Copyright © 2019 Incremental Innovation. All rights reserved.

#include <metal_stdlib>
using namespace metal;
#include <SceneKit/scn_metal>

struct Uniforms
{
    float2 resolution;
};

typedef struct {
    float4 position;
    float2 texCoords;
} QuadVertex;

constant const QuadVertex quadVertices[4] = {
    {{-1.0, -1.0, 0.0, 1.0}, {0.0, 1.0}},
    {{ 1.0, -1.0, 0.0, 1.0}, {1.0, 1.0}},
    {{-1.0,  1.0, 0.0, 1.0}, {0.0, 0.0}},
    {{ 1.0,  1.0, 0.0, 1.0}, {1.0, 0.0}},
};

struct VertexOutput
{
    float4 position [[position]];   // clip space
    float2 texCoords;
};

vertex VertexOutput
vertex_function(unsigned int vid  [[ vertex_id ]])
{
    // The position of the vertices of the triangle strip are already in NDC.
    float4x4 renderedCoordinates = float4x4(float4( -1.0, -1.0, 0.0, 1.0 ),      /// (x, y, z, w)
                                            float4(  1.0, -1.0, 0.0, 1.0 ),
                                            float4( -1.0,  1.0, 0.0, 1.0 ),
                                            float4(  1.0,  1.0, 0.0, 1.0 ));
    
    // In Metal, the uv coords starts with (0, 0) at the top-left corner which
    // is identical to the system adopted by Apple's Core Graphics framework.
    float4x2 textureCoordinates = float4x2(float2( 0.0, 1.0 ),                  /// (s, t)
                                           float2( 1.0, 1.0 ),
                                           float2( 0.0, 0.0 ),
                                           float2( 1.0, 0.0 ));
    
    VertexOutput outVertex;
    outVertex.position = renderedCoordinates[vid];
    outVertex.texCoords = textureCoordinates[vid];
    //QuadVertex quadVertex = quadVertices[vid];
    //outVertex.position = quadVertices[vid].position;
    //outVertex.texCoords = quadVertices[vid].texCoords;

    return outVertex;
}

// The equivalent of gl_FragCoord is available to Metal fragment functions as
// the interpolated position which is expressed in pixel coordinates.
fragment half4
fragment_function(VertexOutput      interpolated    [[stage_in]],
                  constant  float2& resolution      [[buffer(0)]])
{
    float2 position = float2(interpolated.position.x, interpolated.position.y);
    float4 pixelColor = float4(position/resolution, 0.0, 1.0);

    pixelColor.y = 1.0 - pixelColor.y;  // Invert the green component.
    return half4(pixelColor);
}

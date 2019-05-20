#version 330 core

out vec2 TexCoords;         // unused

void main(void)
{
    // the coords of a square made of 2 triangle strips.
    const vec4 verts[4] = vec4[4](vec4(-1.0, -1.0, 0.5, 1.0),
                                  vec4( 1.0, -1.0, 0.5, 1.0),
                                  vec4(-1.0,  1.0, 0.5, 1.0),
                                  vec4( 1.0,  1.0, 0.5, 1.0));
    // the tex coords of the positions of 2 triangle strips.
    const vec2 uvCoords[4] = vec2[4](vec2(0.0, 0.0),
                                     vec2(1.0, 0.0),
                                     vec2(0.0,  1.0),
                                     vec2(1.0,  1.0));
    TexCoords = uvCoords[gl_VertexID];
    gl_Position = verts[gl_VertexID];
}

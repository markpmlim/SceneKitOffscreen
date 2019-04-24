#version 330 core

in vec4 aVertex;
in vec2 aTexCoord0;

uniform mat4 uModelViewProjectionMatrix;

out vec2 TexCoords;

void main(void)
{
    //TexCoords = aTexCoord0;
    TexCoords = vec2(aTexCoord0.s, 1.0 - aTexCoord0.t);
    gl_Position = uModelViewProjectionMatrix * aVertex;
}

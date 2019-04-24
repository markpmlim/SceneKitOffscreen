#version 330 core

uniform vec2 resolution;    // dimensions of view port

in vec2 TexCoords;

// output to color attachment0
out vec4 fragmentColor;

void main(void)
{
    vec2 position = (gl_FragCoord.xy) / resolution;
    fragmentColor = vec4(position, 0.0, 1.0);
}

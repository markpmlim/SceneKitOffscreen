#version 330 core

uniform sampler2D colorTexture;

in vec2 TexCoords;

out vec4 fragmentColor;

void main(void)
{
    fragmentColor = texture(colorTexture, TexCoords);
}

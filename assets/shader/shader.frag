#version 450

layout(location = 0) out vec4 outColor;

layout(location = 0) in vec4 out_color;
layout(location = 1) in vec2 out_texture;

layout(set = 1, binding = 5) uniform sampler2D sampler

void main() {
  outColor = texture(sampler, out_texture);
}


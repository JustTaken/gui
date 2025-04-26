#version 450

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec2 in_texture;

layout(location = 0) out vec4 out_color;

layout(binding = 0) uniform Projection {
  mat4 projection;
  mat4 view;
};

layout(binding = 1) readonly buffer InstanceModel {
  mat4 models[];
};

layout(binding = 2) readonly buffer InstanceColor {
  vec4 colors[];
};

void main() {
  int index = gl_InstanceIndex;
  gl_Position = projection * view * models[index] * vec4(in_position, 1.0);

  out_color = colors[index];
}


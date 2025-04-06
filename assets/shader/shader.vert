#version 450

layout(location = 0) in vec2 in_position;
layout(location = 0) out vec3 out_color;

layout(binding = 0) uniform Projection {
  mat4 projection;
};

layout(binding = 1) readonly buffer InstanceModel {
  mat4 models[];
};

layout(binding = 2) readonly buffer InstanceColor {
  vec3 color[];
};

void main() {
  int index = gl_InstanceIndex;
  gl_Position = projection * models[index] * vec4(in_position, 0.0, 1.0);

  out_color = color[index];
}


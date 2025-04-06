#version 450

layout(location = 0) in vec2 in_position;

layout(binding = 0) uniform Projection {
  mat4 projection;
};

layout(binding = 1) readonly buffer Instance {
  mat4 models[];
};

void main() {
  int index = gl_InstanceIndex;
  gl_Position = projection * models[index] * vec4(in_position, 0.0, 1.0);
}


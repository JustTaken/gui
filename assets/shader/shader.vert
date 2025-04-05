#version 450

layout(location = 0) in vec2 in_position;

layout(binding = 0) readonly buffer Instance {
  mat4 models[];
};

void main() {
  int index = gl_InstanceIndex;
  gl_Position = models[index] * vec4(in_position, 0.0, 1.0);
}


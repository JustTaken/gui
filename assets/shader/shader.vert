#version 450

layout(location = 0) in vec2 in_position;

layout(binding = 0) buffer Instance {
  vec2 positions[];
};

void main() {
  int index = gl_InstanceIndex;
  gl_Position = vec4(in_position + positions[index], 0.0, 1.0);
}


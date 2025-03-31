#version 450

layout(location = 0) in vec2 in_position;
layout(location = 1) in vec3 in_color;

layout(location = 0) out vec3 fragColor;

layout(binding = 0) uniform u_Buffer {
  vec3 vector3;
};

void main() {
	gl_Position = vec4(in_position, 0.0, 1.0);
	fragColor = in_color;
}


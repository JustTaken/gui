#version 450

layout(location = 0) in vec2 in_position;

layout(binding = 0) uniform u_Buffer {
  vec3 vector3;
};

void main() {
	gl_Position = vec4(in_position, 0.0, 1.0);
}


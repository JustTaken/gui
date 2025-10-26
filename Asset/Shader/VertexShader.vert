#version 450

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_color;

layout(location = 0) out vec3 out_color;

layout(set = 0, binding = 0) uniform UniformTest {
    mat4 vector;
};

void main() {
    gl_Position = vec4(in_position, 1.0);
    out_color = in_color;
}

#version 450

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_color;

layout(location = 0) out vec3 out_color;

layout(set = 0, binding = 0) buffer WorldTransform {
    mat4 world_transforms[];
};

layout(set = 1, binding = 0) uniform ViewTransform {
    mat4 projection;
    mat4 view;
};

void main() {
    mat4 transform = world_transforms[gl_InstanceIndex];
    gl_Position = vec4(in_position, 1.0) * view * transform * projection;
    out_color = in_color;
}

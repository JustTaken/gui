#version 450

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec2 in_texture;
layout(location = 3) in vec4 in_weights;
layout(location = 4) in uvec4 in_joints;

layout(location = 0) out vec4 out_color;

layout(set = 0, binding = 0) uniform Projection {
  mat4 projection;
  mat4 view;
};

layout(set = 0, binding = 1) readonly buffer Light {
  vec3 light;
};

layout(set = 1, binding = 0) readonly buffer InstanceModel {
  mat4 models[];
};

layout(set = 1, binding = 1) readonly buffer InstanceColor {
  vec4 colors[];
};

layout(set = 1, binding = 2) readonly buffer BoneTransform {
  mat4 transforms[];
};

void main() {
  mat4 transform = (transforms[in_joints[0]] * in_weights[0] + transforms[in_joints[1]] * in_weights[1] + transforms[in_joints[2]] * in_weights[2] + transforms[in_joints[3]] * in_weights[3]);

  gl_Position = projection * view * models[gl_InstanceIndex] * vec4(in_position, 1.0);
  gl_Position = transform * gl_Position;

  vec3 ligth_direction = normalize(light - gl_Position.xyz);
  out_color = vec4(length(dot(in_normal, ligth_direction)) * colors[index].rgb, colors[index].a);
}


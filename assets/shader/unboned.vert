#version 450

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec2 in_texture;

layout(location = 0) out vec4 out_color;
layout(location = 0) out vec2 out_texture;

layout(set = 0, binding = 0) uniform Projection {
  mat4 projection;
  mat4 view;
};

layout(set = 0, binding = 1) readonly buffer Light {
  vec3 light;
};

layout(set = 1, binding = 0) readonly buffer Materials {
  vec4 materials[];
};

layout(set = 1, binding = 1) readonly buffer InstanceModel {
  mat4 models[];
};

layout(set = 1, binding = 2) readonly buffer InstanceBones {
  mat4 transforms[];
};

layout(set = 1, binding = 3) readonly buffer InstanceOffset {
  int transform_offsets[];
};

layout(set = 1, binding = 4) readonly buffer InstanceMaterialOffset {
  int material_offsets[];
};

void main() {
  int offset = transform_offsets[gl_InstanceIndex];
  mat4 transform = transforms[offset];

  // gl_Position = projection * view * vec4(in_position, 1.0);
  // out_color = vec4(1, 1, 1, 1);
  gl_Position = projection * view * transform * models[gl_InstanceIndex] * vec4(in_position, 1.0);

  vec4 color = materials[material_offsets[gl_InstanceIndex]];
  vec3 ligth_direction = normalize(light - gl_Position.xyz);
  out_color = vec4(length(dot(in_normal, ligth_direction)) * color.rgb, color.a);
  out_texture = in_texture;
}


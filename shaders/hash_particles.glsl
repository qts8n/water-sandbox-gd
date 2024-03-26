#[compute]
#version 450

#include "common.glsl"

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) uniform uint num_particles;
layout(set = 0, binding = 1, std430) uniform FluidProps fluid_props;
layout(set = 0, binding = 2, std430) restrict buffer uint particle_indicies[];
layout(set = 0, binding = 3, std430) restrict buffer uint particle_cell_indicies[];
layout(set = 0, binding = 4, std430) restrict buffer uint cell_offsets[];
layout(set = 0, binding = 5, std430) restrict buffer vec3 predicted_positions[];

void main() {
    uint index = gl_GlobalInvocationID.x;
    if (index >= num_particles) {
        return;
    }

    cell_offsets[index] = INF;
    uint particle_index = particle_indicies[index];
    ivec3 cell = get_cell(predicted_positions[particle_index], fluid_props.smoothing_radius);
    particle_cell_indicies[particle_index] = hash_cell(cell, num_particles);
}

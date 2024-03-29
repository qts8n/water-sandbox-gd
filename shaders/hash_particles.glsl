#[compute]
#version 450

#include "common.glsl"

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

#include "buffers.glsl"

layout(set = 0, binding = 1, std430) restrict buffer ParticleIndicies { uint data[]; } particle_indicies;
layout(set = 0, binding = 2, std430) restrict buffer ParticleCellIndicies { uint data[]; } particle_cell_indicies;
layout(set = 0, binding = 3, std430) restrict buffer CellOffsets { uint data[]; } cell_offsets;
layout(set = 0, binding = 4, std430) restrict buffer PredictedPositions { vec4 data[]; } predicted_positions;

void main() {
    uint index = gl_GlobalInvocationID.x;
    uint num_particles = uint(fluid_props.num_particles);
    if (index >= num_particles) {
        return;
    }

    cell_offsets.data[index] = INF;
    uint particle_index = particle_indicies.data[index];
    ivec3 cell = get_cell(predicted_positions.data[particle_index].xyz, fluid_props.smoothing_radius);
    particle_cell_indicies.data[particle_index] = hash_cell(cell, num_particles);
}

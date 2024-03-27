#[compute]
#version 450

#include "common.glsl"

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

#include "buffers.glsl"

layout(set = 0, binding = 1, std430) restrict buffer ParticleIndicies { uint data[]; } particle_indicies;
layout(set = 0, binding = 2, std430) restrict buffer ParticleCellIndicies { uint data[]; } particle_cell_indicies;
layout(set = 0, binding = 3, std430) restrict buffer CellOffsets { uint data[]; } cell_offsets;


void main() {
    uint num_particles = uint(fluid_props.num_particles);
    uint index = gl_GlobalInvocationID.x;
    if (index >= num_particles) {
        return;
    }

    uint particle_index = particle_indicies.data[index];
    uint cell_index = particle_cell_indicies.data[particle_index];
    atomicMin(cell_offsets.data[cell_index], index);
}

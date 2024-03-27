#[compute]
#version 450

#include "common.glsl"

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

#include "buffers.glsl"

layout(set = 0, binding = 1, std430) restrict buffer ParticleIndicies { uint data[]; } particle_indicies;
layout(set = 0, binding = 2, std430) restrict buffer ParticleCellIndicies { uint data[]; } particle_cell_indicies;
layout(set = 0, binding = 3, std430) restrict buffer BitSorter {
    uint block_size;
    uint dim;
}
bit_sorter;


void main() {
    uint num_particles = uint(fluid_props.num_particles);
    uint i = gl_GlobalInvocationID.x;
    uint j = i ^ bit_sorter.block_size;
    if (i > j || i >= num_particles || j >= num_particles) {
        return;
    }

    uint key_i = particle_indicies.data[i];
    uint key_j = particle_indicies.data[j];
    uint value_i = particle_cell_indicies.data[key_i];
    uint value_j = particle_cell_indicies.data[key_j];

    int diff = int(value_i - value_j) * ((i & bit_sorter.dim) != 0 ? -1 : 1);
    if (diff > 0) {
        particle_indicies.data[i] = key_j;
        particle_indicies.data[j] = key_i;
    }
}


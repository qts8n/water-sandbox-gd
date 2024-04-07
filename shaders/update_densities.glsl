#[compute]
#version 450

#include "common.glsl"

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

#include "buffers.glsl"

layout(set = 0, binding = 1, std430) restrict buffer ParticleIndicies { uint data[]; } particle_indicies;
layout(set = 0, binding = 2, std430) restrict buffer ParticleCellIndicies { uint data[]; } particle_cell_indicies;
layout(set = 0, binding = 3, std430) restrict buffer CellOffsets { uint data[]; } cell_offsets;

layout(set = 0, binding = 4, std430) restrict buffer SmoothigKernel {
    float pow2;
    float pow2_der;
    float pow3;
    float pow3_der;
    float spikey_pow3;
} kernel;

layout(set = 0, binding = 5, std430) restrict buffer PredictedPositions { vec4 data[]; } predicted_positions;
layout(set = 0, binding = 6, std430) restrict buffer Densities { vec2 data[]; } densities;
layout(set = 0, binding = 7, std430) restrict buffer Pressures { vec2 data[]; } pressures;

float smoothing_kernel(float dst) {
    float v = fluid_props.smoothing_radius - dst;
    return v * v * kernel.pow2;
}

float smoothing_kernel_near(float dst) {
    float v = fluid_props.smoothing_radius - dst;
    return v * v * v * kernel.pow3;
}

void main() {
    uint index = gl_GlobalInvocationID.x;
    uint num_particles = uint(fluid_props.num_particles);
    if (index >= num_particles) {
        return;
    }

    uint particle_index = particle_indicies.data[index];
    vec4 origin = predicted_positions.data[particle_index];
    ivec3 cell_index = get_cell(origin.xyz, fluid_props.smoothing_radius);

    // Accumulate density
    float density = 0.;
    float near_density = 0.;

    ivec3 offset_table[27];
    fill_offset_table(offset_table);

    for (uint i = 0; i < 27; i++) {
        ivec3 neighbour_cell_index = cell_index + offset_table[i];
        uint hash_index = hash_cell(neighbour_cell_index, num_particles);
        uint neighbour_it = cell_offsets.data[hash_index];
        while (neighbour_it < num_particles) {
            uint neighbour_index = particle_indicies.data[neighbour_it];
            if (particle_cell_indicies.data[neighbour_index] != hash_index) {
                break;
            }

            neighbour_it++;

            vec4 neighbour_position = predicted_positions.data[neighbour_index];
            float dst = distance(neighbour_position, origin);
            if (dst > fluid_props.smoothing_radius) {
                continue;
            }

            density += smoothing_kernel(dst);
            near_density += smoothing_kernel_near(dst);
        }
    }

    density = density + DENSITY_PADDING;
    near_density = near_density + DENSITY_PADDING;

    densities.data[particle_index] = vec2(density, near_density);

    float pressure = fluid_props.pressure_scalar * (density - fluid_props.target_density);
    float near_pressure = fluid_props.near_pressure_scalar * near_density;

    pressures.data[particle_index] = vec2(pressure, near_pressure);
}


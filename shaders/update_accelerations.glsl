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
layout(set = 0, binding = 8, std430) restrict buffer Velocities { vec4 data[]; } velocities;
layout(set = 0, binding = 9, std430) restrict buffer Accelerations { vec4 data[]; } accelerations;


float smoothing_kernel_derivative(float dst) {
    return (dst - fluid_props.smoothing_radius) * kernel.pow2_der;
}

float smoothing_kernel_derivative_near(float dst) {
    float v = dst - fluid_props.smoothing_radius;
    return v * v * kernel.pow3_der;
}

float smoothing_kernel_viscosity(float dst) {
    float v = fluid_props.smoothing_radius * fluid_props.smoothing_radius - dst * dst;
    return v * v * v * kernel.spikey_pow3;
}

void main() {
    uint index = gl_GlobalInvocationID.x;
    uint num_particles = uint(fluid_props.num_particles);
    if (index >= num_particles) {
        return;
    }

    uint particle_index = particle_indicies.data[index];
    vec4 origin = predicted_positions.data[particle_index];
    vec4 velocity = velocities.data[particle_index];
    float pressure = pressures.data[particle_index].x;
    float near_pressure = pressures.data[particle_index].y;
    ivec3 cell_index = get_cell(origin.xyz, fluid_props.smoothing_radius);

    vec3 pressure_force = vec3(0.);
    vec3 viscosity_force = vec3(0.);

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

            if (particle_index == neighbour_index) {
                continue;
            }

            vec4 neighbour_position = predicted_positions.data[neighbour_index];
            float dst = distance(neighbour_position, origin);
            if (dst > fluid_props.smoothing_radius) {
                continue;
            }

            vec3 dir = dst > 0. ? (neighbour_position - origin).xyz / dst : vec3(0., 1., 0.);

            float slope = smoothing_kernel_derivative(dst);
            float shared_pressure = (pressure + pressures.data[neighbour_index].x) / 2.;

            float slope_near = smoothing_kernel_derivative_near(dst);
            float shared_pressure_near = (near_pressure + pressures.data[neighbour_index].y) / 2.;

            pressure_force += dir * shared_pressure * slope / densities.data[neighbour_index].x;
            pressure_force += dir * shared_pressure_near * slope_near / densities.data[neighbour_index].y;

            float viscosity = smoothing_kernel_viscosity(dst);
            viscosity_force += (velocities.data[neighbour_index] - velocity).xyz * viscosity;
        }
    }

    vec3 pressure_contribution = pressure_force / densities.data[particle_index].x;
    vec3 viscosity_contribution = viscosity_force * fluid_props.viscosity_strength;
    accelerations.data[particle_index] = vec4(pressure_contribution + viscosity_contribution, 0.);
}

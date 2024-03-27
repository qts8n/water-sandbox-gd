#[compute]
#version 450

#include "common.glsl"

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

#include "buffers.glsl"

layout(set = 0, binding = 1, packed) restrict buffer Positions { vec3 data[]; } positions;
layout(set = 0, binding = 2, packed) restrict buffer Velocities { vec3 data[]; } velocities;
layout(set = 0, binding = 3, packed) restrict buffer Accelerations { vec3 data[]; } accelerations;
layout(set = 0, binding = 4, packed) restrict buffer PredictedPositions { vec3 data[]; } predicted_positions;
layout(set = 0, binding = 5, packed) restrict buffer FluidContainer {
    vec3 ext_min;
    vec3 ext_max;
} fluid_container;


void main () {
    uint num_particles = uint(fluid_props.num_particles);
    uint index = gl_GlobalInvocationID.x;
    if (index >= num_particles) {
        return;
    }

    vec3 gravity = vec3(0., -fluid_props.gravity, 0.);

    // Integrate
    velocities.data[index] += (gravity + accelerations.data[index]) / fluid_props.mass * fluid_props.delta_time;
    positions.data[index] += velocities.data[index] * fluid_props.delta_time;

    // Handle collisions

    if (positions.data[index].x < fluid_container.ext_min.x) {
        velocities.data[index].x *= -1. * fluid_props.collision_damping;
        positions.data[index].x = fluid_container.ext_min.x;
    } else if (positions.data[index].x > fluid_container.ext_max.x) {
        velocities.data[index].x *= -1. * fluid_props.collision_damping;
        positions.data[index].x = fluid_container.ext_max.x;
    }

    if (positions.data[index].y < fluid_container.ext_min.y) {
        velocities.data[index].y *= -1. * fluid_props.collision_damping;
        positions.data[index].y = fluid_container.ext_min.y;
    } else if (positions.data[index].y > fluid_container.ext_max.y) {
        velocities.data[index].y *= -1. * fluid_props.collision_damping;
        positions.data[index].y = fluid_container.ext_max.y;
    }

    if (positions.data[index].z < fluid_container.ext_min.z) {
        velocities.data[index].z *= -1. * fluid_props.collision_damping;
        positions.data[index].z = fluid_container.ext_min.z;
    } else if (positions.data[index].z > fluid_container.ext_max.z) {
        velocities.data[index].z *= -1. * fluid_props.collision_damping;
        positions.data[index].z = fluid_container.ext_max.z;
    }

    // Calculate predicted postions
    predicted_positions.data[index] = positions.data[index] + velocities.data[index] * LOOKAHEAD_FACTOR;
}

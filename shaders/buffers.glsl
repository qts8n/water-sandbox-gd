layout(set = 0, binding = 0, std430) restrict buffer FluidProps {
    float num_particles;
    float delta_time;
    float collision_damping;
    float gravity;
    float mass;
    float radius;
    float smoothing_radius;
    float target_density;
    float pressure_scalar;
    float near_pressure_scalar;
    float viscosity_strength;
}
fluid_props;

const uint WORKGROUP_SIZE = 1024;

const float LOOKAHEAD_FACTOR = 1. / 50.;
const float DENSITY_PADDING = 0.00001;

const float PI = 3.141592653589793238;  // Math constants
const uint INF = 999999999;

const uint P1 = 15823;  // Some large primes for hashing
const uint P2 = 9737333;
const uint P3 = 440817757;


// Smothing radius kernel functions

float smoothing_kernel(float dst, float radius) {
    float volume = 15. / (2. * PI * pow(radius, 5.));
    float v = radius - dst;
    return v * v * volume;
}

float smoothing_kernel_near(float dst, float radius) {
    float volume = 15. / (PI * pow(radius, 6.));
    float v = radius - dst;
    return v * v * v * volume;
}

// Slope calculation

float smoothing_kernel_derivative(float dst, float radius) {
    float scale = 15. / (PI * pow(radius, 5.));
    return (dst - radius) * scale;
}

float smoothing_kernel_derivative_near(float dst, float radius) {
    float scale = 45. / (PI * pow(radius, 6.));
    float v = dst - radius;
    return v * v * scale;
}

float smoothing_kernel_viscosity(float dst, float radius) {
    float volume = 315. / (64. * PI * pow(radius, 9.));
    float v = radius * radius - dst * dst;
    return v * v * v * volume;
}

// Hashing cell indicies

ivec3 get_cell(vec3 position, float radius) {
    return ivec3(floor(position / radius));
}

uint hash_cell(ivec3 cell_index, uint num_particles) {
    uvec3 cell = uvec3(cell_index);
    return (cell.x * P1 + cell.y * P2 + cell.z * P3) % num_particles;
}

// Structs

struct FluidProps {
    float delta_time;
    float collision_damping;
    float mass;
    float radius;
    float smoothing_radius;
    float target_density;
    float pressure_scalar;
    float near_pressure_scalar;
    float viscosity_strength;
};

struct BitSorter {
    uint block_size;
    uint dim;
};

extends Node3D

const HASH_PARTICLES_SHADER_PATH = "res://shaders/hash_particles.glsl"
const BITONIC_SORT_SHADER_PATH = "res://shaders/bitonic_sort.glsl"
const CELL_OFFSETS_SHADER_PATH = "res://shaders/cell_offsets.glsl"
const UPDATE_DENSITIES_SHADER_PATH = "res://shaders/update_densities.glsl"
const UPDATE_ACCELERATIONS_SHADER_PATH = "res://shaders/update_accelerations.glsl"
const INTEGRATE_SHADER_PATH = "res://shaders/integrate.glsl"

@export_range(16, 128) var N_SIZE: int = 16
@export var WORKGROUP_SIZE: int = 1024

# Fluid properties settings
@export_category("Fluid Properties")
@export_range(1. / 240., 1. / 60.) var DELTA_TIME: float = 1. / 120.
@export_range(0, 1) var COLLISION_DUMPING: float = 0.95
@export_range(0, 100) var GRAVITY_FORCE: float = 9.8
@export_range(0, 2) var MASS: float = 1.
@export_range(0.05, 1) var SMOOTHING_RADIUS: float = 0.35
@export var TARGET_DENSITY: float = 10.
@export var PRESSURE_SCALAR: float = 55.
@export var NAER_PRESSURE_SCALAR: float = 2.
@export var VISCOSITY_STRENGTH: float = 0.5

# Particles
var _particle_scene = preload("res://particle.tscn")
var _particles: Array[Node3D]
var _particle_radius: float
var _num_particles: int
var _workgroup: Vector3i

# Compute buffers
var _fluid_props_buffer: StorageBufferUniform
var _bitsorter_buffer: StorageBufferUniform
var _particle_indicies_buffer: StorageBufferUniform
var _particle_cell_indicies_buffer: StorageBufferUniform
var _cell_offsets_buffer: StorageBufferUniform
var _smoothing_kernel_buffer: StorageBufferUniform
var _positions_buffer: StorageBufferUniform
var _velocities_buffer: StorageBufferUniform
var _accelerations_buffer: StorageBufferUniform
var _predicted_positions_buffer: StorageBufferUniform
var _densities_buffer: StorageBufferUniform
var _pressures_buffer: StorageBufferUniform
var _fluid_container_buffer: StorageBufferUniform

# Compute passes
var _hash_particles_pass: ComputePass
var _bitonic_sort_pass: ComputePass
var _cell_offsets_pass: ComputePass
var _update_densities_pass: ComputePass
var _update_accelerations_pass: ComputePass
var _integrate_pass: ComputePass


func _generate_cube_fluid(ni: int, nj: int, nk: int, radius: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var half_extents = Vector3(ni, nj, nk) * radius
	var offset = Vector3.ONE * radius - half_extents
	var diam = radius * 2
	for i in range(ni):
		var x = i * diam
		for j in range(nj):
			var y = j * diam
			for k in range(nk):
				var z = k * diam
				points.push_back(Vector3(x, y, z) + offset)
	return points


func _get_fluid_props() -> PackedByteArray:
	return PackedFloat32Array([
		float(_num_particles),
		DELTA_TIME,
		COLLISION_DUMPING,
		GRAVITY_FORCE,
		MASS,
		_particle_radius,
		SMOOTHING_RADIUS,
		TARGET_DENSITY,
		PRESSURE_SCALAR,
		NAER_PRESSURE_SCALAR,
		VISCOSITY_STRENGTH,
	]).to_byte_array()


func _get_smoothing_kernel() -> PackedByteArray:
	return PackedFloat32Array([
		15. / (2. * PI * pow(SMOOTHING_RADIUS, 5.)),
		15. / (PI * pow(SMOOTHING_RADIUS, 5.)),
		15. / (PI * pow(SMOOTHING_RADIUS, 6.)),
		45. / (PI * pow(SMOOTHING_RADIUS, 6.)),
		315. / (64. * PI * pow(SMOOTHING_RADIUS, 9.)),
	]).to_byte_array()


func _get_bitonic_sorter(block_size: int, dim: int) -> PackedByteArray:
	var bit_sorter = PackedByteArray()
	bit_sorter.resize(8)  # stores 2 u32 = 2 * 4 bytes = 8 bytes
	bit_sorter.encode_u32(0, block_size)  # first u32 - block size
	bit_sorter.encode_u32(4, dim)  # second u32
	return bit_sorter


func _get_workgroup() -> Vector3i:
	var batch_size = _num_particles / WORKGROUP_SIZE
	if _num_particles % WORKGROUP_SIZE > 0:
		batch_size += 1
	return Vector3i(batch_size, 1, 1)


# Called when the node enters the scene tree for the first time.
func _ready():
	# Init particle positions
	_particle_radius = _particle_scene.instantiate().get_radius()
	var positions = _generate_cube_fluid(N_SIZE, N_SIZE, N_SIZE, _particle_radius)
	var positions_vec4: Array[float] = []
	for point in positions:
		# Init next particle object
		var particle_instance = _particle_scene.instantiate()
		particle_instance.position = point
		add_child(particle_instance)
		# Store
		_particles.push_back(particle_instance)
		positions_vec4.append_array([point.x, point.y, point.z, 0.])

	# Prepare data for compute buffers
	_num_particles = len(positions)
	var fluid_container_buffer = $box.get_ext_buffer(_particle_radius)
	var positions_buffer = PackedFloat32Array(positions_vec4).to_byte_array()
	var predicted_positions_buffer = positions_buffer.duplicate()

	# Init compute buffers
	_fluid_props_buffer = StorageBufferUniform.create(_get_fluid_props())
	_bitsorter_buffer = StorageBufferUniform.create_uint_zeros(2)
	_particle_indicies_buffer = StorageBufferUniform.create_uint_zeros(_num_particles)
	_particle_cell_indicies_buffer = StorageBufferUniform.create_uint_zeros(_num_particles)
	_cell_offsets_buffer = StorageBufferUniform.create_uint_zeros(_num_particles)
	_smoothing_kernel_buffer = StorageBufferUniform.create(_get_smoothing_kernel())
	_positions_buffer = StorageBufferUniform.create(positions_buffer)
	_velocities_buffer = StorageBufferUniform.create_vec4_zeros(_num_particles)
	_accelerations_buffer = StorageBufferUniform.create_vec4_zeros(_num_particles)
	_predicted_positions_buffer = StorageBufferUniform.create(predicted_positions_buffer)
	_densities_buffer = StorageBufferUniform.create_vec2_zeros(_num_particles)
	_pressures_buffer = StorageBufferUniform.create_vec2_zeros(_num_particles)
	_fluid_container_buffer = StorageBufferUniform.create(fluid_container_buffer)

	# Init compute passes

	# Hash particle indecies
	_hash_particles_pass = ComputePass.from_shader_path(HASH_PARTICLES_SHADER_PATH)
	_hash_particles_pass.add_uniform_array([
		_fluid_props_buffer,
		_particle_indicies_buffer,
		_particle_cell_indicies_buffer,
		_cell_offsets_buffer,
		_predicted_positions_buffer,
	])

	# Bitonic sort the array of particle indecies
	_bitonic_sort_pass = ComputePass.from_shader_path(BITONIC_SORT_SHADER_PATH)
	_bitonic_sort_pass.add_uniform_array([
		_fluid_props_buffer,
		_particle_indicies_buffer,
		_particle_cell_indicies_buffer,
		_bitsorter_buffer,
	])

	# Calculate cell offsets
	_cell_offsets_pass = ComputePass.from_shader_path(CELL_OFFSETS_SHADER_PATH)
	_cell_offsets_pass.add_uniform_array([
		_fluid_props_buffer,
		_particle_indicies_buffer,
		_particle_cell_indicies_buffer,
		_cell_offsets_buffer,
	])

	# Update densities and pressures
	_update_densities_pass = ComputePass.from_shader_path(UPDATE_DENSITIES_SHADER_PATH)
	_update_densities_pass.add_uniform_array([
		_fluid_props_buffer,
		_particle_indicies_buffer,
		_particle_cell_indicies_buffer,
		_cell_offsets_buffer,
		_smoothing_kernel_buffer,
		_predicted_positions_buffer,
		_densities_buffer,
		_pressures_buffer,
	])

	# Calculare pressure & viscosity forces and update accelerations accordingly
	_update_accelerations_pass = ComputePass.from_shader_path(UPDATE_ACCELERATIONS_SHADER_PATH)
	_update_accelerations_pass.add_uniform_array([
		_fluid_props_buffer,
		_particle_indicies_buffer,
		_particle_cell_indicies_buffer,
		_cell_offsets_buffer,
		_smoothing_kernel_buffer,
		_predicted_positions_buffer,
		_densities_buffer,
		_pressures_buffer,
		_velocities_buffer,
		_accelerations_buffer,
	])

	# Integrate particle positions & prepare predicted positions for the next pass
	_integrate_pass = ComputePass.from_shader_path(INTEGRATE_SHADER_PATH)
	_integrate_pass.add_uniform_array([
		_fluid_props_buffer,
		_positions_buffer,
		_velocities_buffer,
		_accelerations_buffer,
		_predicted_positions_buffer,
		_fluid_container_buffer
	])

	_workgroup = _get_workgroup()


func _sort_particles():
	_hash_particles_pass.run(_workgroup)
	ComputePass.sync()

	var dim = 2
	while dim <= _num_particles:
		var block = dim >> 1
		while block > 0:
			_bitsorter_buffer.update_data(_get_bitonic_sorter(block, dim))
			_bitonic_sort_pass.run(_workgroup)
			ComputePass.sync()
			block >>= 1
		dim <<= 1

	_cell_offsets_pass.run(_workgroup)
	ComputePass.sync()


func _simulation_step():
	_update_densities_pass.run(_workgroup)
	ComputePass.sync()

	_update_accelerations_pass.run(_workgroup)
	ComputePass.sync()

	_integrate_pass.run(_workgroup)
	ComputePass.sync()


func _physics_process(_delta):
	_fluid_props_buffer.update_data(_get_fluid_props())
	_smoothing_kernel_buffer.update_data(_get_smoothing_kernel())

	_sort_particles()
	_simulation_step()

	var coordinate_components = _positions_buffer.get_data().to_float32_array()
	for c in range(0, len(coordinate_components), 4):
		var particle_index = c / 4
		_particles[particle_index].position = Vector3(
			coordinate_components[c],
			coordinate_components[c + 1],
			coordinate_components[c + 2],
		)

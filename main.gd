extends Node3D

const INTEGRATE_SHADER_PATH = "res://shaders/integrate.glsl"

@export var N_SIZE: int = 16
@export var WORKGROUP_SIZE: int = 1024

# Fluid properties settings
@export_category("Fluid Properties")
@export_range(1. / 240., 1. / 60.) var DELTA_TIME: float = 1. / 120.
@export_range(0, 1) var COLLISION_DUMPING: float = 0.95
@export_range(0, 100) var GRAVITY_FORCE: float = 9.8
@export_range(0, 2) var MASS: float = 1.
@export var SMOOTHING_RADIUS: float = 0.35
@export var TARGET_DENSITY: float = 10.
@export var PRESSURE_SCALAR: float = 55.
@export var NAER_PRESSURE_SCALAR: float = 2.
@export var VISCOSITY_STRENGTH: float = 0.5 

# Particles
var _particle_scene = preload("res://particle.tscn")
var _particles: Array[Node3D]
var _particle_radius: float
var _num_particles: int

# Compute buffers
var _fluid_props_buffer: StorageBufferUniform
var _positions_buffer: StorageBufferUniform
var _velocities_buffer: StorageBufferUniform
var _accelerations_buffer: StorageBufferUniform
var _predicted_positions_buffer: StorageBufferUniform
var _fluid_container_buffer: StorageBufferUniform

# Compute passes
var _integrate_pass: ComputePass

func _generate_cube_fluid(ni: int, nj: int, nk: int, radius: float):
	var points = []
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


func _get_fluid_props() -> PackedFloat32Array:
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
	])


func _get_workgroup() -> Vector3i:
	var batch_size = _num_particles / WORKGROUP_SIZE
	if _num_particles % WORKGROUP_SIZE > 0:
		batch_size += 1
	return Vector3i(batch_size, 1, 1)


# Called when the node enters the scene tree for the first time.
func _ready():
	# Init particle positions
	_particle_radius = _particle_scene.instantiate().get_radius()
	var ext = $box.get_ext(_particle_radius)
	var positions = _generate_cube_fluid(N_SIZE, N_SIZE, N_SIZE, _particle_radius)
	_num_particles = len(positions)
	for point in positions:
		var particle_instance = _particle_scene.instantiate()
		particle_instance.position = point
		_particles.push_back(particle_instance)
		add_child(particle_instance)
	# Init compute buffers
	_fluid_props_buffer = StorageBufferUniform.create(_get_fluid_props().to_byte_array())
	_positions_buffer = StorageBufferUniform.create(PackedVector3Array(positions).to_byte_array())
	_velocities_buffer = StorageBufferUniform.create_vec3_zeros(_num_particles)
	_accelerations_buffer = StorageBufferUniform.create_vec3_zeros(_num_particles)
	_predicted_positions_buffer = StorageBufferUniform.create(PackedVector3Array(positions).to_byte_array())
	_fluid_container_buffer = StorageBufferUniform.create(PackedVector3Array(ext).to_byte_array())

	# Init compute passes
	_integrate_pass = ComputePass.from_shader_path(INTEGRATE_SHADER_PATH)
	_integrate_pass.add_uniform_array([
		_fluid_props_buffer,
		_positions_buffer,
		_velocities_buffer,
		_accelerations_buffer,
		_predicted_positions_buffer,
		_fluid_container_buffer
	])


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta):
	_fluid_props_buffer.update_data(_get_fluid_props().to_byte_array())
	_integrate_pass.run(_get_workgroup())
	ComputePass.sync()

	var coordinate_components = _positions_buffer.get_data().to_float32_array()
	for c in range(0, len(coordinate_components), 3):
		var particle_index = c / 3
		_particles[particle_index].position = Vector3(
			coordinate_components[c],
			coordinate_components[c + 1],
			coordinate_components[c + 2],
		)

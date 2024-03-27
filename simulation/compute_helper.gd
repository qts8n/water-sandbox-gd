extends Node

class_name ComputePass

static var rd = RenderingServer.get_rendering_device()
static var view = RDTextureView.new()

var compute_shader: RID
var pipeline: RID
var bindings: Array[RDUniform]
var uniforms: Array[Uniform]

static func from_shader_path(shader_path: String) -> ComputePass:
	var shader_spirv: RDShaderSPIRV = ComputePass.get_shader(shader_path)
	return ComputePass.from_shader(shader_spirv)

static func from_shader(shader_spirv: RDShaderSPIRV) -> ComputePass:
	var shader_rid = rd.shader_create_from_spirv(shader_spirv)
	return ComputePass.from_shader_rid(shader_rid)

static func from_shader_rid(shader_rid: RID) -> ComputePass:
	var compute_pass = ComputePass.new()
	compute_pass.compute_shader = shader_rid
	compute_pass.pipeline = rd.compute_pipeline_create(compute_pass.compute_shader)
	return compute_pass

static func sync() -> void:
	rd.barrier(RenderingDevice.BARRIER_MASK_COMPUTE)

static func get_shader(shader_path: String) -> RDShaderSPIRV:
	var shader_file = load(shader_path)
	return shader_file.get_spirv()

func add_uniform(uniform: Uniform) -> void:
	uniforms.append(uniform)

func add_uniform_array(uniform_array: Array[Uniform]) -> void:
	uniforms.append_array(uniform_array)

func run(groups: Vector3i) -> void:
	bindings.clear()
	for uniform_index in uniforms.size():
		bindings.append(uniforms[uniform_index].get_rd_uniform(uniform_index))
	
	var uniform_set = rd.uniform_set_create(bindings, compute_shader, 0)
	var compute_list = rd.compute_list_begin()
	
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, groups.x, groups.y, groups.z)
	rd.compute_list_end()
	rd.free_rid(uniform_set)

func _exit_tree() -> void:
	rd.free_rid(compute_shader)
	rd.free_rid(pipeline)
	for uniform in uniforms:
		uniform.queue_free()

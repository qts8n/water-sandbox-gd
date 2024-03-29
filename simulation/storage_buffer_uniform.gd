extends Uniform

class_name StorageBufferUniform

var storage_buffer: RID
var storage_buffer_size = 0

static func create(data: PackedByteArray) -> StorageBufferUniform:
	var uniform = StorageBufferUniform.new()
	uniform.storage_buffer_size = data.size()
	uniform.storage_buffer = ComputePass.rd.storage_buffer_create(uniform.storage_buffer_size, data)
	return uniform

static func create_uint_zeros(data_length: int) -> StorageBufferUniform:
	var data = []
	for _it in range(data_length * 4):
		data.push_back(0)
	return StorageBufferUniform.create(PackedByteArray(data))

static func create_vec4_zeros(data_length: int) -> StorageBufferUniform:
	var data: Array[float] = []
	for _it in range(data_length * 4):
		data.push_back(0.)
	return StorageBufferUniform.create(PackedFloat32Array(data).to_byte_array())

static func swap_buffers(storage_buffer_1: StorageBufferUniform, storage_buffer_2: StorageBufferUniform) -> void:
	var storage_buffer_1_rid = storage_buffer_1.storage_buffer
	var storage_buffer_1_size = storage_buffer_1.storage_buffer_size

	storage_buffer_1.storage_buffer = storage_buffer_2.storage_buffer
	storage_buffer_1.storage_buffer_size = storage_buffer_2.storage_buffer_size
	storage_buffer_2.storage_buffer = storage_buffer_1_rid
	storage_buffer_2.storage_buffer_size = storage_buffer_1_size

func get_rd_uniform(binding: int) -> RDUniform:
	var uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(storage_buffer)
	return uniform

func update_data(data: PackedByteArray) -> void:
	if storage_buffer_size == data.size():
		ComputePass.rd.buffer_update(storage_buffer, 0, storage_buffer_size, data)
	else:
		ComputePass.rd.free_rid(storage_buffer)
		storage_buffer_size = data.size()
		storage_buffer = ComputePass.rd.storage_buffer_create(storage_buffer_size, data)

func get_data() -> PackedByteArray:
	return ComputePass.rd.buffer_get_data(storage_buffer)

func _exit_tree() -> void:
	ComputePass.rd.free_rid(storage_buffer)

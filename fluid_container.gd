extends MeshInstance3D

func get_ext(padding: float = 0.) -> Array[Vector3]:
	var half_size = mesh.size / 2
	var padding_vector = Vector3(padding, padding, padding)
	var ext_min = position - half_size + padding_vector
	var ext_max = position + half_size - padding_vector
	return [ext_min, ext_max]

func get_ext_buffer(padding: float = 0.) -> PackedByteArray:
	var ext = get_ext(padding)
	return PackedFloat32Array([
		ext[0].x,
		ext[0].y,
		ext[0].z,
		0.,
		ext[1].x,
		ext[1].y,
		ext[1].z,
		0.
	]).to_byte_array()

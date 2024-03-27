extends MeshInstance3D

func get_ext(radius: float) -> Array[Vector3]:
	var half_size = mesh.size / 2
	var radius_vector = Vector3(radius, radius, radius)
	var ext_min = position - half_size + radius_vector
	var ext_max = position + half_size - radius_vector
	return [ext_min, ext_max]

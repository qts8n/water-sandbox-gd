extends Node3D

@export var N_SIZE: int = 16

var particle = preload("res://particle.tscn")

var rd: RenderingDevice


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


# Called when the node enters the scene tree for the first time.
func _ready():
	var radius: float = particle.instantiate().get_radius()
	var positions = _generate_cube_fluid(N_SIZE, N_SIZE, N_SIZE, radius)
	for point in positions:
		var particle_instance = particle.instantiate()
		particle_instance.position = point
		add_child(particle_instance)
	rd = RenderingServer.create_local_rendering_device()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

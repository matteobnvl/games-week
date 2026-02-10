class_name MaterialFactory
## Static factory for creating reusable StandardMaterial3D instances.


static func create_wall_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if ResourceLoader.exists("res://textures/wall.jpg"):
		mat.albedo_texture = load("res://textures/wall.jpg")
		mat.uv1_triplanar = true
		mat.uv1_triplanar_sharpness = 1.0
		mat.uv1_scale = Vector3(0.3, 0.3, 0.3)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		mat.albedo_color = Color(0.45, 0.45, 0.5)
	return mat


static func create_floor_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if ResourceLoader.exists("res://textures/floor.jpg"):
		mat.albedo_texture = load("res://textures/floor.jpg")
		mat.uv1_triplanar = true
		mat.uv1_triplanar_sharpness = 1.0
		mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		mat.albedo_color = Color(0.3, 0.3, 0.3)
	return mat


static func create_ceiling_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if ResourceLoader.exists("res://textures/ceiling_cut.jpg"):
		mat.albedo_texture = load("res://textures/ceiling_cut.jpg")
		mat.uv1_triplanar = true
		mat.uv1_triplanar_sharpness = 1.0
		mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		mat.albedo_color = Color(0.4, 0.4, 0.42)
	return mat


static func create_glass_material(color := Color(0.7, 0.85, 1.0, 0.3)) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.roughness = 0.1
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func create_door_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.2, 0.1)
	return mat


static func create_emissive_material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	return mat

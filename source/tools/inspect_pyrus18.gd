extends SceneTree
const Arena = preload("res://scripts/arena.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var arena = Arena.new()
	root.add_child(arena)
	arena.set_theme("ds_pyrus")
	print("GROUP ", arena.native_surface.group_id)
	var records: Array = []
	for item: Dictionary in arena.native_surface._meshes:
		var joints: Dictionary = {}
		var skeleton: Skeleton3D = item.skeleton
		var skin: Skin = item.skin
		for bind: int in skin.get_bind_count():
			var bone: int = skin.get_bind_bone(bind)
			if bone < 0: bone = skeleton.find_bone(skin.get_bind_name(bind))
			joints[bind] = str(skeleton.get_bone_name(bone))
		var counts: Dictionary = {}
		for index: int in item.bones.size():
			if item.weights[index] > 0.5:
				var name: String = str(joints[item.bones[index]])
				counts[name] = int(counts.get(name,0))+1
		var material: Material = item.mesh.get_active_material(item.surface)
		var low: Vector3 = Vector3(INF,INF,INF)
		var high: Vector3 = -low
		var influences: int = item.bones.size()/item.vertices.size()
		for index: int in item.vertices.size():
			var point: Vector3 = Vector3.ZERO
			for influence: int in influences:
				var offset: int = index*influences+influence
				var bind: int = item.bones[offset]
				var bone: int = skin.get_bind_bone(bind)
				if bone < 0: bone = skeleton.find_bone(skin.get_bind_name(bind))
				point += (skeleton.global_transform*skeleton.get_bone_global_pose(bone)*skin.get_bind_pose(bind)*item.vertices[index])*item.weights[offset]
			low = low.min(point)
			high = high.max(point)
		records.append({"mesh":str(item.mesh.name),"surface":item.surface,"material":material.resource_name,"joints":counts,"triangle_count":item.indices.size()/3,"minimum":[low.x,low.y,low.z],"maximum":[high.x,high.y,high.z]})
	FileAccess.open("res://builds/qa-0.18/pyrus-source-surfaces.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	print(JSON.stringify(records))
	arena.free()
	quit()

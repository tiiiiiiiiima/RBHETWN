extends SceneTree
## Run headless with --script tools/inspect_ds_arena_geometry.gd -- [asset-directory] [report-json].
## Measures raw native GLBs without starting the global editor import pipeline.
var results: Dictionary = {}
func _initialize() -> void:
 call_deferred("_run")
func _run() -> void:
 var args: PackedStringArray = OS.get_cmdline_user_args()
 var base: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path('res://assets/ds/arenas')
 _walk(base)
 var f: FileAccess = FileAccess.open(args[1] if args.size() > 1 else '/tmp/bakugan-ds-arena-geometry.json', FileAccess.WRITE)
 f.store_string(JSON.stringify(results, '\t'))
 print('DS mesh bounds recorded: ', results.size())
 quit()
func _walk(path: String) -> void:
 var dir: DirAccess = DirAccess.open(path)
 if dir == null: return
 for n: String in dir.get_files():
  if n.ends_with('.glb'): _inspect(path.path_join(n))
 for n: String in dir.get_directories(): _walk(path.path_join(n))
func _inspect(path: String) -> void:
 var doc := GLTFDocument.new()
 var state := GLTFState.new()
 var err: Error = doc.append_from_file(path, state)
 if err != OK:
  results[path] = {'error': err}; return
 var scene: Node3D = doc.generate_scene(state)
 root.add_child(scene)
 var info: Dictionary = {'meshes': 0, 'triangles': 0, 'vertices': 0, 'textures': [], 'planes': {}, 'animations': [], 'flat_triangles': []}
 _meshes(scene, info)
 var box: AABB = info.get('aabb', AABB())
 info['bounds'] = {'min': _v(box.position), 'max': _v(box.end), 'size': _v(box.size)}
 info.erase('aabb')
 var planes: Array = []
 for plane: Dictionary in info['planes'].values(): planes.append(plane)
 planes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.area > b.area)
 info['planes'] = planes.slice(0, 6)
 results[ProjectSettings.localize_path(path).trim_prefix('res://')] = info
 scene.free()
func _v(v: Vector3) -> Array:
 return [v.x, v.y, v.z]
func _meshes(node: Node, info: Dictionary) -> void:
 if node is AnimationPlayer:
  info.animations = (node as AnimationPlayer).get_animation_list()
 if node is MeshInstance3D:
  var inst: MeshInstance3D = node as MeshInstance3D
  if inst.mesh:
   info.meshes += 1
   var bb: AABB = inst.global_transform * inst.mesh.get_aabb()
   info.aabb = bb if not info.has('aabb') else (info.aabb as AABB).merge(bb)
   for surface: int in inst.mesh.get_surface_count():
    var m: Material = inst.mesh.surface_get_material(surface)
    if m is StandardMaterial3D and (m as StandardMaterial3D).albedo_texture:
     var tex: Texture2D = (m as StandardMaterial3D).albedo_texture
     var size: Array = [tex.get_width(), tex.get_height()]
     if not info.textures.has(size): info.textures.append(size)
    var arrays: Array = inst.mesh.surface_get_arrays(surface)
    var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    info.vertices += verts.size()
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    if indices.is_empty():
     for j: int in verts.size(): indices.append(j)
    info.triangles += indices.size() / 3
    for j: int in range(0, indices.size() - 2, 3):
     var a: Vector3 = inst.global_transform * verts[indices[j]]
     var b: Vector3 = inst.global_transform * verts[indices[j + 1]]
     var c: Vector3 = inst.global_transform * verts[indices[j + 2]]
     var cross: Vector3 = (b - a).cross(c - a)
     var area: float = cross.length() * 0.5
     if area < 0.001 or absf(cross.normalized().y) < 0.98: continue
     var y: float = snappedf((a.y + b.y + c.y) / 3.0, 0.1)
     info.flat_triangles.append({'y': y, 'a': _v(a), 'b': _v(b), 'c': _v(c)})
     var key: String = str(y)
     var bbp: AABB = AABB(a, Vector3.ZERO).expand(b).expand(c)
     var pp: Dictionary = info.planes.get(key, {'y': y, 'area': 0.0, 'min': _v(bbp.position), 'max': _v(bbp.end)})
     pp.area += area
     var minp: Vector3 = Vector3(pp.min[0], pp.min[1], pp.min[2]).min(bbp.position)
     var maxp: Vector3 = Vector3(pp.max[0], pp.max[1], pp.max[2]).max(bbp.end)
     pp.min = _v(minp); pp.max = _v(maxp)
     info.planes[key] = pp
 for child: Node in node.get_children(): _meshes(child, info)

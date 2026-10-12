extends SceneTree
const Stages = preload('res://scripts/ds_arena_catalog.gd')
const Arena = preload('res://scripts/arena.gd')
var checks: int = 0
func _initialize() -> void:
 call_deferred('_run')
func _run() -> void:
 var groups: Dictionary = Stages.manifest().get('groups', {})
 assert(groups.size() == 18)
 checks += 1
 var stage_meshes: int = 0
 for gid: String in groups:
  print("DS GROUP ",gid)
  var stage: Node3D = Stages.make_source_preview(gid, false)
  assert(stage != null)
  root.add_child(stage)
  assert(stage.get_meta('native_geometry', false))
  assert(stage.get_child_count() == groups[gid].components.size())
  assert(is_equal_approx(stage.scale.x, float(groups[gid].pc_fit.uniform_scale)))
  var count: int = _meshes(stage)
  assert(count > 0)
  stage_meshes += count
  checks += 5
  await process_frame
  await RenderingServer.frame_post_draw
  stage.queue_free()
  await process_frame
 for theme: String in Stages.PLAYABLE_FIELDS:
  print("DS FIELD ",theme)
  var board = Arena.new()
  board.theme_id = theme
  root.add_child(board)
  board.set_theme(theme)
  assert(board.theme_id == theme)
  assert(board.environment_root.get_meta('source_available', false))
  assert(board.environment_root.get_meta('source_origin', '') == 'user_ds_nitrofs')
  assert(board.environment_root.get_meta('ds_group_id', '') == Stages.stage_id_for(theme) + '_throw')
  await process_frame
  await RenderingServer.frame_post_draw
  checks += 4
  var battle: Node3D = Stages.make_battle_stage(theme, false)
  assert(battle != null)
  root.add_child(battle)
  await process_frame
  await RenderingServer.frame_post_draw
  assert(battle.get_meta('ds_group_id', '') == Stages.stage_id_for(theme) + '_battle')
  checks += 2
  battle.queue_free()
  board.queue_free()
  await process_frame
 print(JSON.stringify({'stage_groups': groups.size(), 'source_meshes': stage_meshes, 'playable_DS_choices': Stages.PLAYABLE_FIELDS.size(), 'checks': checks, 'failures': 0}))
 quit()
func _meshes(node: Node) -> int:
 var count: int = 1 if node is MeshInstance3D and (node as MeshInstance3D).mesh != null else 0
 for child: Node in node.get_children(): count += _meshes(child)
 return count

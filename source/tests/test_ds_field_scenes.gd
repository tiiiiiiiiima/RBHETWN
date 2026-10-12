extends SceneTree
## Both real controllers must use the selected native floor for preview and roll.
const Catalog = preload("res://scripts/ds_arena_catalog.gd")
const Duel = preload("res://scripts/anime_duel.gd")
const Roster = preload("res://scripts/roster.gd")
const Layout = preload("res://scripts/board_layout.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _grounded(arena: Node3D, point: Vector3) -> bool:
	return point.is_finite() and absf(point.y - arena.surface_height(point) - 0.44) < 0.0001

func _run() -> void:
	var game: Node3D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.muted = true
	for theme: String in Catalog.PLAYABLE_FIELDS:
		game.selected_arena = theme
		game.arena.set_theme(theme)
		game.start_match()
		game._place_player_gate(5)
		game._skip_gate()
		game.charging = true
		game.charge = 0.67
		game.aim_point = Layout.POSITIONS[5]
		game._draw_trajectory()
		var preview: Mesh = game.trajectory.mesh
		game._draw_trajectory()
		_check(game.trajectory.mesh == preview, "Unchanged classic aim reuses the measured preview: " + theme)
		_check(game.arena.field_surface.group_id == Catalog.stage_id_for(theme) + "_throw", "Classic controller selects the actual native field: " + theme)
		game._launch_ball(0, 0, Layout.POSITIONS[5])
		game._update_flight(game._current_flight_duration())
		_check(game.phase == "rolling" and _grounded(game.arena, game.flight_ball.position), "Classic flight lands on its selected measured floor: " + theme)
		if theme == "ds_pyrus":
			_check(game.arena.camera.position.z < 0.0, "Classic Pyrus view avoids the source overhang")
			var forward: Vector3 = -game.arena.camera.global_transform.basis.z
			var control: Vector2 = game.arena.control_direction(Vector2(0.0, -1.0))
			_check(control.dot(Vector2(forward.x, forward.z)) > 0.0, "Classic Pyrus W steering follows the reversed view")
		game._update_roll(0.04)
		_check(not game.roll_motion.travel_segments.is_empty() and game.roll_motion.position.is_finite(), "Classic rolling uses swept source-floor steps: " + theme)
	game._show_menu()
	game.queue_free()
	await process_frame
	for theme: String in Catalog.PLAYABLE_FIELDS:
		var scene := Duel.new()
		scene.configure(Roster.make_anime_team([0, 1, 2], ["Pyrus", "Pyrus", "Ventus"]), theme, {"reduced_motion": true}, "straight")
		scene.auto_ai = false
		root.add_child(scene)
		await process_frame
		scene.set_process(false)
		scene.start_match(11006)
		scene._handle_result(scene.rules.place_gate(0, 0, 5))
		scene._handle_result(scene.rules.place_gate(1, 0, 6))
		scene.selected_unit = 1
		scene.aim_point = Layout.POSITIONS[5]
		scene._draw_preview()
		var preview: Mesh = scene._trajectory.mesh
		scene._draw_preview()
		_check(scene._trajectory.mesh == preview, "Unchanged anime aim reuses the measured preview: " + theme)
		_check(scene.arena.field_surface.group_id == Catalog.stage_id_for(theme) + "_throw", "Anime controller selects the actual native field: " + theme)
		scene._launch_throw(0, 1, Layout.POSITIONS[5], 0.67)
		scene._update_flight(3.0)
		_check(scene.visual_phase == "rolling" and _grounded(scene.arena, scene._flight_ball.position), "Anime flight lands on its selected measured floor: " + theme)
		if theme == "ds_pyrus":
			_check(scene.arena.camera.position.z < 0.0, "Anime Pyrus view avoids the source overhang")
			var forward: Vector3 = -scene.arena.camera.global_transform.basis.z
			var control: Vector2 = scene.arena.control_direction(Vector2(0.0, -1.0))
			_check(control.dot(Vector2(forward.x, forward.z)) > 0.0, "Anime Pyrus W steering follows the reversed view")
		scene._update_roll(0.04)
		_check(not scene._roll.travel_segments.is_empty() and scene._roll.position.is_finite(), "Anime rolling uses swept source-floor steps: " + theme)
		scene.queue_free()
		await process_frame
	print("DS FIELD SCENES: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

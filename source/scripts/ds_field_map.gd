extends Control
## Desktop navigation overlay; its floor outlines come from native DS triangles.
signal aim_requested(point: Vector3)
signal placement_requested(slot: int)
const Board = preload("res://scripts/board_layout.gd")
var game: Node3D
var _field_id: int = -1
var _polygons: Array[PackedVector2Array] = []
var _bounds: Vector2 = Vector2(20,20)
var _refresh: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	tooltip_text = "Мини-карта DS: выбери подсвеченную клетку для ворот или цель броска. Q/E — обзор; колесо — масштаб."

func _process(delta: float) -> void:
	if not is_instance_valid(game):
		visible = false
		return
	visible = game.rules_profile=="ds" and game.arena.uses_large_ds_field() and game.phase in ["opening","place","aim","flying","rolling","stay","double","ai","result"] and not game.overlay.visible
	if not visible:
		return
	_refresh += delta
	if _refresh<0.10:
		return
	_refresh = 0.0
	prepare_map()
	queue_redraw()

func prepare_map() -> void:
	_bounds = game.arena.traversal_bounds()
	var id: int = game.arena.environment_root.get_instance_id()
	if id==_field_id:
		return
	_field_id = id
	_polygons.clear()
	if game.arena.field_surface==null:
		return
	for triangle: PackedVector3Array in game.arena.field_surface.triangles:
		var normal: Vector3 = (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).normalized()
		if absf(normal.y)<0.80 or minf(triangle[0].y,minf(triangle[1].y,triangle[2].y)) < -0.4:
			continue
		var polygon := PackedVector2Array()
		for point: Vector3 in triangle:
			polygon.append(world_to_map(point))
		# Very small source triangles collapse after conversion to screen pixels.
		if absf((polygon[1]-polygon[0]).cross(polygon[2]-polygon[0]))>0.02:
			_polygons.append(polygon)

func map_scale() -> float:
	return minf((size.x-16.0)/(_bounds.x*2.0),(size.y-38.0)/(_bounds.y*2.0))

func map_center() -> Vector2:
	return Vector2(size.x*0.5,(size.y+20.0)*0.5)

func world_to_map(point: Vector3) -> Vector2:
	return map_center()+Vector2(point.x,point.z)*map_scale()

func map_to_world(point: Vector2) -> Vector3:
	var world: Vector2 = (point-map_center())/maxf(map_scale(),0.0001)
	return game.arena.clamp_aim(Vector3(world.x,0,world.y))

func _gui_input(event: InputEvent) -> void:
	if not is_instance_valid(game) or game.paused or game.phase not in ["aim","opening","place","double"]:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT:
			var point: Vector3 = map_to_world(event.position)
			if game.phase=="aim":
				aim_requested.emit(point)
			else:
				var slot: int = game._nearest_slot(point,1.6)
				if slot>=0: placement_requested.emit(slot)
			accept_event()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			game.arena.zoom_view(-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1)
			accept_event()

func _draw() -> void:
	if not is_instance_valid(game) or not visible:
		return
	draw_style_box(_background(),Rect2(Vector2.ZERO,size))
	var title: String = "PYRUS · ЛАВА −30 G" if game.arena.theme_id=="ds_pyrus" else "ПОЛЕ · НАЖМИ ДЛЯ ПРИЦЕЛА"
	draw_string(ThemeDB.fallback_font,Vector2(9,17),title,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("9cb2c8"))
	for polygon: PackedVector2Array in _polygons:
		draw_colored_polygon(polygon,Color("253c50"))
	var low: Vector2 = world_to_map(game.arena.slot_position(0))
	var high: Vector2 = world_to_map(game.arena.slot_position(47))
	var step: Vector2 = Vector2((high.x-low.x)/7.0,(high.y-low.y)/5.0)
	var start: Vector2 = low-step*0.5
	for column: int in range(9):
		var x: float = start.x+float(column)*step.x
		draw_line(Vector2(x,start.y),Vector2(x,start.y+step.y*6),Color("54758a"),0.7)
	for row: int in range(7):
		var y: float = start.y+float(row)*step.y
		draw_line(Vector2(start.x,y),Vector2(start.x+step.x*8,y),Color("54758a"),0.7)
	if game.phase in ["opening","place","double"]:
		var legal: Array = game.rules.legal_double_destinations(game.pending_double_slot) if game.phase=="double" else game.rules.legal_gate_slots(game.phase=="opening",0)
		for slot: int in legal:
			var p: Vector2 = world_to_map(game.arena.slot_position(slot))
			draw_rect(Rect2(p-step*0.42,step*0.84),Color(0.15,0.8,0.9,0.24))
	if is_instance_valid(game.arena.field_objects):
		for item: Dictionary in game.arena.field_objects.items:
			if item.collected:
				continue
			var colors: Dictionary = {"g_power":Color("f7d253"),"s_power":Color("d4dfec"),"s_power_small":Color("64b6ff"),"speed_pad":Color("6bbdea"),"trampoline":Color("61e995"),"experience":Color("3cf176"),"water_jet":Color("319cff"),"energy_orb":Color("ffff6f"),"wind_jet":Color("b5e9c2"),"breakable":Color("b8875e")}
			var point: Vector2 = world_to_map(item.node.global_position)
			if item.kind=="lava_pool":
				var polygon := PackedVector2Array()
				for corner: Vector3 in [Vector3(-1,0,-1),Vector3(1,0,-1),Vector3(1,0,1),Vector3(-1,0,1)]:
					polygon.append(world_to_map(item.node.global_transform*(corner*item.extent)))
				if not Geometry2D.triangulate_polygon(polygon).is_empty():
					draw_colored_polygon(polygon,Color("e65a26"))
				continue
			draw_circle(point,2.0,colors.get(item.kind,Color.WHITE))
	for slot: Variant in game.rules.gates:
		var center: Vector2 = world_to_map(game.arena.slot_position(int(slot)))
		var half: Vector2 = Board.card_size("ds")*0.5*map_scale()
		draw_rect(Rect2(center-half,half*2),Color("67d7f7") if int(game.rules.gates[slot].owner)==0 else Color("ed3024"),false,1.5)
	var sphere: Vector3 = game.ds_sphere.position if is_instance_valid(game.flight_ball) else game.arena.launch_position(0)
	draw_circle(world_to_map(sphere),4.0,Color("67d7f7") if not is_instance_valid(game.flight_ball) or game.flight_owner==0 else Color("ed3024"))
	if game.phase=="aim":
		var target: Vector2 = world_to_map(game.aim_point)
		draw_line(target-Vector2(4,0),target+Vector2(4,0),Color.WHITE,1.5)
		draw_line(target-Vector2(0,4),target+Vector2(0,4),Color.WHITE,1.5)

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101c2a")
	style.border_color = Color("39516b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

extends Control
## Native Scratch input and opposed meter; numeric scoring is a desktop fit.
const MAX_POINTS: int = 600
var running: bool = false
var score: float = 0.0
var advantage: float = 0.5
var symbol: Texture2D
var _held: bool = false
var _last: Vector2 = Vector2.ZERO
var _inside: bool = false
var _pending: float = 0.0
var _flash: float = 0.0
var _motion_budget: float = 0.0

func configure(attribute: String, _mode: String = "scratch") -> void:
	score = 0.0
	advantage = 0.5
	set_running(false)
	var ui: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ds/ui_manifest.json"))
	var path: String = str(ui.get("runtime",{}).get("attribute_"+attribute.to_lower(),{}).get("path",""))
	symbol = load(path) as Texture2D if ResourceLoader.exists(path) else null
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func center() -> Vector2:
	return Vector2(size.x*0.5,size.y*0.61)

func inside_symbol(point: Vector2) -> bool:
	return point.distance_to(center())<=minf(size.y*0.32,70.0)

func press(point: Vector2) -> void:
	_held = running and inside_symbol(point)
	_last = point
	_inside = _held

func motion(point: Vector2) -> void:
	if running and _held:
		var inside: bool = inside_symbol(point)
		if inside and _inside:
			_pending += minf(point.distance_to(_last),140.0)
		_last = point
		_inside = inside

func release() -> void:
	_held = false
	_inside = false
	_pending = 0.0
	_motion_budget = 0.0

func set_running(value: bool) -> void:
	running = value
	release()
	_pending = 0.0

func step(delta: float) -> int:
	if not running or delta<=0.0 or not is_finite(delta):
		return int(score)
	# Limit distance by elapsed game time: event frequency and teleporting
	# the cursor cannot create unlimited power. Holding still earns nothing.
	# Mouse events arrive at a different frequency than rendered frames.
	# Retain at most 100 ms of input capacity, so a legitimate stroke is not
	# discarded at high FPS while teleporting cannot earn unbounded credit.
	_motion_budget = minf(140.0,_motion_budget+delta*1400.0)
	var distance: float = minf(_pending,_motion_budget)
	_motion_budget -= distance
	score = minf(MAX_POINTS,score+distance*0.08)
	_flash = 0.12 if distance>0.0 else maxf(0.0,_flash-delta)
	_pending = 0.0
	queue_redraw()
	return int(score)

func set_meter(player: int, enemy: int) -> void:
	advantage = clampf(float(maxi(0,player))/float(maxi(1,maxi(0,player)+maxi(0,enemy))),0.0,1.0)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible or not running:
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		release()
	elif event is InputEventMouseMotion and _held:
		motion(get_global_transform_with_canvas().affine_inverse()*event.position)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed: press(event.position)
		else: release()
		accept_event()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		release()
		_pending = 0.0

func _draw() -> void:
	var bar := Rect2(Vector2(16,5),Vector2(size.x-32,18))
	draw_rect(bar,Color("ed3024"))
	var own := Rect2(Vector2(bar.end.x-bar.size.x*advantage,bar.position.y),Vector2(bar.size.x*advantage,bar.size.y))
	draw_rect(own,Color("28bfe9"))
	draw_rect(bar,Color("f5e4c1"),false,2.0)
	var radius: float = minf(size.y*0.32,70.0)
	draw_circle(center(),radius,Color("193e4d") if _flash<=0 else Color("347b83"))
	draw_arc(center(),radius+3,0,TAU,64,Color("83e1e7"),2.0)
	if symbol!=null:
		draw_texture_rect(symbol,Rect2(center()-Vector2.ONE*radius*0.79,Vector2.ONE*radius*1.58),false)
	else:
		draw_string(ThemeDB.fallback_font,center()+Vector2(-12,12),"G",HORIZONTAL_ALIGNMENT_LEFT,-1,34,Color.WHITE)
	if _flash>0.0:
		draw_circle(_last,5,Color("fff0a5"))

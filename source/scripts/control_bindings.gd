extends RefCounted
## Shared physical bindings; virtual pointers use the same mini-game input API.
const DEFAULTS = {"action":KEY_SPACE,"left":KEY_A,"right":KEY_D,"up":KEY_W,"down":KEY_S,"brake":KEY_SHIFT,"unit1":KEY_1,"unit2":KEY_2,"unit3":KEY_3,"style":KEY_T,"special":KEY_P,"camera_left":KEY_Q,"camera_right":KEY_E,"skip":KEY_BACKSPACE,"zoom_in":KEY_R,"zoom_out":KEY_F,"help":KEY_H}
const TITLES = {"action":"Бросок / прыжок / действие","left":"Влево","right":"Вправо","up":"Вперёд","down":"Назад","brake":"Тормоз","unit1":"Бакуган / карта 1","unit2":"Бакуган / карта 2","unit3":"Бакуган / карта 3","style":"Высокий / прямой бросок","special":"Особый бросок","camera_left":"Камера влево","camera_right":"Камера вправо","skip":"Пропуск карты цепи","zoom_in":"Приблизить камеру","zoom_out":"Отдалить камеру","help":"Помощь"}
var axes: Dictionary = {}
var buttons: Dictionary = {}
var device: int = -1
var virtual_cursor: Vector2 = Vector2.ZERO
var virtual_active: bool = false
var last_device: String = "mouse"

static func normalize(data: Variant) -> Dictionary:
	var result: Dictionary = DEFAULTS.duplicate()
	if not data is Dictionary: return result
	var used: Array = []
	for action: String in DEFAULTS:
		var key: Variant = data.get(action,DEFAULTS[action])
		if not key is int or key<=0 or key>0x7fffffff or key in [KEY_ESCAPE,KEY_ENTER] or used.has(key): return DEFAULTS.duplicate()
		result[action]=key
		used.append(key)
	return result

static func key_for(action: String, options: Dictionary) -> int:
	return int(options.get("bindings",DEFAULTS).get(action,DEFAULTS.get(action,KEY_NONE)))

static func key_name(action: String, options: Dictionary) -> String:
	return OS.get_keycode_string(key_for(action,options))

static func hints(text: String, options: Dictionary) -> String:
	var result: String=text
	var pattern:=RegEx.new()
	pattern.compile("(?<![A-Za-zА-Яа-я0-9])(?:ПРОБЕЛ|Пробел|пробел|WASD|1–3|Shift|SHIFT|Backspace|BACKSPACE|Q/E|T|P)(?![A-Za-zА-Яа-я0-9])")
	var matches: Array[RegExMatch]=pattern.search_all(text)
	matches.reverse()
	for match_value: RegExMatch in matches:
		var token: String=match_value.get_string()
		var replacement: String=""
		if token=="Q/E": replacement=key_name("camera_left",options)+"/"+key_name("camera_right",options)
		elif token=="WASD": replacement="/".join([key_name("up",options),key_name("left",options),key_name("down",options),key_name("right",options)])
		elif token=="1–3": replacement="/".join([key_name("unit1",options),key_name("unit2",options),key_name("unit3",options)])
		else: replacement=key_name(str({"ПРОБЕЛ":"action","Пробел":"action","пробел":"action","Shift":"brake","SHIFT":"brake","Backspace":"skip","BACKSPACE":"skip","T":"style","P":"special"}[token]),options)
		result=result.substr(0,match_value.get_start())+replacement+result.substr(match_value.get_end())
	return result

static func hint_control(control: Control, options: Dictionary) -> void:
	if control.text!=str(control.get_meta("rendered_hint","")):
		control.set_meta("source_hint",control.text)
	control.text=hints(str(control.get_meta("source_hint",control.text)),options)
	control.set_meta("rendered_hint",control.text)

static func held(action: String, options: Dictionary) -> bool:
	return Input.is_physical_key_pressed(key_for(action,options))

static func remap(event: InputEventKey, options: Dictionary) -> InputEventKey:
	var key: int = int(event.physical_keycode if event.physical_keycode!=0 else event.keycode)
	for action: String in DEFAULTS:
		if key==key_for(action,options):
			var mapped: InputEventKey = event.duplicate()
			mapped.keycode=DEFAULTS[action]
			return mapped
	# A formerly bound default key must not invoke the action after reassignment.
	if DEFAULTS.values().has(key):
		var ignored: InputEventKey=event.duplicate()
		ignored.keycode=KEY_NONE
		return ignored
	return event

func record(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		last_device="pad"
		device=event.device
		axes[event.axis]=event.axis_value
	elif event is InputEventJoypadButton:
		last_device="pad"
		device=event.device
		buttons[event.button_index]=event.pressed
	elif event is InputEventMouseMotion or event is InputEventMouseButton: last_device="mouse"
	elif event is InputEventKey: last_device="keyboard"

func reset() -> void:
	axes.clear(); buttons.clear(); device=-1
	virtual_active=false
	last_device="mouse"

func axis(index: int) -> float:
	return float(axes.get(index,0.0))

func pad_held(index: int) -> bool:
	return bool(buttons.get(index,false))

func movement(options: Dictionary, right_stick: bool = false) -> Vector2:
	var keys := Vector2(float(held("right",options) or Input.is_physical_key_pressed(KEY_RIGHT))-float(held("left",options) or Input.is_physical_key_pressed(KEY_LEFT)),float(held("down",options) or Input.is_physical_key_pressed(KEY_DOWN))-float(held("up",options) or Input.is_physical_key_pressed(KEY_UP)))
	var stick := Vector2(axis(JOY_AXIS_RIGHT_X if right_stick else JOY_AXIS_LEFT_X),axis(JOY_AXIS_RIGHT_Y if right_stick else JOY_AXIS_LEFT_Y))
	var deadzone: float = float(options.get("gamepad_deadzone",0.18))
	if stick.length()<=deadzone: stick=Vector2.ZERO
	else: stick=stick.normalized()*clampf((stick.length()-deadzone)/(1.0-deadzone),0.0,1.0)
	return (keys+stick).limit_length()

func move_pointer(mini: Control, options: Dictionary, delta: float) -> void:
	var direction: Vector2 = movement(options)
	if not virtual_active:
		if direction.length()<0.01: return
		virtual_cursor=mini.center()
		virtual_active=true
	virtual_cursor=(virtual_cursor+direction*330.0*delta).clamp(Vector2(8,30),mini.size-Vector2(8,8))
	mini.motion(virtual_cursor)
	mini.virtual_pointer=virtual_cursor
	mini.show_virtual_pointer=true
	mini.queue_redraw()

func pointer_action(mini: Control, pressed: bool) -> void:
	if not virtual_active:
		virtual_active=true
		virtual_cursor=mini.center()
	mini.virtual_pointer=virtual_cursor
	mini.show_virtual_pointer=true
	if pressed: mini.press(virtual_cursor)
	else: mini.release()
	mini.queue_redraw()

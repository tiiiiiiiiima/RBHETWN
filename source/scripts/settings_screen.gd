extends Panel
const Controls = preload("res://scripts/control_bindings.gd")
const Avatar = preload("res://scripts/avatar_view.gd")
const Mini = preload("res://scripts/ds_minigame_catalog.gd")
const Arenas = preload("res://scripts/arena_catalog.gd")
var owner_ui: Node
var tabs: TabContainer
var advanced: Dictionary = {}
var rebind_buttons: Dictionary = {}
var capture_action: String = ""
var capture_label: Label
var preview: SubViewportContainer
var avatar_ids: Array[String] = []
var _refreshing: bool = false

func build(ui: Node) -> void:
	owner_ui=ui
	position=Vector2(250,52); size=Vector2(940,790)
	add_theme_stylebox_override("panel",ui._style(Color("0b1122"),Color("37536b")))
	ui._label(self,"НАСТРОЙКИ",Vector2(24,15),Vector2(892,38),27,ui.CYAN,true)
	tabs=TabContainer.new()
	tabs.position=Vector2(24,65); tabs.size=Vector2(892,635)
	tabs.add_theme_font_override("font",ui.font_regular)
	tabs.add_theme_font_size_override("font_size",17)
	add_child(tabs)
	var game:=_tab("Игра")
	ui._label(game,"ПРАВИЛА",Vector2(16,20),Vector2(190,26),16,ui.ORANGE,true)
	ui.rules_selector=ui._option(game,Vector2(218,12),640)
	ui.rules_selector.add_item("Nintendo DS · карты и порядок действий")
	ui.rules_selector.add_item("Wii · отдельная колода")
	ui.rules_selector.item_selected.connect(ui._select_rules_profile)
	ui.rules_description=ui._label(game,"",Vector2(16,63),Vector2(842,35),14,ui.MUTED)
	ui._label(game,"АРЕНА",Vector2(16,115),Vector2(190,26),16,ui.ORANGE,true)
	ui.arena_selector=ui._option(game,Vector2(218,105),640)
	for entry: Dictionary in Arenas.ENTRIES: ui.arena_selector.add_item(str(entry.title))
	ui.arena_selector.item_selected.connect(ui._select_arena)
	ui.arena_description=ui._label(game,"",Vector2(16,162),Vector2(842,58),15,ui.MUTED)
	ui._label(game,"ОБЪЕКТЫ DS",Vector2(16,237),Vector2(190,26),16,ui.CYAN,true)
	ui.field_layout_selector=ui._option(game,Vector2(218,227),640)
	ui.field_layout_selector.item_selected.connect(ui._select_field_layout)
	ui._label(game,"СЛОЖНОСТЬ",Vector2(16,303),Vector2(190,26),16,ui.ORANGE,true)
	ui.difficulty_selector=ui._option(game,Vector2(218,292),640)
	for title: String in ["Лёгкая","Обычная","Сложная"]: ui.difficulty_selector.add_item(title)
	ui.difficulty_selector.item_selected.connect(ui._select_difficulty)
	ui.ds_gate_toggle=CheckButton.new()
	ui.ds_gate_toggle.text="Автоматическая постановка начальных ворот DS"
	ui.ds_gate_toggle.position=Vector2(16,355); ui.ds_gate_toggle.size=Vector2(842,44)
	game.add_child(ui.ds_gate_toggle)
	ui.ds_gate_toggle.toggled.connect(func(value: bool): _change("ds_auto_gates",value))
	ui._label(game,"МИНИ-ИГРА DS",Vector2(16,435),Vector2(190,26),16,ui.CYAN,true)
	ui.ds_minigame_selector=ui._option(game,Vector2(218,423),640)
	ui.ds_minigame_selector.add_item("Чередовать все шесть")
	for kind: String in Mini.MODES: ui.ds_minigame_selector.add_item(str(Mini.NAMES[kind]))
	ui.ds_minigame_selector.item_selected.connect(func(index: int): _change("ds_minigame","cycle" if index==0 else Mini.MODES[index-1]))
	ui._label(game,"Первый бой с подсказками: главное меню → Тренировка → Первый бой.",Vector2(16,500),Vector2(842,65),16,ui.MUTED)
	var graphics:=_tab("Графика")
	_choice(graphics,"Режим экрана","screen_mode",["Окно","Окно без рамки","Полный экран"],["window","borderless","fullscreen"],18)
	_choice(graphics,"Лимит кадров","frame_cap",["Без ограничения","30 FPS","60 FPS","120 FPS"],[0,30,60,120],84)
	_choice(graphics,"Сглаживание","msaa",["Выключено","MSAA 2×","MSAA 4×"],[0,2,4],150)
	_slider(graphics,"Масштаб 3D","render_scale",0.5,1.0,0.05,225)
	_toggle(graphics,"Вертикальная синхронизация","vsync",299)
	ui.motion_toggle=_toggle(graphics,"Меньше вспышек и движения камеры","reduced_motion",357)
	ui._label(graphics,"Интерфейс сохраняет чёткость при уменьшении масштаба 3D. Частота кадров зависит от компьютера; V-Sync — от драйвера.",Vector2(16,435),Vector2(842,90),17,ui.MUTED)
	var sound:=_tab("Звук")
	ui.volume_text=ui._label(sound,"ГРОМКОСТЬ",Vector2(16,18),Vector2(250,26),16,ui.ORANGE,true)
	ui.volume_slider=_slider(sound,"","volume",0,1,0.05,18)
	for index: int in 3:
		var key: String=["music_volume","effects_volume","voice_volume"][index]
		ui.channel_sliders[key]=_slider(sound,["Музыка","Эффекты","Голоса"][index],key,0,1,0.05,100+index*76)
	_toggle(sound,"Субтитры реплик","subtitles",344)
	var library: Button=ui._button(sound,"ПРОСЛУШАТЬ ИСХОДНЫЕ ЗВУКИ DS",Vector2(16,413),Vector2(842,48),ui.CYAN)
	library.pressed.connect(func(): ui.audio.open_library())
	ui._label(sound,"Сохраняется исходная английская озвучка. Неустановленные голоса доступны в библиотеке, без назначения персонажам.",Vector2(16,485),Vector2(842,90),17,ui.MUTED)
	var controls:=_tab("Управление")
	_slider(controls,"Чувствительность наведения","camera_sensitivity",0.5,2,0.1,15)
	_slider(controls,"Мёртвая зона стика","gamepad_deadzone",0.1,0.35,0.01,75)
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(16,148); scroll.size=Vector2(842,306)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	controls.add_child(scroll)
	var rows:=VBoxContainer.new(); rows.custom_minimum_size=Vector2(810,0)
	scroll.add_child(rows)
	for action: String in Controls.DEFAULTS:
		var row:=HBoxContainer.new(); rows.add_child(row)
		var label:=Label.new(); label.text=str(Controls.TITLES[action]); label.custom_minimum_size=Vector2(560,38)
		label.add_theme_font_size_override("font_size",16); row.add_child(label)
		var button:=Button.new(); button.custom_minimum_size=Vector2(224,38); row.add_child(button)
		button.pressed.connect(_capture.bind(action)); rebind_buttons[action]=button
	capture_label=ui._label(controls,"",Vector2(16,467),Vector2(842,47),15,ui.CYAN)
	var reset: Button=ui._button(controls,"СБРОСИТЬ КЛАВИШИ",Vector2(16,535),Vector2(292,40),ui.ORANGE)
	reset.pressed.connect(func(): _change("bindings",Controls.DEFAULTS.duplicate()))
	ui._label(controls,"Геймпад: A — действие; B — тормоз/назад; X — бросок; Y — особый; LB/RB — камера; D-pad — команда; Start — пауза. В мини-игре: стик + A или RT.",Vector2(324,523),Vector2(534,72),14,ui.MUTED)
	var avatars:=_tab("Аватар")
	ui._label(avatars,"ПЕРСОНАЖ DS",Vector2(16,23),Vector2(210,26),16,ui.CYAN,true)
	var selector: OptionButton=ui._option(avatars,Vector2(230,12),628)
	for id: String in Avatar.entries():
		avatar_ids.append(id)
		selector.add_item(str(Avatar.entries()[id].get("name",id)))
	selector.item_selected.connect(func(index: int): _change("avatar",avatar_ids[index]))
	advanced.avatar={"node":selector,"values":avatar_ids}
	preview=Avatar.new(); preview.position=Vector2(285,87); preview.size=Vector2(300,370)
	avatars.add_child(preview)
	ui._label(avatars,"Все 18 аватаров используют исходные модели, текстуры и анимации скелета DS. Выбранный аватар появляется рядом с боем; в кампании соперник выбирается по главе.",Vector2(16,482),Vector2(842,95),17,ui.MUTED)
	var done: Button=ui._button(self,"СОХРАНИТЬ И ВЕРНУТЬСЯ",Vector2(24,722),Vector2(892,46),ui.CYAN)
	done.pressed.connect(ui._close_preparation)
	visible=false

func _tab(title: String) -> Control:
	var content:=Control.new(); content.name=title; tabs.add_child(content)
	return content
func _choice(parent: Node,title: String,key: String,titles: Array,values: Array,y: float) -> void:
	owner_ui._label(parent,title,Vector2(16,y+8),Vector2(280,28),17,owner_ui.WHITE)
	var choice: OptionButton=owner_ui._option(parent,Vector2(306,y),552)
	for item: String in titles: choice.add_item(item)
	choice.item_selected.connect(func(index: int): _change(key,values[index]))
	advanced[key]={"node":choice,"values":values}
func _slider(parent: Node,title: String,key: String,low: float,high: float,step: float,y: float) -> HSlider:
	if not title.is_empty(): owner_ui._label(parent,title,Vector2(16,y+8),Vector2(280,30),17,owner_ui.WHITE)
	var slider:=HSlider.new(); slider.position=Vector2(306,y+8); slider.size=Vector2(462,32)
	slider.min_value=low; slider.max_value=high; slider.step=step; parent.add_child(slider)
	var value: Label=owner_ui._label(parent,"",Vector2(780,y+8),Vector2(78,30),16,owner_ui.CYAN)
	slider.value_changed.connect(func(amount: float): _change(key,amount))
	advanced[key]={"node":slider,"label":value}
	return slider
func _toggle(parent: Node,title: String,key: String,y: float) -> CheckButton:
	var toggle:=CheckButton.new(); toggle.position=Vector2(16,y); toggle.size=Vector2(842,42); toggle.text=title
	parent.add_child(toggle); toggle.toggled.connect(func(value: bool): _change(key,value))
	advanced[key]={"node":toggle}
	return toggle
func _change(key: String,value: Variant) -> void:
	if _refreshing: return
	owner_ui.preferences[key]=value
	owner_ui._apply_settings(); owner_ui._save_profile()
	refresh_advanced()
func refresh_advanced() -> void:
	_refreshing=true
	for key: String in advanced:
		var item: Dictionary=advanced[key]; var value: Variant=owner_ui.preferences[key]
		if item.node is OptionButton: item.node.select(maxi(0,item.values.find(value)))
		elif item.node is Range:
			item.node.set_value_no_signal(float(value)); item.label.text="%.0f%%" % (float(value)*100) if key!="camera_sensitivity" else "%.1f×" % float(value)
		elif item.node is BaseButton: item.node.set_pressed_no_signal(bool(value))
	for action: String in rebind_buttons: rebind_buttons[action].text=Controls.key_name(action,owner_ui.preferences)
	preview.show_avatar(str(owner_ui.preferences.avatar))
	_refreshing=false
func _capture(action: String) -> void:
	capture_action=action
	capture_label.text="Нажми новую клавишу для «%s». Esc — отмена." % Controls.TITLES[action]
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or capture_action.is_empty(): return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode==KEY_ESCAPE:
			capture_action=""; capture_label.text="Переназначение отменено."; return
		var key: int=int(event.physical_keycode if event.physical_keycode!=0 else event.keycode)
		if key in [KEY_ENTER,KEY_NONE] or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
			capture_label.text="Выбери отдельную клавишу. Enter и Esc используются в меню."; return
		var bindings: Dictionary=owner_ui.preferences.bindings.duplicate()
		for action: String in bindings:
			if action!=capture_action and int(bindings[action])==key:
				capture_label.text="Эта клавиша уже назначена: %s." % Controls.TITLES[action]; return
		bindings[capture_action]=key
		capture_action=""; capture_label.text="Клавиша сохранена."
		_change("bindings",bindings)

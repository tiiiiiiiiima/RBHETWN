extends Control
const FieldCards = preload("res://scripts/ds_field_cards.gd")
const DSPlayable = preload("res://scripts/ds_playable_catalog.gd")
## Reusable collection overlay. Parent pauses its own game while this is open.
## show_browser()/close_browser(), closed signal; no gameplay card effects.

signal closed

const Library = preload("res://scripts/source_card_library.gd")
const DSLibrary = preload("res://scripts/ds_card_catalog.gd")
const MonsterLibrary = preload("res://scripts/monster_batch_card_library.gd")
const SOURCES: Array[String] = ["ds", "workshop", "monster_batch"]
const PAGE_SIZE := 12
const WHITE := Color(0.94, 0.95, 1.0)
const MUTED := Color(0.66, 0.73, 0.84)
const ORANGE := Color(1.0, 0.52, 0.20)
const CYAN := Color(0.22, 0.77, 0.93)

var _source: String = "ds"
var _source_selector: OptionButton
var _source_note: Label
var _built: bool = false
var _kind: String = "all"
var _query: String = ""
var _playable_only: bool = false
var _playable_toggle: CheckButton
var _page: int = 0
var _matches: Array[Dictionary] = []
var _filter_buttons: Dictionary = {}
var _grid: GridContainer
var _page_label: Label
var _count_label: Label
var _previous: Button
var _next: Button
var _search: LineEdit
var _zoom_overlay: PanelContainer
var _zoom_image: TextureRect
var _zoom_title: Label
var _zoom_type: Label
var _zoom_description: RichTextLabel
var _zoom_level: Label
var _zoom_key: String = ""
var _zoom_factor: float = 1.0


func _ready() -> void:
	_build()
	hide()


func show_browser(kind: String = "all", source: String = "") -> void:
	_build()
	if source in SOURCES:
		_source = source
	_source_selector.select(SOURCES.find(_source))
	_kind = kind if kind in ["all", "gate", "ability", "other"] else "all"
	_page = 0
	_zoom_overlay.hide()
	_refresh_matches()
	show()
	_search.grab_focus()


func close_browser() -> void:
	if not visible:
		return
	_zoom_overlay.hide()
	_zoom_image.texture = null
	_clear_grid()
	Library.clear_texture_cache()
	DSLibrary.clear_texture_cache()
	MonsterLibrary.clear_texture_cache()
	hide()
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if _zoom_overlay.visible:
			_close_zoom()
		else:
			close_browser()
		get_viewport().set_input_as_handled()


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 120
	var font: Font = load("res://assets/ui.ttf") as Font
	var local_theme := Theme.new()
	local_theme.default_font = font
	local_theme.default_font_size = 16
	local_theme.set_color("font_color", "Label", WHITE)
	local_theme.set_color("font_color", "Button", WHITE)
	local_theme.set_color("font_color", "LineEdit", WHITE)
	local_theme.set_color("font_color", "RichTextLabel", WHITE)
	theme = local_theme
	var backdrop := PanelContainer.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_theme_stylebox_override("panel", _style(Color(0.025, 0.035, 0.07, 1.0), Color(0.18, 0.25, 0.38), 20))
	add_child(backdrop)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	backdrop.add_child(body)
	var heading := HBoxContainer.new()
	body.add_child(heading)
	var title := _label("КОЛЛЕКЦИЯ КАРТ", 27, ORANGE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := _button("Закрыть · Esc")
	close.pressed.connect(close_browser)
	heading.add_child(close)
	_count_label = _label("", 15, MUTED)
	body.add_child(_count_label)
	var source_row := HBoxContainer.new()
	source_row.add_theme_constant_override("separation", 12)
	body.add_child(source_row)
	source_row.add_child(_label("НАБОР", 14, CYAN))
	_source_selector = OptionButton.new()
	_source_selector.add_item("Nintendo DS · Battle Brawlers")
	_source_selector.add_item("Bakugan Anime Style Format")
	_source_selector.add_item("Monster batch")
	_source_selector.custom_minimum_size = Vector2(380, 36)
	_source_selector.item_selected.connect(func(index: int): _set_source(SOURCES[index]))
	source_row.add_child(_source_selector)
	_source_note = _label("", 14, MUTED)
	_source_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_source_note)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	body.add_child(filters)
	for entry: Array in [["all", "Все"], ["gate", "Ворота"], ["ability", "Способности"], ["other", "Другие"]]:
		var key: String = entry[0]
		var button := _button(entry[1])
		button.toggle_mode = true
		button.pressed.connect(func(): _set_kind(key))
		filters.add_child(button)
		_filter_buttons[key] = button
	_search = LineEdit.new()
	_search.placeholder_text = "Название или категория…"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.custom_minimum_size.x = 210
	_search.add_theme_stylebox_override("normal", _style(Color(0.06, 0.09, 0.15), Color(0.23, 0.32, 0.46), 10))
	_search.add_theme_stylebox_override("focus", _style(Color(0.07, 0.10, 0.17), CYAN, 10))
	_search.text_changed.connect(_set_query)
	filters.add_child(_search)
	_playable_toggle=CheckButton.new()
	_playable_toggle.text="Для боя DS"
	_playable_toggle.toggled.connect(func(enabled: bool):
		_playable_only=enabled; _page=0; _refresh_matches())
	filters.add_child(_playable_toggle)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	body.add_child(footer)
	_previous = _button("← Назад")
	_previous.pressed.connect(func(): _change_page(-1))
	footer.add_child(_previous)
	_page_label = _label("", 16, WHITE)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_page_label)
	_next = _button("Далее →")
	_next.pressed.connect(func(): _change_page(1))
	footer.add_child(_next)
	_build_zoom()


func _build_zoom() -> void:
	_zoom_overlay = PanelContainer.new()
	_zoom_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_zoom_overlay.add_theme_stylebox_override("panel", _style(Color(0.025, 0.035, 0.07, 1.0), CYAN, 20))
	add_child(_zoom_overlay)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	_zoom_overlay.add_child(columns)
	var image_column := VBoxContainer.new()
	image_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(image_column)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	image_column.add_child(tools)
	for entry: Array in [["−", -0.5], ["+", 0.5]]:
		var amount: float = entry[1]
		var button := _button(entry[0])
		button.custom_minimum_size.x = 45
		button.pressed.connect(func():
			_zoom_factor = clampf(_zoom_factor + amount, 1.0, 4.0)
			_update_zoom_size()
		)
		tools.add_child(button)
	_zoom_level = _label("", 15, MUTED)
	tools.add_child(_zoom_level)
	var fit := _button("Вписать")
	fit.pressed.connect(func():
		_zoom_factor = 1.0
		_update_zoom_size()
	)
	tools.add_child(fit)
	var image_scroll := ScrollContainer.new()
	image_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image_column.add_child(image_scroll)
	_zoom_image = TextureRect.new()
	_zoom_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if _source == "ds" else CanvasItem.TEXTURE_FILTER_LINEAR
	_zoom_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_zoom_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_scroll.add_child(_zoom_image)
	var details := VBoxContainer.new()
	details.custom_minimum_size.x = 370
	details.add_theme_constant_override("separation", 14)
	columns.add_child(details)
	_zoom_title = _label("", 23, WHITE)
	_zoom_title.custom_minimum_size.x = 370
	_zoom_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_zoom_title)
	_zoom_type = _label("", 15, CYAN)
	_zoom_type.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_zoom_type)
	_zoom_description = RichTextLabel.new()
	_zoom_description.bbcode_enabled = false
	_zoom_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_zoom_description.custom_minimum_size = Vector2(370, 170)
	details.add_child(_zoom_description)
	var usage := _label("Увеличивай изображение кнопками + / −; для чтения используй полосы прокрутки. Печатные эффекты относятся к исходному набору.", 14, MUTED)
	usage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(usage)
	var back := _button("← К коллекции · Esc")
	back.pressed.connect(_close_zoom)
	details.add_child(back)
	_zoom_overlay.hide()


func _library() -> Script:
	return DSLibrary if _source == "ds" else MonsterLibrary if _source == "monster_batch" else Library


func _set_source(source: String) -> void:
	if source not in SOURCES:
		return
	_close_zoom()
	_clear_grid()
	Library.clear_texture_cache()
	DSLibrary.clear_texture_cache()
	MonsterLibrary.clear_texture_cache()
	_source = source
	_source_selector.select(SOURCES.find(source))
	_page = 0
	_query = ""
	_search.set_text("")
	_refresh_matches()


func _set_kind(kind: String) -> void:
	_kind = kind
	_page = 0
	_refresh_matches()


func _set_query(query: String) -> void:
	_query = query
	_page = 0
	_refresh_matches()


func _refresh_matches() -> void:
	_matches = _library().cards(_kind, _query)
	_playable_toggle.disabled=_source!="ds"
	if _source=="ds" and _playable_only:
		_matches=_matches.filter(func(entry:Dictionary)->bool:return not DSPlayable.metadata(str(entry.get("key",""))).is_empty() or not FieldCards.metadata(str(entry.get("key",""))).is_empty())
	_source_note.text = "Исходные изображения и тексты Nintendo DS. %d карт доступны в колодах режима DS; 12 специальных карт собираются на поле; остальные пока входят в коллекцию." % DSPlayable.cards().size() if _source == "ds" else "Полные изображения из Bakugan Anime Style Format. Карты этой коллекции пока не участвуют в дуэлях."
	if _source == "monster_batch":
		_source_note.text = "Monster batch: ворота, способности и карточки характеристик. Только коллекция; эффекты фанатского набора пока не добавлены в дуэли."
	for key: String in _filter_buttons:
		(_filter_buttons[key] as Button).set_pressed_no_signal(key == _kind)
	_count_label.text = "%d карт: %d ворот · %d способностей · %d других. Найдено: %d" % [_library().total(), _library().total("gate"), _library().total("ability"), _library().total("other"), _matches.size()]
	_refresh_page()


func _change_page(direction: int) -> void:
	_page = clampi(_page + direction, 0, _page_count() - 1)
	_refresh_page()


func _page_count() -> int:
	return maxi(1, int(ceil(float(_matches.size()) / PAGE_SIZE)))


func _clear_grid() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()


func _refresh_page() -> void:
	_clear_grid()
	_page = clampi(_page, 0, _page_count() - 1)
	for index in range(_page * PAGE_SIZE, mini((_page + 1) * PAGE_SIZE, _matches.size())):
		var entry: Dictionary = _matches[index]
		var key: String = str(entry.get("key", ""))
		var button := _button("")
		button.custom_minimum_size = Vector2(180, 188)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.tooltip_text = str(entry.get("name", ""))
		button.pressed.connect(func(): _open_zoom(key))
		_grid.add_child(button)
		var inner := VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 10
		inner.offset_right = -10
		inner.offset_top = 7
		inner.offset_bottom = -7
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(inner)
		var image := TextureRect.new()
		image.texture = _library().thumbnail(key)
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if _source == "ds" else CanvasItem.TEXTURE_FILTER_LINEAR
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(110, 140)
		image.size_flags_vertical = Control.SIZE_EXPAND_FILL
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(image)
		var name := _label(str(entry.get("name", "Без названия")), 12, WHITE)
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name.max_lines_visible = 2
		name.custom_minimum_size.y = 30
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(name)
		if _source=="ds":
			var playable: bool = not DSPlayable.metadata(key).is_empty() or not FieldCards.metadata(key).is_empty()
			var badge: Label=_label("ДОСТУПНА ДЛЯ БОЯ" if playable else "ТОЛЬКО КОЛЛЕКЦИЯ",10,CYAN if playable else MUTED)
			badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
			inner.add_child(badge)
		if image.texture == null:
			name.text += " · изображение недоступно"
	_page_label.text = "Страница %d / %d · нажми на карту для увеличения" % [_page + 1, _page_count()]
	_previous.disabled = _page <= 0
	_next.disabled = _page >= _page_count() - 1


func _open_zoom(key: String) -> void:
	var entry: Dictionary = _library().metadata(key)
	if entry.is_empty():
		return
	_zoom_key = key
	_zoom_factor = 1.0
	_zoom_image.texture = _library().texture(key)
	_zoom_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if _source == "ds" else CanvasItem.TEXTURE_FILTER_LINEAR
	_zoom_title.text = str(entry.get("name", "Без названия"))
	var types := {"gate": "Карта ворот", "ability": "Карта способности", "other": "Характеристики / счётчик", "token": "Жетон", "unclassified": "Другие изображения"}
	_zoom_type.text = "%s\n%s" % [types.get(str(entry.get("kind", "")), "Карта"), str(entry.get("category", ""))]
	var description: String = str(entry.get("source_description", ""))
	_zoom_description.text = description if not description.is_empty() else "Описание для этой карты пока недоступно." if _source == "ds" else "Текст карты находится на исходном изображении."
	if _source == "ds":
		var field_card: Dictionary=FieldCards.metadata(key)
		if not field_card.is_empty():
			_zoom_type.text += "\nРаботает как предмет на поле DS; в колоду не входит"
			_zoom_description.text += "\n\nВ игре: "+str(field_card.description)
		var playable: Dictionary = DSPlayable.metadata(key)
		_zoom_type.text += "\nДоступна в колоде DS" if not playable.is_empty() else "" if not field_card.is_empty() else "\nТолько коллекция"
		if not playable.is_empty():
			_zoom_description.text += "\n\nВ игре: " + str(playable.get("description", ""))
			if str(playable.get("kind", "")) == "gate":
				var boosts: Dictionary = playable.get("boosts", {})
				for attribute: String in DSPlayable.ATTRIBUTES:
					_zoom_description.text += "\n%s +%d G" % [attribute, int(boosts.get(attribute, 0))]
	_zoom_overlay.show()
	_update_zoom_size()


func _close_zoom() -> void:
	_zoom_overlay.hide()
	_zoom_image.texture = null
	_zoom_key = ""


func _update_zoom_size() -> void:
	if _zoom_image.texture == null:
		_zoom_image.custom_minimum_size = Vector2(400, 500)
		_zoom_level.text = "Изображение недоступно"
		return
	var native_size: Vector2 = _zoom_image.texture.get_size()
	var available: Vector2 = get_viewport_rect().size - Vector2(480, 115)
	var fit_factor: float = minf(available.x / native_size.x, available.y / native_size.y)
	_zoom_image.custom_minimum_size = native_size * maxf(0.1, fit_factor) * _zoom_factor
	_zoom_level.text = "%d%% · %d × %d" % [roundi(_zoom_factor * 100.0), int(native_size.x), int(native_size.y)]


func _label(text: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result


func _button(text: String) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 36
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.add_theme_stylebox_override("normal", _style(Color(0.06, 0.09, 0.15), Color(0.25, 0.33, 0.46), 8))
	result.add_theme_stylebox_override("hover", _style(Color(0.10, 0.15, 0.23), CYAN, 8))
	result.add_theme_stylebox_override("pressed", _style(Color(0.09, 0.20, 0.27), CYAN, 8))
	result.add_theme_stylebox_override("focus", _style(Color(0.07, 0.12, 0.21), CYAN, 8))
	return result


func _style(background: Color, border: Color, padding: int) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = background
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(10)
	result.content_margin_left = padding
	result.content_margin_right = padding
	result.content_margin_top = padding
	result.content_margin_bottom = padding
	return result

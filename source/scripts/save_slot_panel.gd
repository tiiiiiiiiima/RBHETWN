extends Panel
const Slots = preload("res://scripts/save_slots.gd")
var game: Node3D
var kind: String = "campaign"
var selected: String = "campaign_1"
var category_buttons: Array[Button]=[]
var buttons: Array[Button] = []
var detail: Label
var message: Label
var resume: Button
var new_match: Button
func configure(controller: Node3D) -> void:
	game=controller; position=Vector2(180,130); size=Vector2(1080,620)
	add_theme_stylebox_override("panel",game._style(Color("0d1527"),Color("4b5476")))
	game._label(self,"СОХРАНЕНИЯ",Vector2(26,20),Vector2(1028,42),28,game.ORANGE,true)
	for index: int in Slots.KINDS.size():
		var button: Button=game._button(self,["КАМПАНИЯ","МАТЧИ / ТУРНИР","АНИМЕ-ДУЭЛИ"][index],Vector2(26+index*350,86),Vector2(328,48),game.CYAN)
		button.add_theme_font_size_override("font_size",16)
		button.pressed.connect(_category_changed.bind(index)); category_buttons.append(button)
	for index: int in Slots.COUNT:
		var button: Button=game._button(self,"",Vector2(26,152+index*80),Vector2(426,66),game.CYAN)
		button.add_theme_font_size_override("font_size",17)
		button.pressed.connect(_select.bind(index)); buttons.append(button)
	detail=game._label(self,"",Vector2(478,152),Vector2(570,258),18,game.WHITE)
	detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	message=game._label(self,"",Vector2(26,410),Vector2(1028,52),16,game.MUTED)
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	resume=game._button(self,"ПРОДОЛЖИТЬ",Vector2(26,482),Vector2(326,60),game.ORANGE)
	resume.pressed.connect(func(): game._resume_slot(selected))
	new_match=game._button(self,"",Vector2(374,482),Vector2(326,60),game.CYAN)
	new_match.pressed.connect(func(): game._new_slot_game(selected))
	var back: Button=game._button(self,"В МЕНЮ",Vector2(722,482),Vector2(326,60),game.CYAN)
	back.pressed.connect(game._close_preparation)
	hide()
func _category_changed(index: int) -> void:
	kind=Slots.KINDS[index]; selected=Slots.ids(kind)[0]; refresh()
func _select(index: int) -> void:
	selected=Slots.ids(kind)[index]; refresh()
func open(kind_id: String = "") -> void:
	if kind_id in Slots.KINDS: kind=kind_id
	selected=str({"campaign":game.campaign_slot,"free":game.free_slot,"anime":game.anime_slot}[kind])
	refresh(); category_buttons[Slots.KINDS.find(kind)].grab_focus()
func refresh() -> void:
	for index: int in category_buttons.size():
		category_buttons[index].text=("› " if Slots.KINDS[index]==kind else "")+["КАМПАНИЯ","МАТЧИ / ТУРНИР","АНИМЕ-ДУЭЛИ"][index]
	var entries: Array[String]=Slots.ids(kind)
	for index: int in entries.size():
		var value: Dictionary=Slots.record(entries[index]); var data: Dictionary=value.get("match",{})
		buttons[index].text="%sСЛОТ %d · %s" % ["› " if entries[index]==selected else "",index+1,"Бой сохранён" if not data.is_empty() else "Нет незаконченного боя"]
	var value: Dictionary=Slots.record(selected); var data: Dictionary=value.get("match",{})
	detail.text="%s · слот %s" % [Slots.LABELS[kind],selected.get_slice("_",1)]
	if kind=="campaign":
		var progress: Dictionary=game.campaign_profiles.get(selected,value.get("progress",{}))
		detail.text+="\nГлава %d / 7 · очки %d" % [int(progress.get("chapter",0))+1,int(progress.get("coins",0))]
	if not data.is_empty():
		var state: Dictionary=data.rules; var main: Dictionary=data.main
		if kind=="anime": detail.text+="\nАниме-дуэль · ход %d\nАрена: %s" % [int(state.turn_serial)+1,str(main.arena_id)]
		else: detail.text+="\n%s · %d : %d\nАрена: %s\nМомент: %s" % [str(main.rules_profile).to_upper(),state.scores[0],state.scores[1],str(data.field.theme),{"aim":"Прицеливание","flying":"Бросок","rolling":"Катание","battle":"Мини-игра","battle_ready":"Подготовка боя","ds_scene":"Сцена карты / боя","ai":"Ход соперника","double":"Двойная постановка","stay":"STAY","result":"Результат","opening":"Постановка ворот","place":"Постановка ворот"}.get(str(main.phase),str(main.phase))]
		var timestamp: int=int(value.get("saved_at",0))
		if timestamp>0: detail.text+="\nСохранено: "+Time.get_datetime_string_from_unix_time(timestamp).replace("T"," ")+" UTC"
	else: detail.text+="\nМожно начать новый бой."
	resume.disabled=data.is_empty()
	new_match.text="ОТКРЫТЬ КАМПАНИЮ" if kind=="campaign" else "НОВЫЙ БОЙ"
	message.text="Прогресс и бой каждого слота сохраняются отдельно. Начало нового боя в занятом слоте требует подтверждения."

extends Panel
const Campaign = preload("res://scripts/campaign.gd")
const Cards = preload("res://scripts/ds_playable_catalog.gd")
const Roster = preload("res://scripts/roster.gd")
var avatar: SubViewportContainer
var game: Node3D
var title: Label
var dialogue: Label
var resources: Label
var development: Label
var message: Label
var species: OptionButton
var start: Button
var upgrade: Button
var evolve: Button
var team_selectors: Array[OptionButton]=[]
var attribute_selectors: Array[OptionButton]=[]
var card_selectors: Dictionary={"gate":[],"ability":[]}
func configure(controller: Node3D) -> void:
	game=controller; position=Vector2(130,120); size=Vector2(1180,650)
	add_theme_stylebox_override("panel",game._style(Color("0d1527"),Color("4b5476")))
	title=game._label(self,"",Vector2(24,16),Vector2(1132,38),28,game.ORANGE,true)
	dialogue=game._label(self,"",Vector2(154,64),Vector2(1002,66),17,game.WHITE)
	avatar=preload("res://scripts/avatar_view.gd").new(); avatar.position=Vector2(24,55); avatar.size=Vector2(110,116)
	add_child(avatar)
	resources=game._label(self,"",Vector2(24,139),Vector2(1132,28),16,game.CYAN,true)
	game._label(self,"КОМАНДА КАМПАНИИ",Vector2(24,181),Vector2(480,28),18,game.ORANGE,true)
	for slot: int in 3:
		var option: OptionButton=game._option(self,Vector2(24+slot*378,216),358)
		option.item_selected.connect(_team_changed.bind(slot)); team_selectors.append(option)
		var attribute: OptionButton=game._option(self,Vector2(24+slot*378,271),358)
		for id: String in Roster.ATTRIBUTES: attribute.add_item(id)
		attribute.item_selected.connect(_attribute_changed.bind(slot)); attribute_selectors.append(attribute)
	game._label(self,"ВОРОТА И СПОСОБНОСТИ · ОТКРЫТЫЕ НАГРАДАМИ",Vector2(24,325),Vector2(850,28),18,game.CYAN,true)
	for kind: String in ["gate","ability"]:
		for slot: int in 3:
			var option: OptionButton=game._option(self,Vector2(24+slot*378,359 if kind=="gate" else 414),358)
			option.add_theme_font_size_override("font_size",14)
			option.item_selected.connect(_card_changed.bind(kind,slot)); card_selectors[kind].append(option)
	species=game._option(self,Vector2(24,485),340)
	species.item_selected.connect(func(_index: int): refresh_development())
	development=game._label(self,"",Vector2(24,538),Vector2(560,50),15,game.WHITE)
	upgrade=game._button(self,"",Vector2(384,485),Vector2(242,54),game.ORANGE)
	upgrade.pressed.connect(_upgrade)
	evolve=game._button(self,"ЭВОЛЮЦИЯ · 120",Vector2(642,485),Vector2(242,54),game.CYAN)
	evolve.pressed.connect(_evolve)
	message=game._label(self,"",Vector2(24,600),Vector2(672,32),15,game.MUTED)
	start=game._button(self,"",Vector2(900,485),Vector2(256,54),game.ORANGE)
	start.pressed.connect(game._launch_campaign)
	var back: Button=game._button(self,"В МЕНЮ",Vector2(900,553),Vector2(256,54),game.CYAN)
	back.pressed.connect(game._close_preparation)
	visible=false
func refresh() -> void:
	var progress=game.campaign; var data: Dictionary=progress.stage()
	avatar.show_avatar(str({"Дэн":"chara00","Маручо":"chara02","Руно":"chara01","Джули":"chara04","Шун":"chara03","Маскарад":"chara06"}.get(str(data.opponent),"chara00")))
	title.text="КАМПАНИЯ · %d / 7 · %s" % [progress.chapter+1,str(data.title).to_upper()]
	dialogue.text="Кампания пройдена! Развивай команду и повтори финал." if progress.completed else str(data.before)
	resources.text="ОЧКИ %d · БАКУГАНЫ %d · КАРТЫ %d · АРЕНЫ %d · СОПЕРНИК: %s" % [progress.coins,progress.unlocked_species.size(),progress.unlocked_cards.size(),progress.unlocked_arenas.size(),data.opponent]
	var units: Array[Dictionary]=progress.player_team()
	for slot: int in 3:
		var option: OptionButton=team_selectors[slot]; option.clear()
		for id: String in progress.unlocked_species:
			option.add_item("%s · ур. %d" % [Campaign.species_name(id),progress.level(id)])
			option.set_item_metadata(option.item_count-1,id)
			option.set_item_disabled(option.item_count-1,id!=progress.team[slot] and progress.team.has(id))
			if id==progress.team[slot]: option.select(option.item_count-1)
		for attribute_index: int in Roster.ATTRIBUTES.size():
			attribute_selectors[slot].set_item_text(attribute_index,Roster.ATTRIBUTES[attribute_index])
		attribute_selectors[slot].select(Roster.ATTRIBUTES.find(str(units[slot].attribute)))
		attribute_selectors[slot].set_item_text(attribute_selectors[slot].selected,"%s · %d G" % [units[slot].attribute,int(units[slot].g)])
		attribute_selectors[slot].tooltip_text="%d G · %s" % [int(units[slot].g),str(units[slot].get("g_note",""))]
	for kind: String in ["gate","ability"]:
		var colors: Array=Cards.GATE_COLORS if kind=="gate" else Cards.ABILITY_COLORS
		for slot: int in 3:
			var option: OptionButton=card_selectors[kind][slot]; option.clear()
			for entry: Dictionary in Cards.cards(kind):
				if str(entry.color_type)!=str(colors[slot]): continue
				var unlocked: bool=progress.unlocked_cards.has(str(entry.key))
				option.add_item(str(entry.title) if unlocked else "Закрыто · "+str(entry.title))
				option.set_item_metadata(option.item_count-1,str(entry.key)); option.set_item_disabled(option.item_count-1,not unlocked)
				if str(entry.key)==str(progress.decks[kind][slot]): option.select(option.item_count-1)
	var selected: String=str(species.get_item_metadata(species.selected)) if species.item_count>0 else progress.team[0]
	species.clear()
	for id: String in progress.unlocked_species:
		species.add_item(Campaign.species_name(id)); species.set_item_metadata(species.item_count-1,id)
		if id==selected: species.select(species.item_count-1)
	start.text="ПРОДОЛЖИТЬ БОЙ" if game._campaign_has_checkpoint() else "ПОВТОРИТЬ ФИНАЛ" if progress.completed else "НАЧАТЬ ГЛАВУ"
	var reward: Dictionary=progress.reward_preview(progress.chapter)
	message.text="Награда: %d очков · %s · %s" % [reward.coins,Campaign.species_name(str(reward.species)),str(reward.arena).trim_prefix("ds_").to_upper()] if not progress.completed else "Награды получены; повтор финала не выдаёт их снова."
	refresh_development()
func refresh_development() -> void:
	if species.item_count==0: return
	var id: String=str(species.get_item_metadata(species.selected)); var progress=game.campaign
	upgrade.text="УЛУЧШИТЬ · %d" % progress.upgrade_cost(id)
	upgrade.disabled=progress.level(id)>=5 or progress.coins<progress.upgrade_cost(id)
	evolve.disabled=not progress.evolution_error(id).is_empty(); evolve.tooltip_text=progress.evolution_error(id)
	development.text="%s · уровень %d / 5\n+20 G за уровень; эволюция меняет модель и даёт +60 G." % [Campaign.species_name(id),progress.level(id)]
	if progress.EVOLUTIONS.has(id): development.text+=" → "+Campaign.species_name(str(progress.EVOLUTIONS[id].to))
func _team_changed(index: int, slot: int) -> void:
	var id: String=str(team_selectors[slot].get_item_metadata(index))
	if not game.campaign.team.has(id): game.campaign.team[slot]=id
	game._save_profile(); refresh()
func _attribute_changed(index: int, slot: int) -> void:
	game.campaign.attributes[slot]=str(Roster.ATTRIBUTES[index]); game._save_profile(); refresh()
func _card_changed(index: int, kind: String, slot: int) -> void:
	game.campaign.set_card(kind,slot,str(card_selectors[kind][slot].get_item_metadata(index)))
	game._save_profile(); refresh()
func _upgrade() -> void:
	game.campaign.upgrade(str(species.get_item_metadata(species.selected))); game._save_profile(); refresh()
func _evolve() -> void:
	game.campaign.evolve(str(species.get_item_metadata(species.selected))); game._save_profile(); refresh()

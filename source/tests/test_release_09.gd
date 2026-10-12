extends SceneTree
## Menu attribute constraints, gallery categories and legacy save migration.

const Roster = preload("res://scripts/roster.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _index(id: String) -> int:
	for index: int in range(Roster.CREATURES.size()):
		if str(Roster.CREATURES[index].id) == id:
			return index
	return -1

func _run() -> void:
	var menu: Node3D = load("res://main.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	_check(ProjectSettings.get_setting("application/config/version") == "0.9.0", "Export declares current release")
	var chosen: Array = [_index("dragonoid"), _index("ingram"), _index("juggernoid")]
	menu.selected_roster = chosen
	menu.selected_attributes = ["Aquos", "Haos", "Aquos"]
	menu._open_roster()
	_check(menu.selected_attributes == ["Pyrus", "Ventus", "Aquos"], "Native hero partners normalize while generic Juggernoid keeps Aquos")
	_check(menu.attribute_selectors[0].disabled and menu.attribute_selectors[1].disabled and not menu.attribute_selectors[2].disabled, "UI enforces native partners and allows generic variants")
	menu._select_attribute(0, Roster.ATTRIBUTES.find("Aquos"))
	_check(menu.selected_attributes[0] == "Pyrus", "A forged disabled option cannot change Drago's native attribute")
	menu._select_attribute(2, Roster.ATTRIBUTES.find("Darkus"))
	_check(menu.selected_attributes[2] == "Darkus", "A generic species accepts another attribute")
	_check(menu.roster_power_labels[0].text.contains("условная") and menu.roster_source_labels[0].text.contains("не подтверждена"), "Unverified anime G remains explicit in preparation")
	menu._select_roster_slot(0, _index("neo_dragonoid"))
	_check(menu.roster_power_labels[0].text.contains("400 G") and menu.roster_power_labels[0].text.contains("по источнику"), "Confirmed Neo starting power appears with provenance")
	menu._close_roster()
	menu._open_model(0)
	_check(menu.model_species_selector.item_count == 117, "Default collection retains all existing models")
	menu.model_category_buttons[2].pressed.emit()
	_check(menu.model_category == "trap" and menu.model_species_selector.item_count == 17, "Trap category contains exactly the real traps")
	for entry: Dictionary in menu._model_entries():
		_check(str(entry.classification) == "trap" and str(entry.name) != "Shadow Wing", "Trap collection excludes paired support")
	menu.model_category_buttons[3].pressed.emit()
	_check(menu.model_species_selector.item_count == 1 and menu.model_name.text.contains("Shadow Wing") and menu.model_name.text.contains("ПАРНАЯ"), "Shadow Wing has a separate support category")
	menu.model_category_buttons[1].pressed.emit()
	_check(menu.model_species_selector.item_count == 99, "Ordinary roster stays separate from supports")
	menu.model_catalog_index = _index("dragonoid")
	menu.model_attribute = "Aquos"
	menu._render_model()
	_check(menu.model_name.text.contains("Aquos") and not menu.model_attribute_selector.disabled, "Collection still shows non-native physical colours")
	menu._close_preparation()
	var old: ConfigFile = ConfigFile.new()
	old.set_value("profile", "schema", 6)
	old.set_value("team", "selection", chosen)
	old.set_value("team", "attributes", ["Aquos", "Haos", "Darkus"])
	old.set_value("results", "wins", 13)
	old.set_value("results", "losses", 2)
	old.set_value("controls", "throw_style", "straight")
	old.set_value("settings", "preferences", {"reduced_motion": true, "volume": 0.4, "difficulty": "hard"})
	old.set_value("environment", "id", "anime_board")
	old.set_value("deck", "selection", [3, 4, 5])
	old.set_value("gates", "selection", [3, 4, 5])
	old.set_value("tournament", "progress", {"stage": 1, "active": true, "completed": false})
	_check(old.save("user://legacy09.cfg") == OK, "Legacy fixture can be written")
	menu._load_profile("user://legacy09.cfg")
	_check(menu.selected_roster == chosen and menu.selected_attributes == ["Pyrus", "Ventus", "Darkus"], "Legacy save converts native attributes without changing team order")
	_check(menu.wins == 13 and menu.losses == 2 and menu.throw_style == "straight" and menu.selected_arena == "anime_board", "Migration retains results, throw style and arena")
	_check(menu.selected_deck == [3, 4, 5] and menu.selected_gate_deck == [3, 4, 5] and menu.preferences.reduced_motion, "Migration retains decks and settings")
	_check(menu.tournament.stage == 1 and menu.tournament.active, "Migration retains tournament progress")
	menu._save_profile("user://migrated09.cfg")
	var saved: ConfigFile = ConfigFile.new()
	_check(saved.load("user://migrated09.cfg") == OK and saved.get_value("team", "attributes") == ["Pyrus", "Ventus", "Darkus"], "Migrated native attributes persist")
	menu._start_quick_match()
	_check(menu.phase == "opening" and menu.rules.teams[0].size() == 3, "Classic quick match still starts with three ordinary units")
	_check(menu.rules.teams[0][0].attribute == "Pyrus" and menu.rules.teams[0][1].attribute == "Ventus", "Classic match receives the native selection")
	menu.queue_free()
	await process_frame
	print("RELEASE 0.9: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

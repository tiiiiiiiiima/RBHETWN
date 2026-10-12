extends RefCounted
## Diagnostics use a separate profile; ordinary user paths never change.
static var diagnostic_mode: bool = OS.get_cmdline_user_args().has("--verify-release")
static func resolve(path: String) -> String:
	if diagnostic_mode and path.begins_with("user://") and not path.begins_with("user://diagnostics/"):
		var release: String=str(ProjectSettings.get_setting("application/config/version","0.23.0")).trim_suffix(".0")
		return "user://diagnostics/"+release+"/"+path.trim_prefix("user://")
	return path
static func prepare(path: String) -> Error:
	return DirAccess.make_dir_recursive_absolute(resolve(path).get_base_dir())
static func write_config(config: ConfigFile, path: String) -> Error:
	path=resolve(path)
	var error: Error=prepare(path)
	if error!=OK: return error
	error=config.save(path+".tmp")
	if error!=OK: return error
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path+".bak"):
			error=DirAccess.remove_absolute(path+".bak")
			if error!=OK: return error
		error=DirAccess.rename_absolute(path,path+".bak")
		if error!=OK: return error
	return DirAccess.rename_absolute(path+".tmp",path)
static func quit_or_warn(parent: Node, errors: Array) -> void:
	if errors.all(func(error: Variant) -> bool: return error==OK):
		parent.get_tree().quit(); return
	if parent.has_method("_toggle_pause") and not parent.paused: parent._toggle_pause()
	elif parent.has_method("_set_paused") and not parent.paused: parent._set_paused(true)
	var dialog: ConfirmationDialog=parent.get_node_or_null("SaveFailureDialog") as ConfirmationDialog
	if dialog==null:
		dialog=ConfirmationDialog.new(); dialog.name="SaveFailureDialog"
		dialog.process_mode=Node.PROCESS_MODE_ALWAYS
		dialog.title="Не удалось сохранить игру"
		dialog.dialog_text="Последние изменения не записаны. Можно вернуться к игре и освободить место на диске или выйти без сохранения."
		dialog.ok_button_text="Выйти без сохранения"; dialog.cancel_button_text="Вернуться"
		dialog.confirmed.connect(parent.get_tree().quit)
		parent.add_child(dialog)
	dialog.popup_centered(Vector2i(560,180))

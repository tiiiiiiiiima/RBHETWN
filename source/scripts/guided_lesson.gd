extends Panel
## An observed real match. No fabricated landings, scores or victories.
const Avatar = preload("res://scripts/avatar_view.gd")
const Controls = preload("res://scripts/control_bindings.gd")
var game: Node
var active: bool = false
var step: int = 0
var title: Label
var body: Label
var next: Button
var avatar: SubViewportContainer
var attempts: int = 0
var seen_battle: bool = false
var _last_step: int = -1

func build(ui: Node) -> void:
	game=ui
	position=Vector2(24,144); size=Vector2(232,546)
	add_theme_stylebox_override("panel",ui._style(Color("101b2a"),Color("67d7f7")))
	avatar=Avatar.new(); avatar.position=Vector2(34,10); avatar.size=Vector2(164,151)
	add_child(avatar); avatar.show_avatar("chara00")
	title=ui._label(self,"",Vector2(14,165),Vector2(204,54),17,ui.CYAN,true)
	body=ui._label(self,"",Vector2(14,224),Vector2(204,237),15,ui.WHITE)
	next=ui._button(self,"ДАЛЬШЕ",Vector2(14,480),Vector2(204,48),ui.CYAN)
	next.add_theme_font_size_override("font_size",14)
	next.pressed.connect(advance)
	visible=false
	avatar.set_suspended(true)

func begin() -> void:
	active=true; step=0; attempts=0; seen_battle=false; _last_step=-1
	visible=true; refresh()

func cancel() -> void:
	active=false; visible=false
	avatar.set_suspended(true)
	game.controls.virtual_active=false

func observe(event: String) -> void:
	if not active: return
	if step==1 and event=="unit": step=2
	elif step==2 and event=="aim": step=3
	elif step==3 and event=="throw": step=4; attempts+=1
	refresh()

func advance() -> void:
	if not active: return
	if step==0: step=1
	elif step in [5,6,7]: step+=1
	elif step==9:
		game.preferences.tutorial_completed=true
		game._save_profile()
		cancel()
	refresh()

func update() -> void:
	if not active: return
	visible=not game.overlay.visible and game.phase not in ["menu","finished"]
	avatar.set_suspended(game.paused or not visible)
	if game.paused: return
	if step==4 and game.phase in ["ai","aim","stay","double"]: step=5
	if step==5 and game.phase=="aim" and not seen_battle:
		step=2
	if game.phase=="battle_ready":
		seen_battle=true
		if step<5: step=5
	if step==8 and game.phase=="result" and not game.last_battle_result.is_empty(): step=9
	refresh()

func permits_throw() -> bool:
	return not active or step>=3
func permits_battle() -> bool:
	return not active or step>=8

func refresh() -> void:
	if not active: return
	var action: String=Controls.key_name("action",game.preferences)
	var instructions: Array[String]=[
		"Дэн: Побеждает тот, кто заберёт три карты ворот. Первые две карты уже на поле. Пройдём настоящий первый бой вместе.",
		"Выбери бакугана кнопкой команды или клавишей 1–3. У каждого есть стихия и исходная G-Power.",
		"Щёлкни по карте на мини-карте справа или наведи цель клавишами движения / левым стиком. Лучше выбрать уже занятую соперником карту.",
		"Зажми сферу и проведи мышью вверх. Или удержи %s / A для силы и отпусти. T / X меняет высокий и прямой бросок." % action,
		"В полёте и при катании управляй направлением. Shift / B — тормоз, %s / A — прыжок. Жёлтые G дают силу только после попадания на карту." % action,
		"Когда два соперника стоят на одной карте, начинаются бой и раскрытие ворот. Дождись соперника. Если промахнулся — можно попробовать ещё раз.",
		"База — сила бакугана. Ворота добавляют бонус его стихии. Сбор — жёлтые G с поля. Урон вычитается. Способности дают отдельный бонус; формула обоих участников видна под сценой.",
		"Выбери подходящую способность кнопкой карты / 1–3. Недоступная карта объясняет причину. Порядок выбора задаёт цепь; можно начать и без способностей.",
		"Нажми %s / A для начала. Scratch: зажми знак и двигай курсор. С клавиатуры: %s + движение; геймпад: A или RT + стик. Мини-игра меняет шкалу преимущества, а не показанное G." % [action,action],
		"Бой завершён. Результат зависит от G-Power, способностей и шкалы мини-игры. Теперь можно продолжить тренировочный матч до трёх карт. Победы и поражения здесь не записываются."]
	if step==5 and game.phase=="battle_ready": instructions[5]="Соперник на твоей карте! Ворота открылись. Бонус зависит от стихии каждого бакугана. Посмотри на карточку и нажми «Дальше»."
	if step==9:
		instructions[9]="Ты выиграл первый бой! "+instructions[9] if int(game.last_battle_result.get("owner",1))==0 else "В первом бою победил соперник. "+instructions[9]
	title.text="ПЕРВЫЙ БОЙ · %d/10" % (step+1)
	body.text=instructions[clampi(step,0,9)]
	next.visible=step in [0,6,7,9] or (step==5 and game.phase=="battle_ready")
	next.text="ПРОДОЛЖИТЬ МАТЧ" if step==9 else "ДАЛЬШЕ"
	if step!=_last_step:
		_last_step=step
		game._play_sound("switch")

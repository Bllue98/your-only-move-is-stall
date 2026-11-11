extends CanvasLayer
## Interface criada por código: placar, fase, contagem, abas Mover/Chutar e botão Confirmar.

signal plan_changed
signal confirm_pressed

var tabs: TabContainer
var sl_dir: HSlider
var sl_force: HSlider
var sl_elev: HSlider
var sl_lat: HSlider
var sl_vert: HSlider
var msg_label: Label
var countdown_label: Label
var phase_label: Label
var score_label: Label
var panel: PanelContainer
var confirm_btn: Button
var info_label: Label


func _ready() -> void:
	score_label = Label.new()
	score_label.text = "Azul 0 x 0 Vermelho"
	score_label.add_theme_font_size_override("font_size", 28)
	add_child(score_label)
	score_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 10)

	phase_label = Label.new()
	phase_label.text = "PLANEJAMENTO"
	phase_label.add_theme_font_size_override("font_size", 20)
	phase_label.position = Vector2(12, 10)
	add_child(phase_label)

	countdown_label = Label.new()
	countdown_label.text = "30"
	countdown_label.add_theme_font_size_override("font_size", 40)
	countdown_label.modulate = Color.YELLOW
	countdown_label.position = Vector2(12, 40)
	add_child(countdown_label)

	info_label = Label.new()
	info_label.position = Vector2(12, 100)
	info_label.modulate = Color.ORANGE
	add_child(info_label)

	panel = PanelContainer.new()
	add_child(panel)
	var vbox: VBoxContainer = VBoxContainer.new()
	panel.add_child(vbox)

	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(420, 190)
	vbox.add_child(tabs)

	var move_box: VBoxContainer = VBoxContainer.new()
	move_box.name = "Mover"
	var move_lbl: Label = Label.new()
	move_lbl.text = "Clique no campo para definir o destino."
	move_box.add_child(move_lbl)
	tabs.add_child(move_box)

	var kick_box: VBoxContainer = VBoxContainer.new()
	kick_box.name = "Chutar"
	sl_dir = _make_row(kick_box, "Direção (°)", -90.0, 90.0, 0.0, 1.0)
	sl_force = _make_row(kick_box, "Força (m/s)", 0.0, 30.0, 20.0, 0.5)
	sl_elev = _make_row(kick_box, "Elevação (°)", 0.0, 45.0, 15.0, 1.0)
	sl_lat = _make_row(kick_box, "Efeito lateral", -1.0, 1.0, 0.0, 0.05)
	sl_vert = _make_row(kick_box, "Efeito vertical", -1.0, 1.0, 0.0, 0.05)
	msg_label = Label.new()
	msg_label.modulate = Color.RED
	kick_box.add_child(msg_label)
	tabs.add_child(kick_box)
	tabs.tab_changed.connect(_on_tab_changed)

	confirm_btn = Button.new()
	confirm_btn.text = "Confirmar"
	confirm_btn.pressed.connect(func() -> void: confirm_pressed.emit())
	vbox.add_child(confirm_btn)

	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 10)


func _make_row(parent: Control, title: String, min_v: float, max_v: float, def_v: float, step_v: float) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	var lbl: Label = Label.new()
	lbl.text = title
	lbl.custom_minimum_size = Vector2(120, 0)
	var sl: HSlider = HSlider.new()
	sl.min_value = min_v
	sl.max_value = max_v
	sl.step = step_v
	sl.value = def_v
	sl.custom_minimum_size = Vector2(190, 0)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val: Label = Label.new()
	val.text = "%.2f" % def_v
	val.custom_minimum_size = Vector2(50, 0)
	sl.value_changed.connect(_on_slider_changed.bind(val))
	row.add_child(lbl)
	row.add_child(sl)
	row.add_child(val)
	parent.add_child(row)
	return sl


func _on_slider_changed(v: float, val_label: Label) -> void:
	val_label.text = "%.2f" % v
	plan_changed.emit()


func _on_tab_changed(_i: int) -> void:
	plan_changed.emit()


func get_tab() -> int:
	return tabs.current_tab


func set_tab(i: int) -> void:
	tabs.current_tab = i


func set_kick_values(d: float, f: float, e: float, lat: float, vert: float) -> void:
	sl_dir.value = d
	sl_force.value = f
	sl_elev.value = e
	sl_lat.value = lat
	sl_vert.value = vert


func get_kick_values() -> Dictionary:
	return {"dir_deg": sl_dir.value, "force": sl_force.value, "elev": sl_elev.value, "lat": sl_lat.value, "vert": sl_vert.value}


func set_phase(t: String) -> void:
	phase_label.text = t


func set_countdown(t: String) -> void:
	countdown_label.text = t


func set_score(a: int, b: int) -> void:
	score_label.text = "Azul %d x %d Vermelho" % [a, b]


func set_message(t: String) -> void:
	msg_label.text = t


func set_info(t: String) -> void:
	info_label.text = t


func set_panel_enabled(on: bool) -> void:
	panel.visible = on

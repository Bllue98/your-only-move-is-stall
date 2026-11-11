extends Node3D
## Máquina de estados PLANNING -> EXECUTING -> PLANNING, placar, espectros (ghosts) e autoteste.

enum State { PLANNING, EXECUTING }

const BallScript = preload("res://scripts/ball.gd")
const PlayerScript = preload("res://scripts/player.gd")

signal planning_started
signal a_action_finished

@export var planning_seconds: float = 30.0
## Liga o autoteste (compara espectro azul x execução real e testa gol). Desligar para jogar.
@export var selftest: bool = false

const FIELD_HX: float = 20.0
const FIELD_HZ: float = 12.0
const GOAL_W: float = 7.32
const GOAL_H: float = 2.44
const AI_COUNT: int = 5  # parado, avançar, recuar, desviar esq., desviar dir.
const START_A: Vector3 = Vector3(-8.0, 0.0, 0.0)
const START_B: Vector3 = Vector3(8.0, 0.0, 0.0)
const START_BALL: Vector3 = Vector3(0.0, 0.22, 0.0)

var state: int = State.PLANNING
var score_a: int = 0
var score_b: int = 0
var ai_index: int = 0
var planning_left: float = 0.0
var move_target: Variant = null

var a_recording: bool = false
var real_log: Dictionary = {}
var last_real_log: Dictionary = {}
var ghost_a_log: Dictionary = {}

var ghost_root: Node3D
var _mat_cache: Dictionary = {}

@onready var ball = $Ball
@onready var pa = $PlayerA
@onready var pb = $PlayerB
@onready var ui = $UI
@onready var camera: Camera3D = $Camera3D
@onready var light: DirectionalLight3D = $DirectionalLight3D


func _ready() -> void:
	Engine.physics_ticks_per_second = 60
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 30.0
	camera.rotation_degrees = Vector3(-35.264, 45.0, 0.0)
	camera.position = camera.basis.z * 40.0
	light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	_build_field()
	ghost_root = Node3D.new()
	ghost_root.name = "Ghosts"
	add_child(ghost_root)

	ui.plan_changed.connect(_update_ghosts)
	ui.confirm_pressed.connect(_on_confirm)
	_reset_round()
	_start_planning()
	if selftest:
		_run_selftest()


# ---------------------------------------------------------------- campo

func _build_field() -> void:
	var t: float = 0.12
	_add_box(Vector3(0, 0.01, -FIELD_HZ), Vector3(FIELD_HX * 2.0, 0.02, t), Color.WHITE)
	_add_box(Vector3(0, 0.01, FIELD_HZ), Vector3(FIELD_HX * 2.0, 0.02, t), Color.WHITE)
	_add_box(Vector3(-FIELD_HX, 0.01, 0), Vector3(t, 0.02, FIELD_HZ * 2.0), Color.WHITE)
	_add_box(Vector3(FIELD_HX, 0.01, 0), Vector3(t, 0.02, FIELD_HZ * 2.0), Color.WHITE)
	_add_box(Vector3(0, 0.01, 0), Vector3(t, 0.02, FIELD_HZ * 2.0), Color.WHITE)
	var goal_col: Color = Color(0.85, 0.85, 0.85, 0.6)
	_add_box(Vector3(-FIELD_HX - 0.5, GOAL_H * 0.5, 0), Vector3(1.0, GOAL_H, GOAL_W), goal_col)
	_add_box(Vector3(FIELD_HX + 0.5, GOAL_H * 0.5, 0), Vector3(1.0, GOAL_H, GOAL_W), goal_col)


func _add_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color, color.a < 1.0, false)
	mi.position = pos
	add_child(mi)


func _mat(color: Color, alpha: bool, unshaded: bool) -> StandardMaterial3D:
	var key: String = "%s|%s|%s" % [color, alpha, unshaded]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_cache[key] = m
	return m


# ---------------------------------------------------------------- fluxo de turnos

func _reset_round() -> void:
	ball.reset_to(START_BALL)
	pa.reset_to(START_A)
	pb.reset_to(START_B)
	ai_index = 0
	a_recording = false


func _start_planning() -> void:
	state = State.PLANNING
	move_target = null
	ui.set_phase("PLANEJAMENTO")
	ui.set_score(score_a, score_b)
	if not pa.is_free():
		# Azul ainda está preso na ação longa: só o adversário (automático) age.
		_commit({})
		return
	planning_left = planning_seconds
	ui.set_panel_enabled(true)
	ui.set_info("")
	_update_ghosts()
	planning_started.emit()


func _process(delta: float) -> void:
	if state == State.PLANNING and pa.is_free():
		planning_left -= delta
		ui.set_countdown(str(maxi(0, int(ceil(planning_left)))))
		if planning_left <= 0.0:
			_on_confirm(true)


func _on_confirm(timeout: bool = false) -> void:
	if state != State.PLANNING or not pa.is_free():
		return
	var plan: Dictionary = _current_plan()
	if plan["type"] == "kick" and not pa.in_kick_range(ball.position):
		if not timeout:
			ui.set_message("longe demais")
			return
		plan = {"type": "idle"}
	_commit(plan)


func _commit(plan: Dictionary) -> void:
	state = State.EXECUTING
	ui.set_panel_enabled(false)
	ui.set_phase("EXECUÇÃO")
	ui.set_countdown("")
	_clear_ghosts()
	if pa.is_free():
		_apply_plan(pa, plan if not plan.is_empty() else {"type": "idle"})
		a_recording = true
		real_log = {"p": [pa.position], "b": [ball.position]}
		ui.set_info("")
	else:
		ui.set_info("Azul preso na ação em curso...")
	if pb.is_free():
		_start_ai(pb, ai_index % AI_COUNT, ball.position)
		ai_index += 1


func _physics_process(_delta: float) -> void:
	if state != State.EXECUTING:
		return
	# Passo fixo: mesma ordem usada nos espectros (_run_log).
	pa.tick(ball)
	pb.tick(ball)
	ball.tick()
	if a_recording:
		real_log["p"].append(pa.position)
		real_log["b"].append(ball.position)
	var g: int = ball.goal_side()
	if g != 0:
		if g > 0:
			score_a += 1
		else:
			score_b += 1
		_reset_round()
		_start_planning()
		return
	var a_free: bool = pa.is_free()
	if a_free and a_recording:
		a_recording = false
		last_real_log = real_log
		a_action_finished.emit()
	if a_free or pb.is_free():
		_start_planning()


# ---------------------------------------------------------------- ações

func _kick_dict() -> Dictionary:
	var v: Dictionary = ui.get_kick_values()
	var a: float = deg_to_rad(v["dir_deg"])
	return {"dir": Vector3(cos(a), 0.0, sin(a)), "force": v["force"], "elev": v["elev"], "lat": v["lat"], "vert": v["vert"]}


func _current_plan() -> Dictionary:
	if ui.get_tab() == 1:
		return {"type": "kick", "kick": _kick_dict()}
	if move_target != null:
		return {"type": "move", "target": move_target}
	return {"type": "idle"}


func _apply_plan(p: Node3D, plan: Dictionary) -> void:
	match plan["type"]:
		"move":
			p.start_move(plan["target"])
		"kick":
			p.start_kick(plan["kick"])
		_:
			p.start_idle()


## Ações do adversário: 0 parado, 1 avançar na bola, 2 recuar p/ o gol (+x), 3 desviar esq., 4 desviar dir.
func _start_ai(p: Node3D, idx: int, ball_pos: Vector3) -> void:
	match idx:
		0:
			p.start_idle()
		1:
			p.start_move(Vector3(ball_pos.x, 0.0, ball_pos.z), p.ticks_advance_retreat)
		2:
			p.start_move(Vector3(FIELD_HX, 0.0, 0.0), p.ticks_advance_retreat)
		3:
			p.start_move(p.position + Vector3(0.0, 0.0, -100.0), p.ticks_dodge)
		_:
			p.start_move(p.position + Vector3(0.0, 0.0, 100.0), p.ticks_dodge)


func _unhandled_input(event: InputEvent) -> void:
	if state != State.PLANNING or not pa.is_free() or ui.get_tab() != 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var o: Vector3 = camera.project_ray_origin(event.position)
		var d: Vector3 = camera.project_ray_normal(event.position)
		if absf(d.y) < 0.000001:
			return
		var hit: Vector3 = o + d * (-o.y / d.y)
		hit.x = clampf(hit.x, -FIELD_HX, FIELD_HX)
		hit.z = clampf(hit.z, -FIELD_HZ, FIELD_HZ)
		hit.y = 0.0
		move_target = hit
		_update_ghosts()


# ---------------------------------------------------------------- espectros

func _clone_player(src: Node3D) -> Node3D:
	var c: Node3D = PlayerScript.new()
	c.copy_from(src)
	return c


func _clone_ball() -> Node3D:
	var c: Node3D = BallScript.new()
	c.copy_from(ball)
	return c


## Roda a MESMA simulação (mesma ordem de tick) numa cópia, até a ação do jogador acabar.
func _run_log(p: Node3D, b: Node3D) -> Dictionary:
	var lp: Array = [p.position]
	var lb: Array = [b.position]
	while not p.is_free():
		p.tick(b)
		b.tick()
		lp.append(p.position)
		lb.append(b.position)
	return {"p": lp, "b": lb}


func _clear_ghosts() -> void:
	for c in ghost_root.get_children():
		ghost_root.remove_child(c)
		c.queue_free()


func _update_ghosts() -> void:
	_clear_ghosts()
	ghost_a_log = {}
	if state != State.PLANNING:
		return
	if pa.is_free():
		var plan: Dictionary = _current_plan()
		var pc: Node3D = _clone_player(pa)
		var bc: Node3D = _clone_ball()
		_apply_plan(pc, plan)
		ghost_a_log = _run_log(pc, bc)
		_draw_ghost(ghost_a_log, Color(0.2, 0.4, 1.0, 0.4), true)
		pc.free()
		bc.free()
		if plan["type"] == "kick" and not pa.in_kick_range(ball.position):
			ui.set_message("longe demais")
		else:
			ui.set_message("")
	var red: Color = Color(1.0, 0.15, 0.15, 0.22)
	if pb.is_free():
		for i in range(AI_COUNT):
			var pc2: Node3D = _clone_player(pb)
			var bc2: Node3D = _clone_ball()
			_start_ai(pc2, i, ball.position)
			var lg: Dictionary = _run_log(pc2, bc2)
			var col: Color = red
			if i == ai_index % AI_COUNT:
				col.a = 0.45  # a próxima ação do rodízio fica mais forte
			_draw_ghost(lg, col, false)
			pc2.free()
			bc2.free()
	else:
		var pc3: Node3D = _clone_player(pb)
		var bc3: Node3D = _clone_ball()
		_draw_ghost(_run_log(pc3, bc3), red, false)
		pc3.free()
		bc3.free()


func _draw_ghost(lg: Dictionary, color: Color, with_ball: bool) -> void:
	var lp: Array = lg["p"]
	var lb: Array = lg["b"]
	var n: int = lp.size()
	var ball_col: Color = Color(color.r, color.g, color.b, 0.55)
	for i in range(n):
		if i % 10 == 0 or i == n - 1:
			_ghost_capsule(lp[i], color)
			if with_ball:
				_ghost_sphere(lb[i], ball_col)
	_ghost_line(lp, color, 0.05)
	if with_ball:
		_ghost_line(lb, ball_col, 0.0)


func _ghost_capsule(pos: Vector3, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var m: CapsuleMesh = CapsuleMesh.new()
	m.radius = 0.35
	m.height = 1.8
	mi.mesh = m
	mi.material_override = _mat(color, true, false)
	mi.position = pos + Vector3(0.0, 0.9, 0.0)
	ghost_root.add_child(mi)


func _ghost_sphere(pos: Vector3, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var m: SphereMesh = SphereMesh.new()
	m.radius = 0.22
	m.height = 0.44
	mi.mesh = m
	mi.material_override = _mat(color, true, false)
	mi.position = pos
	ghost_root.add_child(mi)


func _ghost_line(pts: Array, color: Color, y_off: float) -> void:
	if pts.size() < 2:
		return
	var im: ImmediateMesh = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in pts:
		im.surface_add_vertex(p + Vector3(0.0, y_off, 0.0))
	im.surface_end()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = _mat(Color(color.r, color.g, color.b, 0.9), true, true)
	ghost_root.add_child(mi)


# ---------------------------------------------------------------- autoteste

func _logs_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	if a["p"].size() != b["p"].size() or a["b"].size() != b["b"].size():
		print("DIFF tamanho ", a["p"].size(), " vs ", b["p"].size())
		return false
	for i in range(a["p"].size()):
		if a["p"][i] != b["p"][i] or a["b"][i] != b["b"][i]:
			print("DIFF i=", i, " p ", a["p"][i], " vs ", b["p"][i], " b ", a["b"][i], " vs ", b["b"][i])
			return false
	return true


func _run_selftest() -> void:
	var out: Array[String] = []
	await get_tree().process_frame

	# 1) chute com efeito: espectro azul == execução real
	pa.reset_to(Vector3(-1.0, 0.0, 0.0))
	ball.reset_to(START_BALL)
	ui.set_tab(1)
	ui.set_kick_values(10.0, 20.0, 20.0, 0.5, 0.3)
	_update_ghosts()
	var g1: Dictionary = ghost_a_log.duplicate(true)
	_on_confirm()
	await a_action_finished
	await planning_started
	out.append("SELFTEST chute: espectro==real %s (ticks=%d)" % [_logs_equal(g1, last_real_log), g1["p"].size() - 1])

	# 2) mover (bola recolocada: a do teste 1 ainda estava voando para o gol)
	ball.reset_to(START_BALL)
	ui.set_tab(0)
	move_target = Vector3(5.0, 0.0, 3.0)
	_update_ghosts()
	var g2: Dictionary = ghost_a_log.duplicate(true)
	_on_confirm()
	await a_action_finished
	await planning_started
	out.append("SELFTEST mover: espectro==real %s (ticks=%d)" % [_logs_equal(g2, last_real_log), g2["p"].size() - 1])

	# 3) chute longe demais não inicia
	ui.set_tab(1)
	_on_confirm()
	out.append("SELFTEST longe demais: continua em PLANNING %s, msg='%s'" % [state == State.PLANNING, ui.msg_label.text])

	# 4) gol
	score_a = 0
	_reset_round()
	pa.reset_to(Vector3(-1.0, 0.0, 0.0))
	ui.set_tab(1)
	ui.set_kick_values(0.0, 30.0, 8.0, 0.0, 0.0)
	_update_ghosts()
	_on_confirm()
	var turns: int = 0
	while score_a == 0 and turns < 60:
		await planning_started
		turns += 1
		if score_a == 0:
			ui.set_tab(0)
			move_target = null
			_on_confirm()
	out.append("SELFTEST gol: placar_a=%d após %d turnos, bola reposta=%s, azul reposto=%s" % [score_a, turns, ball.position == START_BALL, pa.position == START_A])

	for l in out:
		print(l)
	var f: FileAccess = FileAccess.open("user://selftest.txt", FileAccess.WRITE)
	f.store_string("\n".join(out))
	f.close()

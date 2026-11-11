extends Node3D
## Jogador (cápsula). A posição do estado é a position do Node3D.
## Cada ação tem duração em ticks; is_free() fica true quando a ação termina.

enum Act { NONE, IDLE, MOVE, KICK }

@export var speed: float = 6.0
@export var ticks_idle: int = 10
@export var ticks_kick: int = 20
@export var ticks_dodge: int = 20
@export var ticks_advance_retreat: int = 30
@export var ticks_max_move: int = 60

const DT: float = 1.0 / 60.0
const KICK_RANGE: float = 1.5
const FIELD_HX: float = 20.0
const FIELD_HZ: float = 12.0

var act: int = Act.NONE
var ticks_left: int = 0
var ticks_total: int = 0
var target: Vector3 = Vector3.ZERO
var kick: Dictionary = {}


func is_free() -> bool:
	return ticks_left <= 0


func reset_to(pos: Vector3) -> void:
	position = pos
	act = Act.NONE
	ticks_left = 0
	ticks_total = 0
	kick = {}


func copy_from(o: Node3D) -> void:
	speed = o.speed
	ticks_idle = o.ticks_idle
	ticks_kick = o.ticks_kick
	ticks_dodge = o.ticks_dodge
	ticks_advance_retreat = o.ticks_advance_retreat
	ticks_max_move = o.ticks_max_move
	position = o.position
	act = o.act
	ticks_left = o.ticks_left
	ticks_total = o.ticks_total
	target = o.target
	kick = o.kick.duplicate(true)


func start_idle() -> void:
	act = Act.IDLE
	ticks_total = ticks_idle
	ticks_left = ticks_idle


## ticks < 0: duração = distância / velocidade (mín. 1, máx. ticks_max_move).
## Com ticks fixo, o destino é limitado ao que dá para percorrer nesse tempo.
func start_move(dest: Vector3, ticks: int = -1) -> void:
	dest.x = clampf(dest.x, -FIELD_HX, FIELD_HX)
	dest.z = clampf(dest.z, -FIELD_HZ, FIELD_HZ)
	dest.y = 0.0
	var step: float = speed * DT
	var to_dest: Vector3 = dest - position
	to_dest.y = 0.0
	var dist: float = to_dest.length()
	var n: int = ticks
	if n < 0:
		n = clampi(int(dist / step), 1, ticks_max_move)
	var reach: float = minf(dist, step * float(n))
	if dist > 0.0:
		target = position + to_dest / dist * reach
	else:
		target = position
	target.y = 0.0
	act = Act.MOVE
	ticks_total = n
	ticks_left = n


func start_kick(k: Dictionary) -> void:
	kick = k.duplicate(true)
	act = Act.KICK
	ticks_total = ticks_kick
	ticks_left = ticks_kick


func in_kick_range(ball_pos: Vector3) -> bool:
	return position.distance_to(ball_pos) <= KICK_RANGE


func tick(ball: Node3D) -> void:
	if ticks_left <= 0:
		return
	match act:
		Act.MOVE:
			var d: Vector3 = target - position
			var step: float = speed * DT
			if d.length() <= step or ticks_left == 1:
				position = target
			else:
				position += d.normalized() * step
		Act.KICK:
			if ticks_left == ticks_total and in_kick_range(ball.position):
				ball.apply_kick(kick["dir"], kick["force"], kick["elev"], kick["lat"], kick["vert"])
	ticks_left -= 1

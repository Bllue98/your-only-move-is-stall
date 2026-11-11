extends Node3D
## Bola com física própria (sem RigidBody3D). O estado é: position (do Node3D), velocity e spin.
## Tudo determinístico: passo fixo de 1/60 s, sem aleatoriedade.

@export var radius: float = 0.22
@export var gravity: float = 9.8
@export var k_drag: float = 0.1
@export var k_magnus: float = 0.01
@export var spin_scale: float = 20.0
@export var bounce_restitution: float = 0.6
@export var bounce_friction: float = 0.9
@export var rolling_friction: float = 0.985
@export var field_half_length: float = 20.0
@export var field_half_width: float = 12.0
@export var goal_half_width: float = 3.66
@export var goal_height: float = 2.44

const DT: float = 1.0 / 60.0

var velocity: Vector3 = Vector3.ZERO
var spin: Vector3 = Vector3.ZERO


func reset_to(pos: Vector3) -> void:
	position = pos
	velocity = Vector3.ZERO
	spin = Vector3.ZERO


func copy_from(o: Node3D) -> void:
	radius = o.radius
	gravity = o.gravity
	k_drag = o.k_drag
	k_magnus = o.k_magnus
	spin_scale = o.spin_scale
	bounce_restitution = o.bounce_restitution
	bounce_friction = o.bounce_friction
	rolling_friction = o.rolling_friction
	field_half_length = o.field_half_length
	field_half_width = o.field_half_width
	goal_half_width = o.goal_half_width
	goal_height = o.goal_height
	position = o.position
	velocity = o.velocity
	spin = o.spin


## dir: direção horizontal unitária. vert > 0 = topspin, < 0 = backspin.
func apply_kick(dir: Vector3, force: float, elevation_deg: float, lat: float, vert: float) -> void:
	var e: float = deg_to_rad(elevation_deg)
	velocity = dir * (cos(e) * force) + Vector3.UP * (sin(e) * force)
	var side_axis: Vector3 = -dir.cross(Vector3.UP)
	spin = (Vector3.UP * lat + side_axis * vert) * spin_scale


func _in_goal_mouth() -> bool:
	return absf(position.z) < goal_half_width and position.y < goal_height


## 1 = bola cruzou a linha de fundo direita dentro das traves, -1 = esquerda, 0 = nada.
func goal_side() -> int:
	if _in_goal_mouth():
		if position.x > field_half_length:
			return 1
		if position.x < -field_half_length:
			return -1
	return 0


func tick() -> void:
	# Euler semi-implícito: atualiza velocidade e depois posição com a nova velocidade.
	var acc: Vector3 = Vector3(0.0, -gravity, 0.0) - k_drag * velocity + k_magnus * spin.cross(velocity)
	velocity += acc * DT
	position += velocity * DT

	# Quique no chão
	if position.y < radius:
		position.y = radius
		if velocity.y < 0.0:
			if -velocity.y > 0.5:
				velocity.y = -velocity.y * bounce_restitution
				velocity.x *= bounce_friction
				velocity.z *= bounce_friction
			else:
				velocity.y = 0.0

	# Atrito de rolamento em contato com o chão
	if position.y <= radius + 0.0001 and velocity.y <= 0.0:
		velocity.x *= rolling_friction
		velocity.z *= rolling_friction
		spin *= 0.98
		if Vector2(velocity.x, velocity.z).length() < 0.02:
			velocity.x = 0.0
			velocity.z = 0.0

	# Paredes invisíveis (exceto na boca do gol)
	if absf(position.z) > field_half_width:
		position.z = signf(position.z) * field_half_width
		velocity.z = -velocity.z * 0.5
	if absf(position.x) > field_half_length and not _in_goal_mouth():
		position.x = signf(position.x) * field_half_length
		velocity.x = -velocity.x * 0.5

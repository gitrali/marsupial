extends CharacterBody3D

@export var var_look_sensitivity : float = 0.006
@export var var_jump_velocity := 6.0
@export var var_auto_bhop := true


var wish_direction := Vector3.ZERO
var camera_aligned_wish_direction := Vector3.ZERO

var var_noclip_speed_multiplier := 3.0
var var_noclip := false

const HEADBOB_MOVE_AMOUNT = 0.06
const HEADBOB_FREQUENCY = 2.4
var headbob_time := 0.0

# Ground movement setting. omygah.
@export var var_walk_speed := 7.0
@export var var_sprint_speed := 8.5
@export var var_ground_acceleration := 14.0
@export var var_ground_deceleration := 10.0
@export var var_ground_friction := 6.0


# Air movement settings. guh.
@export var var_air_cap := 0.85 # can surf steeper ramps if this is higher, makes it easier to stick and bhop
@export var var_air_acceleration := 800.0
@export var air_move_speed := 500.0

func get_move_speed() -> float:
	return var_sprint_speed if Input.is_action_just_pressed("sprint") else var_walk_speed


func _ready():
	for child in %WorldModel.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)

func _unhandled_input(event):
	
	# if you click on the window - lock the mouse
	# if you press escape - unlock the mouse
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		
		# if the mouse is moving, and is captured, then it moves the camera
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * var_look_sensitivity)
			%Camera3D.rotate_x(-event.relative.y * var_look_sensitivity)
			
			# clamps camera rotation to 90 degrees up and down
			%Camera3D.rotation.x = clamp(%Camera3D.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func clip_velocity(normal: Vector3, overbounce : float, _delta : float) -> void:
	# when strafing into wall, + gravity, velocity will be pointing much in the opposite direction of the normal
	# so with this code , we will back up and off the wall, cancelling out our strafe + gravity, allowing surf.
	var backoff := self.velocity.dot(normal) * overbounce
	if backoff >= 0: return 
	
	var change := normal * backoff
	self.velocity -= change
	
	var adjust := self.velocity.dot(normal)
	if adjust < 0.0:
		self.velocity-= normal * adjust

func is_surface_too_steep(normal : Vector3) -> bool:
	var maximum_slope_angle_dot = Vector3(0,1,0).rotated(Vector3(1.0,0,0), self.floor_max_angle).dot(Vector3(0,1,0))
	if normal.dot(Vector3(0,1,0)) < maximum_slope_angle_dot:
		return true
	return false


func _headbob_effect(_delta):
	headbob_time += _delta * self.velocity.length()
	%Camera3D.transform.origin = Vector3(
		cos(headbob_time * HEADBOB_FREQUENCY* 0.5) * HEADBOB_MOVE_AMOUNT,
		sin(headbob_time * HEADBOB_FREQUENCY) * HEADBOB_MOVE_AMOUNT,
		0
	)


func _process(_delta):
	pass
	
func _handle_noclip(_delta) -> bool:
	if Input.is_action_just_pressed("noclip") and OS.has_feature("debug"):
		noclip = !noclip
	
	$CollisionShape3D.disabled = noclip
	
	if not noclip:
		return false
	
	var speed = get_move_speed() * var_noclip_speed_multiplier
	if Input.is_action_pressed("sprint"):
		speed *= 3.0
	
	self.velocity = camera_aligned_wish_direction * speed#Vector3.ZERO #gmod style where you can fly with noclip
	global_position += self.velocity * _delta
	return true

func _handle_air_physics(_delta) -> void:
	self.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * _delta
	
	# source physics
	var cursor_speed_in_wish_direction = self.velocity.dot(wish_direction)
	# wish speed (if wish_direction > 0 length) capped to var_air_cap
	var capped_speed = min((air_move_speed * wish_direction).length(), var_air_cap)
	# how much to get to the speed the player wishes (in the new direction)
	# Notice this allows for infinite speed. if wish_direction is perpendicular, we always need to add velocity
	# no matter how fast we're going. this is what allows for things like bhop in CSS & Quake.
	# also just happens to give some very nice feeling movement & responsiveness while in the air.
	var add_speed_until_cap = capped_speed - cursor_speed_in_wish_direction
	if add_speed_until_cap > 0:
		var acceleration_speed = var_air_acceleration * air_move_speed * _delta
		acceleration_speed = min(acceleration_speed, add_speed_until_cap)
		self.velocity += acceleration_speed * wish_direction
	
	
	if is_on_wall():
		# the floating mode is much better and less jittery for surf
		if is_surface_too_steep(get_wall_normal()):
			self.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		else:
			self.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
		clip_velocity(get_wall_normal(), 1, _delta) #allows surf


func _handle_ground_physics(_delta) -> void:
	# similar to air movement. Acceleration and friction on ground.
	var cursor_speed_in_wish_direction = self.velocity.dot(wish_direction)
	var add_speed_until_cap = get_move_speed() - cursor_speed_in_wish_direction
	if add_speed_until_cap > if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			self.velocity.y = var_jump_velocity
		_handle_ground_physics(_delta)
		
	else:
		_handle_air_physics(_delta) 0:
		var acceleration_speed = var_ground_acceleration * _delta * get_move_speed()
		acceleration_speed = min(acceleration_speed, add_speed_until_cap)
		self.velocity += acceleration_speed * wish_direction
	
	# apply friction
	var control = max(self.velocity.length(), var_ground_deceleration)
	var drop = control * var_ground_friction * _delta
	var new_speed = max(self.velocity.length() - drop, 0.0)
	if self.velocity.length() > 0:
		new_speed /= self.velocity.length()
	self.velocity *= new_speed
	
	
	_headbob_effect(_delta)


func _physics_process(_delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward").normalized()
	# Depending on which way you have your character facing, you may have to negate the input directions
	wish_direction = self.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)
	camera_aligned_wish_direction = %Camera3D.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)
	
	if not _handle_noclip(delta):
		if is_on_floor():
			if Input.is_action_just_pressed("jump"):
				self.velocity.y = var_jump_velocity
			_handle_ground_physics(_delta)
			
		else:
			_handle_air_physics(_delta)
	
		move_and_slide()

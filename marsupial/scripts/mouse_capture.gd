class_name mouse_capture extends Node3D # this module attaches to it's parent.

# debug toggle
@export var debug: bool = false

# the category for mouse capture settings
@export_category("mouse_capture_settings")
@export var current_mouse_mode : Input.MouseMode = Input.MOUSE_MODE_CAPTURED # sets the mouse input mode
@export var mouse_sensitivity : float = 0.005 # mouse sensitivity, unsure what kindof unit the se are, but it works

# variables used for mouse capture
var _capture_mouse : bool
var _mouse_input : Vector2

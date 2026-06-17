class_name BaseStateMachine
extends Node

@export var initial_state: BaseState
var current_state: BaseState = null
# 所有可用状态
var states: Dictionary[StringName, BaseState] = {}


func _ready() -> void:
	for child in get_children():
		if child is BaseState:
			states[child.name] = child
			child.transition_signal.connect(transition_to)
	# 未在编辑器里指定 initial_state 时，默认用第一个状态子节点
	if initial_state == null and not states.is_empty():
		initial_state = states.values()[0]
	if initial_state:
		initial_state.enter()
		current_state = initial_state


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	if not states.has(state_name):
		return
	if current_state:
		current_state.exit()
	current_state = states[state_name]
	current_state.enter(msg)

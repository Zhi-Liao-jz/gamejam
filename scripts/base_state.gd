class_name BaseState
extends Node

signal transition_signal(new_state_type: int, msg: Dictionary)

@onready var fsm := get_parent() as BaseStateMachine


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func exit() -> void:
	pass


func enter(_msg: Dictionary = {}) -> void:
	pass

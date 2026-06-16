extends Node
class_name BaseState

signal transition_signal(new_state_type:int,msg:Dictionary)

func update(delta:float):
	pass
func physics_update(delta:float):
	pass
func exit():
	pass
func enter(msg:Dictionary={}):
	pass

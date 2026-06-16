extends Node

func _init() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS

func push_event(destination:String,payload=[]) -> void:
	if not payload is Array:
		payload = [payload]
	payload.insert(0,_get_destination_signal(destination))
	callv("emit_signal",payload)

func subscribe(destination:String,callback:Callable) -> void:
	var dest_signal : String = _get_destination_signal(destination)
	if not is_connected(dest_signal,callback):
		connect(dest_signal,callback)
		
func unsubscribe(destination:String,callback:Callable) -> void:
	var dest_signal : String = _get_destination_signal(destination)
	if is_connected(dest_signal,callback):
		disconnect(dest_signal,callback)
	
func _get_destination_signal(destination:String) -> String:
	var dest_signal : String = "EventBus|"+destination
	if not has_user_signal(dest_signal):
		add_user_signal(dest_signal)
	return dest_signal

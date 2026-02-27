extends Node

signal character_interacted

func notify_interacted() -> void:
	character_interacted.emit()

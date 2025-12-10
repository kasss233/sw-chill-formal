extends Control
@onready var vbox=$FoldableContainer/ScrollContainer/VBoxContainer
@onready var folder=$FoldableContainer
signal music_changed(_name:String)
func get_signal():
	for c in vbox.get_children():
		c= c as SingleMusic
		c.music_changed.connect(Callable(self,"change_music"))
		
func change_music(_name:String):
	emit_signal("music_changed",_name)
	folder.title=_name
	
	

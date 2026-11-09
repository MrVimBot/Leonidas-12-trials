extends SceneTree
## CLI: godot --headless --path . --script res://tools/build_sprite_frames.gd
## Construye resources/sprite_frames/*.tres a partir de assets/sprites/strips/*/.

const Builder := preload("res://tools/sprite_frames_builder.gd")


func _init() -> void:
	var saved := Builder.build_all()
	quit(0 if saved.size() > 0 else 1)

class_name SoulDialogue
extends Resource

@export var character_name: String = ""
@export var default_portrait: Texture2D
@export var role_entries: Array[RoleDialogueEntry] = []
@export var default_lines: Array[DialogueLine] = []

func get_lines_for_role(role_id: StringName) -> Array[DialogueLine]:
	for entry in role_entries:
		if entry and entry.role_id == role_id:
			return entry.lines
	return default_lines

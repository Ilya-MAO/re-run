class_name DialogueChoice
extends Resource

@export var choice_text: String = "Так"
@export var choice_id: StringName = &"" # Наприклад: &"agree", &"refuse", &"accuse"
@export var next_lines: Array[DialogueLine] = [] # Гілка реплік, яка піде після цього вибору

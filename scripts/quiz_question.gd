extends Node2D

@export_group("Quiz")
@export_enum("A", "B", "C", "D") var opcion_correcta: String = "A"
@export var bloquear_reintento: bool = true

@export_group("Retorno")
@export var volver_automaticamente: bool = true
@export var espera_retorno_segundos: float = 1.0
@export var escena_retorno_por_defecto: String = "res://scenes/game-first-level.tscn"

@export_group("UI")
@export var mostrar_feedback: bool = true
@export var texto_correcta: String = "Correcto"
@export var texto_incorrecta: String = "Incorrecto"

const LETRAS := ["A", "B", "C", "D"]

var respondida := false
var feedback_label: Label

func _ready() -> void:
	_crear_feedback_label()
	_preparar_respuestas_clickeables()

func _preparar_respuestas_clickeables() -> void:
	for i in range(4):
		var nombre = "response%d" % (i + 1)
		var etiqueta = get_node_or_null("Background/%s" % nombre) as Label
		if not etiqueta:
			continue

		var letra = LETRAS[i]
		if not etiqueta.text.begins_with("%s)" % letra):
			etiqueta.text = "%s) %s" % [letra, etiqueta.text]

		var boton := Button.new()
		boton.text = letra
		boton.flat = true
		boton.focus_mode = Control.FOCUS_NONE
		boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		boton.modulate = Color(1, 1, 1, 0.85)
		boton.position = Vector2.ZERO
		boton.size = etiqueta.size
		boton.pressed.connect(_on_respuesta_presionada.bind(letra))
		etiqueta.add_child(boton)

func _crear_feedback_label() -> void:
	feedback_label = Label.new()
	feedback_label.position = Vector2(20, 20)
	feedback_label.size = Vector2(600, 40)
	feedback_label.z_index = 100
	feedback_label.visible = false
	feedback_label.add_theme_font_size_override("font_size", 26)
	add_child(feedback_label)

func _on_respuesta_presionada(letra: String) -> void:
	if respondida and bloquear_reintento:
		return

	respondida = true
	var es_correcta = letra == opcion_correcta

	if mostrar_feedback and feedback_label:
		feedback_label.visible = true
		feedback_label.text = "%s | Correcta: %s" % [texto_correcta if es_correcta else texto_incorrecta, opcion_correcta]
		feedback_label.modulate = Color(0.5, 1.0, 0.5, 1.0) if es_correcta else Color(1.0, 0.5, 0.5, 1.0)

	if not volver_automaticamente:
		return

	var timer = get_tree().create_timer(max(0.0, espera_retorno_segundos))
	await timer.timeout
	_volver_escena_anterior()

func _volver_escena_anterior() -> void:
	var tree = get_tree()
	var escena_retorno = str(tree.get_meta("quiz_return_scene_path", escena_retorno_por_defecto))
	var cantidad_spawns = int(tree.get_meta("quiz_return_spawn_count", 0))

	if cantidad_spawns > 0:
		tree.set_meta("quiz_return_spawn_index", randi() % cantidad_spawns)

	tree.change_scene_to_file(escena_retorno)

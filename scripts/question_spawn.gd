extends Node2D

@export_group("Detección Elevator -> Plataforma")
@export var activar_por_posicion: bool = true
@export var ruta_elevator: NodePath = NodePath("../../Borders/RigidBody2D")
@export var ruta_plataforma_objetivo: NodePath = NodePath("../../spawner")
@export var margen_horizontal: float = 48.0
@export var margen_vertical: float = 96.0
@export var buscar_plataforma_spawneada_por_grupo: bool = true
@export var grupo_plataforma_spawneada: StringName = &"plataforma_spawneada"
@export var requerir_entrada_a_la_zona: bool = true
@export var usar_2_fases_spawn_y_cambio: bool = true

@export_group("Cambio de Escena")
@export var escena_siguiente: PackedScene
@export var escenas_quiz: Array[PackedScene] = []
@export var cambiar_escena_al_activar: bool = true

@export_group("Spawn Opcional (modo anterior)")
@export var escena_a_spawnear : PackedScene # Si no hay escena_siguiente, se usa este spawn
@export var tiempo_espera: float = 3.0
@export var spawn_automatico: bool = false

# Si esto es true, el objeto aparece en el root de la escena (útil para plataformas móviles)
# Si es false, aparece pegado al spawner (se mueve con él)
@export var spawn_en_root: bool = true 

@export_group("Prefabs de Plataformas")
@export var prefabs_plataformas: Array[PackedScene] = []
@export var puntos_spawn_prefabs: Array[NodePath] = []
@export var generar_prefabs_al_activar: bool = true
@export var separacion_default_x: float = 120.0

@export_group("Retorno Desde Quiz")
@export var aplicar_spawn_retorno_al_cargar: bool = true
@export var ruta_plataforma_retorno: NodePath = NodePath("../../platform")
@export var puntos_spawn_retorno: Array[NodePath] = []

@export_group("Debug Spawn")
@export var debug_logs: bool = true
@export var forzar_z_index_en_spawn: bool = true
@export var z_index_forzado: int = 0
@export var debug_forzar_posicion_prueba: bool = false
@export var posicion_prueba_global: Vector2 = Vector2.ZERO

var reto_activo = false
var cambio_ejecutado = false
var estaba_encima_en_frame_anterior = false
var plataforma_generada = false

var elevator: Node2D
var plataforma_objetivo: Node2D
var timer: Timer

func _ready():
	timer = get_node_or_null("Timer") as Timer

	elevator = get_node_or_null(ruta_elevator) as Node2D
	plataforma_objetivo = get_node_or_null(ruta_plataforma_objetivo) as Node2D
	_intentar_resolver_plataforma_spawneada()

	if activar_por_posicion and (not elevator or not plataforma_objetivo):
		push_warning("No se encontró Elevator o Plataforma objetivo. Revisa 'ruta_elevator' y 'ruta_plataforma_objetivo'.")
	elif debug_logs:
		print("[question_spawn] Elevator: ", elevator.name, " | Plataforma objetivo: ", plataforma_objetivo.name)

	if activar_por_posicion and elevator and plataforma_objetivo:
		estaba_encima_en_frame_anterior = _elevator_esta_encima_de_plataforma()

	if usar_2_fases_spawn_y_cambio and plataforma_objetivo and plataforma_objetivo.is_in_group(grupo_plataforma_spawneada):
		plataforma_generada = true

	_aplicar_spawn_retorno_si_corresponde()

	if timer:
		timer.wait_time = tiempo_espera
		if spawn_automatico and not activar_por_posicion:
			timer.start()
	elif spawn_automatico and not activar_por_posicion:
		push_error("spawn_automatico está activo pero falta el nodo Timer en el spawner.")

func _physics_process(_delta: float) -> void:
	if not activar_por_posicion:
		return

	if cambio_ejecutado:
		return

	# Re-resolvemos siempre para priorizar la plataforma móvil si ya existe.
	_intentar_resolver_plataforma_spawneada()

	if not elevator or not plataforma_objetivo:
		return

	var esta_encima_ahora = _elevator_esta_encima_de_plataforma()
	var cumple_disparo = esta_encima_ahora

	if requerir_entrada_a_la_zona:
		cumple_disparo = esta_encima_ahora and not estaba_encima_en_frame_anterior

	estaba_encima_en_frame_anterior = esta_encima_ahora

	if cumple_disparo:
		if debug_logs:
			print("[question_spawn] Trigger activado. Pos elevator=", elevator.global_position, " | Pos objetivo=", plataforma_objetivo.global_position)

		if usar_2_fases_spawn_y_cambio and generar_prefabs_al_activar and not plataforma_generada:
			spawnear_prefabs_plataformas()
			plataforma_generada = true
			if debug_logs:
				print("[question_spawn] Fase 1 completa: plataforma generada. Esperando que te subas para cambiar de escena.")
			return

		cambio_ejecutado = true

		if generar_prefabs_al_activar and not plataforma_generada:
			spawnear_prefabs_plataformas()
			plataforma_generada = true

		var escena_quiz_destino = _obtener_escena_quiz_destino()
		if escena_quiz_destino and cambiar_escena_al_activar:
			_guardar_contexto_retorno_quiz()
			get_tree().change_scene_to_packed(escena_quiz_destino)
		elif escena_quiz_destino and not cambiar_escena_al_activar and debug_logs:
			print("[question_spawn] escena_siguiente está asignada, pero cambiar_escena_al_activar=false para debug.")
		elif escena_a_spawnear:
			spawn_reto()
		else:
			push_warning("No hay escena_siguiente ni escena_a_spawnear asignada.")

func _intentar_resolver_plataforma_spawneada() -> void:
	if not buscar_plataforma_spawneada_por_grupo:
		return

	var nodos = get_tree().get_nodes_in_group(grupo_plataforma_spawneada)
	for i in range(nodos.size() - 1, -1, -1):
		var nodo = nodos[i]
		if nodo is Node2D:
			plataforma_objetivo = nodo as Node2D
			return

func set_plataforma_objetivo(nueva_plataforma: Node2D) -> void:
	plataforma_objetivo = nueva_plataforma
	if activar_por_posicion and elevator and plataforma_objetivo:
		estaba_encima_en_frame_anterior = _elevator_esta_encima_de_plataforma()

func _elevator_esta_encima_de_plataforma() -> bool:
	var dx = abs(elevator.global_position.x - plataforma_objetivo.global_position.x)
	var dy = elevator.global_position.y - plataforma_objetivo.global_position.y

	# Usamos cercanía vertical para contar contacto real con la plataforma.
	return dx <= margen_horizontal and abs(dy) <= margen_vertical

func _on_timer_timeout():
	if not reto_activo and escena_a_spawnear:
		spawn_reto()

func spawnear_prefabs_plataformas() -> void:
	if prefabs_plataformas.is_empty():
		return

	for i in prefabs_plataformas.size():
		var prefab = prefabs_plataformas[i]
		if not prefab:
			continue

		var instancia = prefab.instantiate()
		if not (instancia is Node2D):
			push_warning("El prefab en índice %d no es Node2D y se omite." % i)
			continue

		var instancia_2d := instancia as Node2D
		var punto_spawn = _obtener_punto_spawn(i)
		_agregar_instancia_en_escena(instancia_2d, punto_spawn)
		instancia_2d.add_to_group(grupo_plataforma_spawneada)
		set_plataforma_objetivo(instancia_2d)

		if debug_logs:
			print("[question_spawn] Prefab spawneado idx=", i, " nombre=", instancia_2d.name, " pos=", instancia_2d.global_position, " z=", instancia_2d.z_index)

func _obtener_punto_spawn(indice: int) -> Vector2:
	if indice < puntos_spawn_prefabs.size():
		var nodo_spawn = get_node_or_null(puntos_spawn_prefabs[indice]) as Node2D
		if nodo_spawn:
			return nodo_spawn.global_position

	return global_position + Vector2(indice * separacion_default_x, 0.0)

func spawn_reto():
	var instancia = escena_a_spawnear.instantiate()
	if not (instancia is Node2D):
		push_warning("escena_a_spawnear debe ser un Node2D para poder posicionarla.")
		return

	var instancia_2d := instancia as Node2D
	
	# Conexión para detectar cuándo se libera el objeto (muerte o resolución)
	instancia_2d.tree_exited.connect(_on_instancia_liberada)
	_agregar_instancia_en_escena(instancia_2d, global_position)
		
	reto_activo = true
	print("Objeto spawneado: ", instancia_2d.name)

func _agregar_instancia_en_escena(instancia: Node2D, posicion_global: Vector2) -> void:
	var posicion_final = posicion_global
	if debug_forzar_posicion_prueba:
		posicion_final = posicion_prueba_global

	instancia.global_position = posicion_final

	if forzar_z_index_en_spawn:
		instancia.z_index = z_index_forzado

	if spawn_en_root:
		get_tree().current_scene.add_child(instancia)
	else:
		add_child(instancia)

	if debug_logs:
		print("[question_spawn] Instancia agregada: ", instancia.name, " en ", instancia.global_position, " z=", instancia.z_index)

func _obtener_escena_quiz_destino() -> PackedScene:
	if escenas_quiz.is_empty():
		return escena_siguiente

	var tree = get_tree()
	var indice = int(tree.get_meta("quiz_scene_index", 0))
	var indice_seguro = posmod(indice, escenas_quiz.size())
	tree.set_meta("quiz_scene_index", indice_seguro + 1)

	var escena = escenas_quiz[indice_seguro]
	if escena:
		return escena

	for alternativa in escenas_quiz:
		if alternativa:
			return alternativa

	return escena_siguiente

func _guardar_contexto_retorno_quiz() -> void:
	var tree = get_tree()
	var escena_actual = ""
	if tree.current_scene:
		escena_actual = tree.current_scene.scene_file_path

	tree.set_meta("quiz_return_scene_path", escena_actual)
	tree.set_meta("quiz_return_spawn_count", puntos_spawn_retorno.size())

func _aplicar_spawn_retorno_si_corresponde() -> void:
	if not aplicar_spawn_retorno_al_cargar:
		return

	var tree = get_tree()
	if not tree.has_meta("quiz_return_scene_path"):
		return

	var retorno_path = str(tree.get_meta("quiz_return_scene_path", ""))
	var escena_actual = ""
	if tree.current_scene:
		escena_actual = tree.current_scene.scene_file_path

	if retorno_path != escena_actual:
		return

	if not tree.has_meta("quiz_return_spawn_index"):
		return

	if puntos_spawn_retorno.is_empty():
		_limpiar_meta_retorno_quiz()
		return

	var indice = int(tree.get_meta("quiz_return_spawn_index", 0))
	var index_seguro = posmod(indice, puntos_spawn_retorno.size())
	var nodo_spawn = get_node_or_null(puntos_spawn_retorno[index_seguro]) as Node2D
	var plataforma_retorno = get_node_or_null(ruta_plataforma_retorno) as Node2D

	if not nodo_spawn or not plataforma_retorno:
		_limpiar_meta_retorno_quiz()
		return

	plataforma_retorno.global_position = nodo_spawn.global_position
	plataforma_retorno.add_to_group(grupo_plataforma_spawneada)
	set_plataforma_objetivo(plataforma_retorno)

	if plataforma_retorno.has_method("actualizar_base_desde_posicion_actual"):
		plataforma_retorno.call("actualizar_base_desde_posicion_actual")

	if debug_logs:
		print("[question_spawn] Retorno quiz aplicado. Spawn idx=", index_seguro, " pos=", plataforma_retorno.global_position)

	_limpiar_meta_retorno_quiz()

func _limpiar_meta_retorno_quiz() -> void:
	var tree = get_tree()
	if tree.has_meta("quiz_return_scene_path"):
		tree.remove_meta("quiz_return_scene_path")
	if tree.has_meta("quiz_return_spawn_count"):
		tree.remove_meta("quiz_return_spawn_count")
	if tree.has_meta("quiz_return_spawn_index"):
		tree.remove_meta("quiz_return_spawn_index")

func _on_instancia_liberada():
	reto_activo = false
	print("Espacio liberado. Spawner listo para el siguiente.")

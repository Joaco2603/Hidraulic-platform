extends Node2D

@export_group("Configuración de Movimiento")
@export var velocidad: float = 200.0
@export var distancia: float = 500.0
@export var mover_padre_en_lugar_de_este_nodo: bool = false
@export var mover_solo_a_la_derecha: bool = false
# Esto permite definir el punto de inicio desde el Inspector 
# si no quieres que sea donde está el objeto al arrancar
@export var usar_posicion_actual_como_base: bool = true
@export var posicion_base_manual: Vector2 = Vector2.ZERO

var posicion_inicial: Vector2
var direccion: int = 1
var objetivo_2d: Node2D # Nodo que efectivamente se mueve

func _ready():
	add_to_group(&"plataforma_spawneada")

	if mover_padre_en_lugar_de_este_nodo:
		objetivo_2d = get_parent() as Node2D
	else:
		objetivo_2d = self

	if not objetivo_2d:
		push_error("Error: No se encontró un Node2D válido para mover.")
		return

	# Definimos la base
	if usar_posicion_actual_como_base:
		posicion_inicial = objetivo_2d.global_position
	else:
		posicion_inicial = posicion_base_manual

func actualizar_base_desde_posicion_actual() -> void:
	if not objetivo_2d:
		return

	posicion_inicial = objetivo_2d.global_position
	direccion = 1

func _physics_process(delta: float):
	if not objetivo_2d:
		return

	if mover_solo_a_la_derecha:
		if objetivo_2d.global_position.x >= posicion_inicial.x + distancia:
			return
		objetivo_2d.position.x += abs(velocidad) * delta
		return

	# Movemos el nodo objetivo
	objetivo_2d.position.x += velocidad * direccion * delta
	
	# Verificamos la distancia respecto a la base inicial
	var distancia_recorrida = abs(objetivo_2d.global_position.x - posicion_inicial.x)
	
	if distancia_recorrida > distancia:
		direccion *= -1

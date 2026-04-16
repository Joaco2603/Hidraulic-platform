extends RigidBody2D

@export var fuerza_empuje = 400
@export var limite_velocidad_muerte = 500 # Si choca a más de esta velocidad, muere
@export var altura_suelo = 600 # Referencia para la energía potencial (Y del suelo)

@export var label_ec : Label
@export var label_ep : Label
@export var label_vel : Label

var esta_presionando = false
var gravedad_valor = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	lock_rotation = true
	# Conectamos la señal de colisión por código para asegurar que funcione
	body_entered.connect(_on_body_entered)



func _physics_process(delta: float) -> void:
	# 1. Lógica de Empuje (Jetpack)
	if esta_presionando:
		linear_velocity.y = -fuerza_empuje
	
	# 2. Seguimiento de Energías
	# Energía Cinética: 1/2 * masa * velocidad^2
	var energia_cinetica = 0.5 * mass * linear_velocity.length_squared()
	
	# Energía Potencial: masa * gravedad * altura
	# En Godot Y crece hacia abajo, por eso restamos la posición del suelo
	var altura_relativa = altura_suelo - global_position.y
	var energia_potencial = mass * gravedad_valor * altura_relativa
	
	# Mostrar en consola (puedes comentar esto si satura mucho)
	print("Ec: %d | Ep: %d | Vel Y: %d" % [energia_cinetica, energia_potencial, linear_velocity.y])

	# --- MOSTRAR EN LOS LABELS ---
	# Usamos str() para convertir números a texto
	# O usamos formatting "%d" para que no salgan mil decimales
	if label_ec:
		label_ec.text = "E. Cinética: %d J" % energia_cinetica
	
	if label_ep:
		label_ep.text = "E. Potencial: %d J" % energia_potencial
		
	if label_vel:
		label_vel.text = "Velocidad Y: %.2f" % linear_velocity.y

# --- DETECCIÓN DE MUERTE ---

func _on_body_entered(body: Node) -> void:
	# Si la velocidad en Y al momento del choque era mayor al límite
	if linear_velocity.y > limite_velocidad_muerte:
		morir()

func morir():
	print("¡HAS MUERTO POR IMPACTO A ALTA VELOCIDAD!")
	# Aquí podrías reiniciar la escena
	# get_tree().reload_current_scene()
	queue_free() # El objeto desaparece

# --- SEÑALES DEL BOTÓN ---

func _on_up_button_down() -> void:
	esta_presionando = true

func _on_up_button_up() -> void:
	esta_presionando = false

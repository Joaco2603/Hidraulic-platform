extends RigidBody2D

@export var fuerza_empuje = 400
@export var limite_velocidad_muerte = 500 # Si choca a más de esta velocidad, muere
@export var altura_suelo = 600 # Referencia para la energía potencial (Y del suelo)
@export var habilitar_derrota_por_caida: bool = true
@export var altura_limite_caida_caja: float = 760.0
@export var ruta_caja: NodePath = NodePath("../../box")

@export var label_ec : Label
@export var label_ep : Label
@export var label_vel : Label
@export var label_fuerza : Label
@export var label_caidas : Label

var esta_presionando = false
var gravedad_valor = ProjectSettings.get_setting("physics/2d/default_gravity")
var caja: RigidBody2D
var contador_caidas: int = 0
var reiniciando: bool = false

const META_CAIDAS := "contador_caidas_box"

func _ready():
	lock_rotation = true
	caja = get_node_or_null(ruta_caja) as RigidBody2D
	contador_caidas = int(get_tree().get_meta(META_CAIDAS, 0))

	# Conectamos la señal de colisión por código para asegurar que funcione
	body_entered.connect(_on_body_entered)



func _physics_process(delta: float) -> void:
	if reiniciando:
		return

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

	if label_fuerza:
		label_fuerza.text = "Fuerza: %.0f N" % fuerza_empuje

	if label_caidas:
		label_caidas.text = "Caidas de caja: %d" % contador_caidas

	if habilitar_derrota_por_caida and caja and caja.global_position.y > altura_limite_caida_caja:
		perder_por_caida_de_caja()

# --- DETECCIÓN DE MUERTE ---

func _on_body_entered(body: Node) -> void:
	# Si la velocidad en Y al momento del choque era mayor al límite
	if linear_velocity.y > limite_velocidad_muerte:
		morir()

func morir():
	reiniciando = true
	print("¡HAS MUERTO POR IMPACTO A ALTA VELOCIDAD!")
	get_tree().reload_current_scene()

func perder_por_caida_de_caja() -> void:
	if reiniciando:
		return

	reiniciando = true
	contador_caidas += 1
	get_tree().set_meta(META_CAIDAS, contador_caidas)
	print("La caja se cayó de la plataforma. Reiniciando nivel...")
	get_tree().reload_current_scene()

# --- SEÑALES DEL BOTÓN ---

func _on_up_button_down() -> void:
	esta_presionando = true

func _on_up_button_up() -> void:
	esta_presionando = false

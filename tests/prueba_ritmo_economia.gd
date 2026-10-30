extends Node
## Contratos del balance más gradual. El piloto mide minutos; esta suite sólo
## impide que al encarecer compras se empeoren la IA o los roles comprados.
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	probar_arranque_y_compras()
	probar_precios_y_roles()
	probar_alimentos_sin_inflacion()
	probar_preparaciones()
	probar_partida_anterior()
	Juego.reiniciar_estado()
	print("Economía gradual: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func probar_arranque_y_compras() -> void:
	verificar(Juego.stat("hormigas_iniciales") == 1 and Juego.stat("duracion_run") == 45, "la colonia empieza con una sola obrera y cuarenta y cinco segundos de expedición")
	verificar(Juego.stat("velocidad") == 95 and Juego.stat("olfato") == 45 and Juego.stat("radio_territorio") == 620, "las hormigas no se vuelven lentas, miopes ni pierden territorio inicial")
	verificar(Juego.stat("dano") == 1 and is_equal_approx(Juego.stat("intervalo_mordida"), 0.95), "la mordida conserva el daño pero deja un intervalo más legible de 0,95 segundos")
	verificar(Juego.stat("vida_silla_inicial") == 280 and Juego.stat("recompensa_silla_inicial") == 420, "la primera silla dura el doble sin aumentar su valor total")
	verificar(is_equal_approx(Juego.stat("resistencia_muebles"), 1.6), "los muebles tienen una resistencia común mayor sin multiplicar sus recompensas")
	verificar(Juego.costo("mas_obreras") == 12 and Juego.mejoras_por_id.mas_obreras.valor == 1, "la segunda obrera mantiene un primer precio alcanzable y cada compra suma una trabajadora")
	Juego.migas = 170
	for id in ["mas_obreras", "mandibulas", "buche", "pisada"]:
		verificar(Juego.comprar(id), "el presupuesto de prueba puede comprar un nivel real de %s" % id)
	verificar(Juego.migas > 0 and Juego.stat("hormigas_iniciales") == 2 and Juego.stat("capacidad") == 2, "las compras hacen crecer de una a dos obreras y amplían su carga")
	verificar(is_equal_approx(Juego.stat("dano"), 2.5), "el daño ganado con las primeras mejoras conserva su efecto")


func probar_precios_y_roles() -> void:
	Juego.reiniciar_estado()
	verificar(Juego.costo("mordida_madera") == 700 and {"id": "mandibulas", "nivel": 3} in Juego.mejoras_por_id.mordida_madera.requisitos, "madera llega cerca del minuto 20–25: 700 migas y Mandíbulas 3")
	verificar(Juego.costo("mordida_resistente") == 550000 and Juego.costo("mordida_muros") == 15000000, "las dietas posteriores acompañan la desaceleración sin agregar monedas")
	verificar(Juego.mejoras_por_id.recoleccion_eficiente.crecimiento > 1.9 and Juego.mejoras_por_id.recoleccion_eficiente.valor == 1.12, "la bola de nieve se frena por precio, conservando la utilidad de cada multiplicador")
	verificar(Juego.costo("patas_largas") == 18 and Juego.costo("antenas") == 25 and Juego.costo("rastro_persistente") == 12, "las ayudas de movimiento y llamado suben moderadamente de precio, no pierden eficacia")
	for id in ["mas_obreras", "mandibulas", "pisada", "buche", "recoleccion_eficiente", "huevos_dorados"]:
		var datos: Dictionary = Juego.mejoras_por_id[id]
		verificar(datos.crecimiento > 1 and datos.nivel_max > 1, "%s conserva su crecimiento incremental y sus topes" % id)
	verificar(Juego.castas_por_id.veloz.velocidad == 2.2 and Juego.castas_por_id.cargadora.capacidad == 4 and Juego.castas_por_id.carpintera.dano == 1.3, "se conserva la identidad y la capacidad de los especialistas")
	verificar(Juego.castas_por_id.veloz.costo_base == 40 and Juego.castas_por_id.cargadora.costo_base == 110 and Juego.castas_por_id.carpintera.costo_base == 500, "no se retrasa además el acceso a los roles que diversifican el primer recorrido")


func probar_preparaciones() -> void:
	Juego.reiniciar_estado()
	Juego.migas_colonia = 25600000.0
	Juego.completar_destino()
	var memoria: Array[String] = ["herencia_madera"]
	var cuadrilla: Array[String] = ["herencia_madera", "obreras_reales", "jalea_dano"]
	var solo_memoria := Juego.cotizar_preparacion_fundar(memoria)
	var grupo := Juego.cotizar_preparacion_fundar(cuadrilla)
	verificar(Juego.jalea_por_fundar() == 7 and solo_memoria.valido and solo_memoria.costo == 3, "Memoria conserva el atajo de tres jaleas con una primera fundación de siete")
	verificar(grupo.valido and grupo.costo == 6 and grupo.saldo == 1, "Cuadrilla sigue costando seis y no exige llegar al siguiente destino")
	verificar(Juego.fundar_colonia("numerosa", cuadrilla) and Juego.stat("materiales") == 1 and Juego.jalea == 1, "el balance nuevo no obliga a repetir el ahorro de madera tras elegir la preparación")
	verificar(Juego.stat("hormigas_iniciales") == 7.5 and Juego.stat("dano") > Juego.stats_base.dano, "la cuadrilla con Numerosa ofrece siete obreras reales frente a la única del arranque")


func probar_alimentos_sin_inflacion() -> void:
	var alimentos: Dictionary = {}
	for comida in Juego.comidas:
		alimentos[comida.id] = comida
	verificar(alimentos.miga.vida == 3 and alimentos.miga.recompensa == 2, "las migas iniciales siguen siendo pequeñas y conservan el ingreso de arranque")
	verificar(alimentos.galletita.vida == 84 and alimentos.galletita.recompensa == 60, "la galletita dura más pero no entrega más moneda que antes")
	verificar(alimentos.sandwich.vida == 900 and alimentos.sandwich.recompensa == 900 and alimentos.torta.vida == 4500 and alimentos.torta.recompensa == 5000, "los alimentos grandes ganan resistencia sin inflar su recompensa")
	verificar(alimentos.miga.cantidad == 138 and alimentos.galletita.cantidad == 78 and alimentos.pizza.cantidad == 24, "no se agregan alimentos ni instancias para frenar o compensar la progresión")


func probar_partida_anterior() -> void:
	Juego.reiniciar_estado()
	var niveles_previos := {"mas_obreras": 8, "mandibulas": 14, "pisada": 7, "buche": 5, "mordida_madera": 1}
	Juego.restaurar_partida({"version": 7, "migas": 12345, "runs_jugadas": 12, "niveles": niveles_previos,
		"reclutadas": {"carpintera": 1, "veloz": 2}, "jalea": 4, "legado": 7,
		"niveles_jalea": {"herencia_madera": 1}, "fundaciones": 1})
	verificar(Juego.migas == 12345 and Juego.jalea == 4 and Juego.legado == 7, "cargar el nuevo costo no cobra diferencias ni cambia los saldos existentes")
	verificar(Juego.niveles == niveles_previos and Juego.cantidad_casta("carpintera") == 1 and Juego.cantidad_casta("veloz") == 2, "niveles y especialistas anteriores se conservan sin recomprar")
	verificar(Juego.stat("hormigas_iniciales") == 9, "una partida previa conserva sus ocho niveles y los evalúa con la nueva base y una obrera por nivel")
	verificar(Juego.nivel_jalea("herencia_madera") == 1 and Juego.stat("materiales") == 1, "una memoria anterior sigue evitando el nuevo ahorro de dieta")


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)

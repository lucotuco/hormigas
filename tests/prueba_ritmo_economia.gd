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
	probar_preparaciones()
	probar_partida_anterior()
	Juego.reiniciar_estado()
	print("Economía gradual: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func probar_arranque_y_compras() -> void:
	verificar(Juego.stat("hormigas_iniciales") == 8 and Juego.stat("duracion_run") == 45, "la colonia conserva sus ocho obreras y la expedición inicial de cuarenta y cinco segundos")
	verificar(Juego.stat("velocidad") == 95 and Juego.stat("olfato") == 45 and Juego.stat("radio_territorio") == 620, "las hormigas no se vuelven lentas, miopes ni pierden territorio inicial")
	verificar(Juego.stat("dano") == 1 and is_equal_approx(Juego.stat("intervalo_mordida"), 0.6), "el contacto y la mordida inicial no se debilitan para alargar la campaña")
	verificar(Juego.stat("vida_silla_inicial") == 140 and Juego.stat("recompensa_silla_inicial") == 420, "la primera silla conserva la demostración accesible y la recompensa proporcional")
	Juego.migas = 170
	for id in ["mas_obreras", "mandibulas", "buche", "pisada"]:
		verificar(Juego.comprar(id), "una primera recaudación puede comprar un nivel real de %s" % id)
	verificar(Juego.migas > 0 and Juego.stat("hormigas_iniciales") == 10 and Juego.stat("capacidad") == 2, "el costo gradual sigue permitiendo decisiones útiles tras una expedición")
	verificar(is_equal_approx(Juego.stat("dano"), 2.5), "los niveles pagados mantienen el mismo efecto, no se nerfea la compra además de encarecerla")


func probar_precios_y_roles() -> void:
	Juego.reiniciar_estado()
	verificar(Juego.costo("mordida_madera") > 900 and Juego.costo("mordida_madera") <= 1800, "madera exige un ahorro inicial mayor sin volver al umbral anterior de tres mil")
	verificar(Juego.costo("mordida_resistente") > 150000 and Juego.costo("mordida_muros") > 4000000, "las dietas siguientes extienden el crecimiento sin cambiar la resistencia de los objetos")
	verificar(Juego.mejoras_por_id.recoleccion_eficiente.crecimiento > 1.9 and Juego.mejoras_por_id.recoleccion_eficiente.valor == 1.15, "la bola de nieve se frena por precio, conservando la utilidad de cada multiplicador")
	verificar(Juego.costo("patas_largas") == 15 and Juego.costo("antenas") == 20 and Juego.costo("rastro_persistente") == 10, "velocidad, olfato y respuesta al llamado siguen accesibles a sus precios anteriores")
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
	verificar(Juego.stat("hormigas_iniciales") == 18 and Juego.stat("dano") > Juego.stats_base.dano, "la primera colonia renovada sigue naciendo más capaz")


func probar_partida_anterior() -> void:
	Juego.reiniciar_estado()
	var niveles_previos := {"mas_obreras": 8, "mandibulas": 14, "pisada": 7, "buche": 5, "mordida_madera": 1}
	Juego.restaurar_partida({"version": 7, "migas": 12345, "runs_jugadas": 12, "niveles": niveles_previos,
		"reclutadas": {"carpintera": 1, "veloz": 2}, "jalea": 4, "legado": 7,
		"niveles_jalea": {"herencia_madera": 1}, "fundaciones": 1})
	verificar(Juego.migas == 12345 and Juego.jalea == 4 and Juego.legado == 7, "cargar el nuevo costo no cobra diferencias ni cambia los saldos existentes")
	verificar(Juego.niveles == niveles_previos and Juego.cantidad_casta("carpintera") == 1 and Juego.cantidad_casta("veloz") == 2, "niveles y especialistas anteriores se conservan sin recomprar")
	verificar(Juego.nivel_jalea("herencia_madera") == 1 and Juego.stat("materiales") == 1, "una memoria anterior sigue evitando el nuevo ahorro de dieta")


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)

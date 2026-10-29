extends Node
## Dos cinturones: trabajo real cerca y contexto estático lejos, con rutas A*.
class MesaPrueba extends Node2D:
	var cocina: Cocina

class ComidasObservadas extends Comidas:
	var anteriores: Dictionary = {}

	func _registrar_cambio(_comida: Comida) -> void:
		pass # El reloj de Run no participa de esta prueba de plano y reparto.

	func _repartir_periferia() -> void:
		anteriores.clear()
		for comida in lista:
			anteriores[comida.get_instance_id()] = {"pos": comida.position, "id": comida.id, "valor": comida.recompensa}
		super._repartir_periferia()

var total := 0
var fallas := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	var claves_anteriores: Dictionary = {}
	for m in PlanoCasa.MUEBLES + Mundos.ESPECIALES:
		claves_anteriores[Graficos.clave_mueble(m)] = true
	# Las variantes históricas de destinos también cuentan; la periferia sólo
	# utiliza los mismos tipos/acabados que el catálogo ya conocía.
	for id in Mundos.ORDEN:
		for m in Mundos.plano(id).muebles_interiores:
			claves_anteriores[Graficos.clave_mueble(m)] = true
	verificar(Mundos.VERSION_CONTENIDO == 3, "la ampliación separa los récords anteriores por versión")
	for id in Mundos.ORDEN:
		Juego.reiniciar_estado()
		Juego.lugar_actual = id
		var plano := Mundos.plano(id)
		var juego: Rect2 = PlanoCasa.limites()
		var visual: Rect2 = PlanoCasa.limites_visuales()
		verificar(juego.encloses(PlanoCasa.LIMITES) and visual.encloses(juego), id + ": interior, expansión y contexto tienen límites separados")
		verificar(juego.size.x <= PlanoCasa.LIMITES.size.x * 1.32 and juego.size.y <= PlanoCasa.LIMITES.size.y * 1.33, id + ": la navegación crece de forma moderada, no con el fondo panorámico")
		var claves_ok := true
		var exteriores := 0
		for m in plano.muebles:
			claves_ok = claves_ok and claves_anteriores.has(Graficos.clave_mueble(m))
			if not PlanoCasa.LIMITES.encloses(m.rect):
				exteriores += 1
		verificar(exteriores == 8 and claves_ok, id + ": ocho objetos periféricos auténticos reutilizan el atlas")
		var mesa := MesaPrueba.new()
		add_child(mesa)
		mesa.cocina = Cocina.new()
		mesa.add_child(mesa.cocina)
		var comidas := ComidasObservadas.new()
		mesa.add_child(comidas)
		comidas.generar()
		var anteriores := _generar_plano_anterior(plano, id)
		var azar_igual := anteriores.size() == comidas.lista.size()
		for i in mini(anteriores.size(), comidas.lista.size()):
			var comida := comidas.lista[i]
			var pos: Vector2 = comida.position if comida.id == "banquete" else comidas.anteriores[comida.get_instance_id()].pos
			azar_igual = azar_igual and anteriores[i].id == comida.id and anteriores[i].pos == pos
		verificar(azar_igual, id + ": la distribución previa coincide exactamente con el plano sin ampliar")
		var movidas := 0
		var arranque_igual := true
		var recursos_ok := true
		var valor := 0.0
		var valor_antes := 0.0
		var rutas_ok := true
		for comida in comidas.lista:
			if comida.id == "banquete":
				continue
			var antes: Dictionary = comidas.anteriores[comida.get_instance_id()]
			valor += comida.recompensa
			valor_antes += antes.valor
			if antes.pos.length() <= 900:
				arranque_igual = arranque_igual and antes.pos == comida.position
			if comida.get_meta("periferia", false):
				movidas += 1
				recursos_ok = recursos_ok and juego.grow(-50 - comida.radio).has_point(comida.position) and not PlanoCasa.LIMITES.has_point(comida.position)
				var ruta := mesa.cocina.ruta(Vector2.ZERO, comida.position, 12000)
				var anterior := Vector2.ZERO
				var segura := not ruta.is_empty()
				for paso in ruta:
					segura = segura and mesa.cocina.segmento_libre(anterior, paso)
					anterior = paso
				segura = segura and anterior.distance_to(comida.position) < 1
				if not segura:
					print("SIN RUTA PERIFERIA ", id, " ", comida.id, " ", comida.position)
				rutas_ok = rutas_ok and segura
		verificar(arranque_igual and comidas.anteriores.size() == comidas.lista.size() - 1 and is_equal_approx(valor, valor_antes), id + ": el reparto no agrega comida ni valor ni mueve el arranque")
		verificar(movidas >= 4 and movidas <= 6 and movidas <= floori(comidas.anteriores.size() * 0.05) and recursos_ok, id + ": los bocados trasladados quedan completamente dentro del nuevo terreno")
		verificar(rutas_ok, id + ": se llega desde el nido sin atravesar muebles ni aprender paredes")
		var fuera := visual.position + Vector2(100, 100)
		verificar(not mesa.cocina.libre(fuera) and mesa.cocina._suelo.region.size.x < 330 and mesa.cocina._suelo.region.size.y < 240, id + ": el contexto lejano no entra en el grafo ni se vuelve jugable")
		var determinista := []
		for comida in comidas.lista:
			if comida.get_meta("periferia", false):
				determinista.append([comida.id, comida.position])
		comidas.generar()
		var segunda := []
		for comida in comidas.lista:
			if comida.get_meta("periferia", false):
				segunda.append([comida.id, comida.position])
		verificar(determinista == segunda, id + ": el reparto exterior se repite con la misma semilla")
		mesa.queue_free()
		await get_tree().process_frame
	var casa := Mundos.plano("casa")
	verificar(casa.meta == "mueble:10" and casa.muebles[6].get("perfil", "") == "silla_inicial" and casa.muebles.back().get("practica", false), "la ampliación conserva mesa, primera silla y cartón al final")
	var proporcion_ok := true
	var proporciones := {"columna": 1.0, "anfora": 360.0 / 420.0, "cartel": 260.0 / 300.0}
	for id in Mundos.ORDEN:
		for m in Mundos.plano(id).muebles:
			if not PlanoCasa.LIMITES.encloses(m.rect) and proporciones.has(m.tipo):
				var relacion: float = m.rect.size.x / m.rect.size.y / proporciones[m.tipo]
				proporcion_ok = proporcion_ok and relacion >= 0.67 and relacion <= 1.49
	verificar(proporcion_ok, "columnas, ánforas y carteles periféricos conservan proporciones reconocibles")
	var banco_fuera_calle := true
	for m in Mundos.plano("obelisco").muebles:
		if m.tipo == "banco" and not PlanoCasa.LIMITES.encloses(m.rect):
			banco_fuera_calle = banco_fuera_calle and not m.rect.intersects(Rect2(-4800, 2750, 15600, 320))
	verificar(banco_fuera_calle, "los bancos nuevos de la avenida no ocupan el carril de circulación")
	Juego.reiniciar_estado()
	print("Periferia: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)

func _generar_plano_anterior(plano: Dictionary, id: String) -> Array:
	# Reconstrucción de la geometría previa, no sólo una segunda lectura del
	# escenario nuevo. Prueba que las puertas no consumen otro flujo aleatorio.
	var anterior: Dictionary = plano.duplicate(true)
	anterior.limites = PlanoCasa.LIMITES
	anterior.muebles = plano.muebles_interiores
	anterior.bocados_exteriores = []
	if id == "casa":
		anterior.paredes = PlanoCasa.PAREDES
	else:
		anterior.paredes = [Rect2(-950, -1000, 7900, 50), Rect2(-950, -1000, 50, 5600), Rect2(6900, -1000, 50, 5600), Rect2(-950, 4550, 7900, 50)]
		if id in ["restaurante", "museo"]:
			for i in range(4, plano.paredes.size() - 4):
				anterior.paredes.append(plano.paredes[i])
	Mundos._cache[id] = anterior
	var mesa := MesaPrueba.new()
	add_child(mesa)
	mesa.cocina = Cocina.new()
	mesa.add_child(mesa.cocina)
	var comidas := ComidasObservadas.new()
	mesa.add_child(comidas)
	comidas.generar()
	var resultado := []
	for comida in comidas.lista:
		resultado.append({"id": comida.id, "pos": comida.position})
	Mundos._cache[id] = plano
	mesa.free()
	return resultado

func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", detalle)

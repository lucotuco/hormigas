extends Node
## Identidad visual sin alterar geometría, navegación ni recompensas.
var total := 0
var fallas := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Juego.reiniciar_estado()
	var claves: Dictionary = {}
	for m in PlanoCasa.MUEBLES + Mundos.ESPECIALES:
		claves[Graficos.clave_mueble(m)] = true
	for id in Mundos.ORDEN:
		var faltantes := 0
		for m in Mundos.plano(id).muebles:
			if not claves.has(Graficos.clave_mueble(m)):
				faltantes += 1
		verificar(faltantes == 0, "%s: todos los acabados y orientaciones tienen arte compartido" % id)
	verificar(claves.size() < PlanoCasa.MUEBLES.size() + Mundos.ESPECIALES.size(), "el atlas elimina instancias duplicadas")
	var verde: Dictionary = PlanoCasa.MUEBLES[6].duplicate()
	var marron: Dictionary = verde.duplicate()
	marron.color = Color("af8862")
	verificar(Graficos.clave_mueble(verde) != Graficos.clave_mueble(marron), "sillas de distinto color ya no comparten un acabado incorrecto")
	var copia: Dictionary = verde.duplicate()
	copia.rect = Rect2(1500, 900, 200, 200)
	verificar(Graficos.clave_mueble(verde) == Graficos.clave_mueble(copia), "la posición no duplica el atlas")
	var bancos := 0
	for m in Mundos.plano("obelisco").muebles:
		if m.tipo == "banco":
			bancos += 1
			var banco := MaterialesCasa.definir("banco", m.rect, m.color)
			var anterior := MaterialesCasa.definir("consola", m.rect, m.color)
			verificar(banco.nivel == anterior.nivel and banco.vida == anterior.vida and banco.recompensa == anterior.recompensa, "el banco conserva material, resistencia y recompensa")
	verificar(bancos == 4, "la plaza tiene cuatro bancos en los mismos lugares")
	verificar(Mundos.plano("eiffel").ambientes[0].patron == 4, "los jardines usan césped, no baldosas de baño")
	verificar(Mundos.plano("coliseo").ambientes[1].patron == 3, "la arena no tiene juntas de cerámica")
	var tutorial: Dictionary = Mundos.plano("casa").muebles.back()
	verificar(tutorial.practica and tutorial.acabado == "carton", "el banquito inicial se reconoce como cartón")
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	var fuera := 0
	for comida in run.comidas.lista:
		if comida.id == "banquete":
			continue # el plato caído tiene ubicación narrativa fija
		for datos in Juego.comidas:
			if datos.id == comida.id and datos.get("zonas", "") != "":
				if not String(datos.zonas).split("|").has(PlanoCasa.ambiente_en(comida.position)):
					fuera += 1
	verificar(fuera == 0, "la comida agrupada junto a muebles respeta el ambiente previsto")
	run.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	print("Estética y atlas: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)

func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)

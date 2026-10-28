class_name PanelEstadisticas
extends VentanaModal
## Estadísticas de toda la partida, agrupadas. Los números salen de
## Juego.estadisticas (no se reinician al fundar) y del estado de la partida.

var _valores: Dictionary = {}


func _ready() -> void:
	titulo(tr("Estadísticas"))
	ancho(760)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contenido.add_child(scroll)
	var columna := VBoxContainer.new()
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.add_theme_constant_override("separation", 14)
	scroll.add_child(columna)
	for grupo in grupos():
		columna.add_child(Estilo.etiqueta(grupo.titulo, 12, Color("c9b779")))
		var grilla := GridContainer.new()
		grilla.columns = 3
		grilla.add_theme_constant_override("h_separation", 10)
		grilla.add_theme_constant_override("v_separation", 10)
		columna.add_child(grilla)
		for fila in grupo.filas:
			grilla.add_child(_tarjeta(fila[0], fila[1], fila[2]))


## Los grupos con sus filas: [id, nombre, valor ya formateado].
func grupos() -> Array[Dictionary]:
	var destinos := 0
	for id in Mundos.ORDEN:
		if Juego.lugares_completados.has(id):
			destinos += 1
	var lista: Array[Dictionary] = [
		{"titulo": tr("LA COLONIA"), "filas": [
			["migas_totales", tr("Migas juntadas"), Juego.formatear(Juego.estadistica("migas_totales"))],
			["migas_gastadas", tr("Migas invertidas"), Juego.formatear(Juego.estadistica("migas_gastadas"))],
			["mejor_run", tr("Mejor expedición"), Juego.formatear(Juego.mejor_run)],
			["hormigas_nacidas", tr("Hormigas nacidas"), Juego.formatear(Juego.estadistica("hormigas_nacidas"))],
			["mayor_colonia", tr("Colonia más grande"), Juego.formatear(Juego.estadistica("mayor_colonia"))],
			["niveles_comprados", tr("Niveles de mejoras"), Juego.formatear(Juego.estadistica("niveles_comprados"))],
			["castas_reclutadas", tr("Especialistas reclutadas"), Juego.formatear(Juego.estadistica("castas_reclutadas"))],
		]},
		{"titulo": tr("EXPEDICIONES"), "filas": [
			["runs", tr("Expediciones"), Juego.formatear(Juego.runs_jugadas)],
			["tiempo_en_runs", tr("Tiempo de expedición"), duracion(Juego.estadistica("tiempo_en_runs"))],
			["tiempo_total", tr("Tiempo de juego"), duracion(Juego.estadistica("tiempo_total"))],
			["mejor_combo", tr("Mejor combo"), "x%d" % int(Juego.estadistica("mejor_combo"))],
			["pisotones", tr("Pisotones"), Juego.formatear(Juego.estadistica("pisotones"))],
		]},
		{"titulo": tr("DESTRUCCIÓN"), "filas": [
			["comidas_devoradas", tr("Comidas devoradas"), Juego.formatear(Juego.estadistica("comidas_devoradas"))],
			["partes_devoradas", tr("Muebles y muros devorados"), Juego.formatear(Juego.estadistica("partes_devoradas"))],
			["derrumbes", tr("Derrumbes"), Juego.formatear(Juego.estadistica("derrumbes"))],
			["objetivos_conquistados", tr("Grandes objetivos devorados"), Juego.formatear(Juego.estadistica("objetivos_conquistados"))],
			["destinos", tr("Destinos conquistados"), "%d / %d" % [destinos, Mundos.ORDEN.size()]],
		]},
		{"titulo": tr("LA REINA"), "filas": [
			["fundaciones", tr("Colonias fundadas"), Juego.formatear(Juego.fundaciones)],
			["coronas_ganadas", tr("Coronas ganadas"), Juego.formatear(Juego.estadistica("coronas_ganadas"))],
			["legado", tr("Jalea real ganada"), Juego.formatear(Juego.legado)],
			["jalea_gastada", tr("Jalea real invertida"), Juego.formatear(Juego.estadistica("jalea_gastada"))],
			["hitos", tr("Hitos"), "%d / %d" % [Juego.hitos.size(), Juego.HITOS.size()]],
		]},
	]
	return lista


func _tarjeta(id: String, nombre: String, valor: String) -> Control:
	var caja := PanelContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.custom_minimum_size.x = 220
	caja.add_theme_stylebox_override("panel", Estilo.caja(Color("242c25"), 12, Color("3b4639"), 1, 12))
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 2)
	caja.add_child(columna)
	columna.add_child(Estilo.etiqueta(nombre, 12, Estilo.TEXTO_SUAVE))
	var etiqueta := Estilo.etiqueta(valor, 22, Estilo.ACENTO)
	columna.add_child(etiqueta)
	_valores[id] = etiqueta
	return caja


## 3725 s -> "1 h 02 min"; 95 s -> "1 min 35 s".
static func duracion(segundos: float) -> String:
	var s := int(segundos)
	if s >= 3600:
		return "%d h %02d min" % [s / 3600, (s % 3600) / 60]
	if s >= 60:
		return "%d min %02d s" % [s / 60, s % 60]
	return "%d s" % s

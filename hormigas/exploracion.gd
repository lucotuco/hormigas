class_name ExploracionHormigas
extends RefCounted
## Reparte destinos, no fuerzas entre pares de hormigas. Sólo se consulta al
## terminar un recorrido o quedarse sin trabajo; no hay escaneos N² por cuadro.
const TAMANO_SECTOR := 320.0
const CANDIDATOS := 12
var _reservas: Dictionary = {} # instancia -> sector de destino
var _ocupacion: Dictionary = {} # sector -> exploradoras en camino
var _visitas: Dictionary = {} # sector -> visitas, acotado por el plano

func liberar(instancia: int) -> void:
	if not _reservas.has(instancia):
		return
	var sector: Vector2i = _reservas[instancia]
	var restantes := int(_ocupacion.get(sector, 1)) - 1
	if restantes <= 0:
		_ocupacion.erase(sector)
	else:
		_ocupacion[sector] = restantes
	_reservas.erase(instancia)

func visitar(pos: Vector2) -> void:
	var sector := Vector2i((pos / TAMANO_SECTOR).floor())
	_visitas[sector] = mini(8, int(_visitas.get(sector, 0)) + 1)

func elegir(instancia: int, pos: Vector2, territorio: float, casa: Cocina, volando: bool) -> Vector2:
	liberar(instancia)
	var paso := minf(900, maxf(180, territorio * 0.45))
	var limites := PlanoCasa.limites().grow(-Cocina.MARGEN - 2)
	var mejor := Vector2.INF
	var puntaje := INF
	for i in CANDIDATOS:
		var candidato := (pos + Vector2.from_angle(randf() * TAU) * randf_range(paso * 0.65, paso * 1.15)).limit_length(territorio - 12)
		if not limites.has_point(candidato) or candidato.distance_squared_to(pos) < 80 * 80:
			continue
		var sector := Vector2i((candidato / TAMANO_SECTOR).floor())
		var costo := int(_ocupacion.get(sector, 0)) * 3.0 + int(_visitas.get(sector, 0)) - candidato.distance_to(pos) / paso
		# La consulta geométrica sólo vale la pena si mejora la mejor opción.
		if costo < puntaje and casa.libre(candidato, Cocina.MARGEN, volando):
			mejor = candidato
			puntaje = costo
	# En un rincón o una habitación pequeña se conserva una salida local.
	if mejor == Vector2.INF:
		for i in CANDIDATOS:
			var candidato := (pos + Vector2.from_angle(randf() * TAU) * randf_range(35, 110)).limit_length(territorio - 12)
			if limites.has_point(candidato) and casa.libre(candidato, Cocina.MARGEN, volando):
				mejor = candidato
				break
	if mejor != Vector2.INF:
		var sector := Vector2i((mejor / TAMANO_SECTOR).floor())
		_reservas[instancia] = sector
		_ocupacion[sector] = int(_ocupacion.get(sector, 0)) + 1
	return mejor

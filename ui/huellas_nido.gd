class_name HuellasNido
extends RefCounted
## Recuerdos dibujados, no otra progresión. Sólo lee los premios que Juego ya
## conserva. No altera cámaras, requisitos, economía ni rutas de las hormigas.
## Las cinco ampliaciones usan el espacio libre junto al conducto central.
const CONJUNTOS := {
	"restaurante": {"rect": Rect2(480, 168, 230, 112), "kit": "recoleccion", "conexion": Vector2(850, 202)},
	"museo": {"rect": Rect2(970, 168, 250, 112), "kit": "tiempo", "conexion": Vector2(850, 238)},
	"obelisco": {"rect": Rect2(525, 320, 215, 96), "kit": "colonia", "conexion": Vector2(850, 380)},
	"coliseo": {"rect": Rect2(960, 385, 160, 98), "kit": "territorio", "conexion": Vector2(855, 450)},
	"eiffel": {"rect": Rect2(625, 490, 160, 104), "kit": "mandibulas", "conexion": Vector2(860, 565)},
}
const DESCUBRIMIENTOS := {
	"madera": {"hito": "primera_silla", "camara": "mandibulas", "rect": Rect2(746, 1106, 48, 42)},
	"despensa": {"hito": "primer_tesoro", "camara": "buche", "rect": Rect2(584, 1051, 48, 38)},
	"soportes": {"hito": "primer_derrumbe", "camara": "excavar", "rect": Rect2(1050, 1093, 60, 40)},
}
const SALIDA := [Vector2(560, 32), Vector2(560, 78), Vector2(620, 100), Vector2(704, 112)]


## Se consulta al entrar y cuando cambia el progreso, nunca por cuadro ni al
## cambiar el saldo. El orden de las cuatro piezas viene del catálogo actual.
static func capturar() -> Dictionary:
	var completos: Array[String] = []
	for proyecto in ProyectosCampana.todos():
		if Juego.proyecto_completo(proyecto.id):
			completos.append(proyecto.id)
	return desde_progreso(Juego.hitos, Juego.lugares_completados, completos, Juego.estadistica("migas_totales"))


static func desde_progreso(hitos: Dictionary, destinos: Dictionary, proyectos: Array[String], migas_totales := 0.0) -> Dictionary:
	var hallazgos: Array[String] = []
	if migas_totales > 0.0:
		hallazgos.append("provisiones")
	for id in DESCUBRIMIENTOS:
		if hitos.get(DESCUBRIMIENTOS[id].hito, false) == true:
			hallazgos.append(id)
	if destinos.get("casa", false) == true:
		hallazgos.append("salida")
	var conjuntos := {}
	for destino in CONJUNTOS:
		var partes: Array[int] = []
		var catalogo := ProyectosCampana.del_destino(destino)
		for i in mini(4, catalogo.size()):
			if catalogo[i].id in proyectos:
				partes.append(i)
		if not partes.is_empty():
			conjuntos[destino] = partes
	return {"descubrimientos": hallazgos, "conjuntos": conjuntos}


## El encuadre incluye lo que realmente existe, no veinte huecos vacíos que
## funcionen como una lista de tareas. Los anexos no son cámaras comprables.
static func regiones(estado: Dictionary) -> Array[Rect2]:
	var salida: Array[Rect2] = []
	for destino in estado.get("conjuntos", {}):
		if CONJUNTOS.has(destino):
			salida.append(CONJUNTOS[destino].rect)
	for id in estado.get("descubrimientos", []):
		if DESCUBRIMIENTOS.has(id):
			salida.append(DESCUBRIMIENTOS[id].rect)
		elif id == "salida":
			salida.append(Rect2(520, 15, 80, 68))
	return salida


static func dibujar(ci: CanvasItem, estado: Dictionary) -> void:
	for destino in estado.get("conjuntos", {}):
		if not CONJUNTOS.has(destino):
			continue
		var datos: Dictionary = CONJUNTOS[destino]
		var r: Rect2 = datos.rect
		var desde: Vector2 = datos.conexion
		var borde := Vector2(r.end.x if r.get_center().x < desde.x else r.position.x, r.get_center().y)
		_conectar(ci, PackedVector2Array([desde, Vector2(desde.x, borde.y), borde]), 12.0)
		ArteCamara.caparazon(ci, datos.kit, r.get_center(), r.size, ArteCamara.BORDE, 5.0, 0.1)
		ArteCamara.recuerdo(ci, destino, r, estado.conjuntos[destino])
	for id in estado.get("descubrimientos", []):
		if id == "salida":
			_conectar(ci, PackedVector2Array(SALIDA), 14.0)
			# Una segunda boca real, no una bandera ni un indicador rojo.
			ci.draw_colored_polygon(PackedVector2Array([Vector2(520, 37), Vector2(540, 22), Vector2(578, 22), Vector2(600, 37)]), Color("62452d"))
			ci.draw_polyline(PackedVector2Array([Vector2(520, 37), Vector2(540, 22), Vector2(578, 22), Vector2(600, 37)]), Color("967448"), 2.5, true)
			ci.draw_line(Vector2(547, 35), Vector2(572, 35), ArteCamara.SOMBRA, 6.0, true)
		elif DESCUBRIMIENTOS.has(id):
			var datos: Dictionary = DESCUBRIMIENTOS[id]
			var r: Rect2 = datos.rect
			_conectar(ci, PackedVector2Array([r.get_center(), PlanoHormiguero.rect(datos.camara).get_center()]), 7.0)
			ArteCamara.caparazon(ci, "comun", r.get_center(), r.size, ArteCamara.BORDE, 3.0, 0.0)
			ArteCamara.descubrimiento(ci, id, r)


static func _conectar(ci: CanvasItem, puntos: PackedVector2Array, ancho: float) -> void:
	var linea := puntos
	# Curvas cortas y orgánicas, no caños en ángulo recto. Se generan sólo
	# cuando se redibuja esta capa estática, nunca durante el tránsito.
	if puntos.size() in [3, 4]:
		linea = PackedVector2Array()
		for i in 17:
			var t := i / 16.0
			if puntos.size() == 4:
				linea.append(puntos[0].bezier_interpolate(puntos[1], puntos[2], puntos[3], t))
			else:
				linea.append(puntos[0].lerp(puntos[1], t).lerp(puntos[1].lerp(puntos[2], t), t))
	ci.draw_polyline(linea, ArteCamara.SOMBRA, ancho + 6.0, true)
	ci.draw_polyline(linea, ArteCamara.BORDE, ancho + 2.0, true)
	ci.draw_polyline(linea, ArteCamara.RELLENO, ancho, true)

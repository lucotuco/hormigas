class_name SiluetaMueble
extends RefCounted
## Perfiles del material, sin el margen transparente ni la sombra de los sprites.
## Se preparan una vez por acabado/orientación. Las consultas sólo escalan Rect2.
## Los huecos grandes conservan paso; el calado diminuto del hierro es sólido.

static var _perfiles: Dictionary = {}

static func rectangulos(datos: Dictionary) -> Array[Rect2]:
	var rect: Rect2 = datos.rect
	var dibujo: Dictionary = datos.get("dibujo", datos)
	var tipo := String(datos.tipo)
	if dibujo.get("acabado", "") == "carton" or tipo not in ["obelisco", "torre", "arco", "planta", "inodoro", "silla", "columna", "anfora", "fuente", "farol", "cartel"]:
		var completo: Array[Rect2] = [rect]
		return completo
	var frente := String(dibujo.get("frente", "sur")) if tipo == "silla" else "sur"
	var clave := tipo + ":" + frente
	if not _perfiles.has(clave):
		var perfil := _crear_perfil(tipo)
		if frente != "sur":
			for i in perfil.size():
				perfil[i] = _orientar(perfil[i], frente)
		_perfiles[clave] = perfil
	var resultado: Array[Rect2] = []
	for banda: Rect2 in _perfiles[clave]:
		resultado.append(Rect2(rect.position + banda.position * rect.size, banda.size * rect.size))
	return resultado

static func _orientar(rect: Rect2, frente: String) -> Rect2:
	match frente:
		"norte":
			return Rect2(Vector2.ONE - rect.end, rect.size)
		"este":
			return Rect2(Vector2(rect.position.y, 1.0 - rect.end.x), Vector2(rect.size.y, rect.size.x))
		"oeste":
			return Rect2(Vector2(1.0 - rect.end.y, rect.position.x), Vector2(rect.size.y, rect.size.x))
	return rect

static func _banda(perfil: Array[Rect2], y: float, fin: float, izquierda: float, derecha: float) -> void:
	perfil.append(Rect2(izquierda, y, derecha - izquierda, fin - y))

static func _crear_perfil(tipo: String) -> Array[Rect2]:
	var perfil: Array[Rect2] = []
	match tipo:
		"columna", "fuente":
			for i in 12:
				var y := 0.03 + 0.94 * i / 12.0
				var fin := 0.03 + 0.94 * (i + 1) / 12.0
				var dy := ((y + fin) * 0.5 - 0.5) / 0.47
				var ancho := sqrt(maxf(0.0, 1.0 - dy * dy)) * 0.47
				_banda(perfil, y, fin, 0.5 - ancho, 0.5 + ancho)
		"anfora":
			_banda(perfil, 0.08, 0.23, 0.32, 0.68)
			_banda(perfil, 0.23, 0.36, 0.25, 0.75)
			_banda(perfil, 0.36, 0.52, 0.06, 0.94)
			_banda(perfil, 0.52, 0.72, 0.12, 0.88)
			_banda(perfil, 0.72, 0.86, 0.24, 0.76)
			_banda(perfil, 0.86, 0.94, 0.35, 0.65)
		"farol":
			_banda(perfil, 0.03, 0.32, 0.20, 0.80)
			_banda(perfil, 0.32, 0.90, 0.43, 0.57)
			_banda(perfil, 0.90, 0.98, 0.28, 0.72)
		"cartel":
			_banda(perfil, 0.03, 0.36, 0.02, 0.98)
			_banda(perfil, 0.36, 0.90, 0.44, 0.56)
			_banda(perfil, 0.90, 0.98, 0.28, 0.72)
		"obelisco":
			# Fuente: ArteCasa.OTROS.obelisco (134 × 503). La punta empieza
			# bastante más abajo y más al centro que la esquina del rectángulo.
			_banda(perfil, 0.015, 0.040, 0.493, 0.563)
			_banda(perfil, 0.040, 0.065, 0.416, 0.635)
			_banda(perfil, 0.065, 0.090, 0.350, 0.698)
			for i in 15:
				var y := 0.090 + 0.855 * i / 15.0
				var fin := 0.090 + 0.855 * (i + 1) / 15.0
				var t := (y + fin) * 0.5
				_banda(perfil, y, fin, 0.361 - t * 0.260, 0.698 + t * 0.204)
			_banda(perfil, 0.945, 0.962, 0.067, 0.933)
			_banda(perfil, 0.962, 0.974, 0.097, 0.873)
		"torre":
			# El cuerpo superior se ensancha hasta la primera plataforma.
			# Los tramos transparentes bajo ambas plataformas son transitables.
			_banda(perfil, 0.020, 0.090, 0.484, 0.502)
			_banda(perfil, 0.090, 0.170, 0.451, 0.538)
			for i in 7:
				var y := 0.170 + 0.320 * i / 7.0
				var fin := 0.170 + 0.320 * (i + 1) / 7.0
				var t := (y + fin) * 0.5
				_banda(perfil, y, fin, 0.495 - t * 0.178, 0.496 + t * 0.177)
			_banda(perfil, 0.490, 0.535, 0.364, 0.626)
			for i in 3:
				var y := 0.535 + 0.135 * i / 3.0
				var fin := 0.535 + 0.135 * (i + 1) / 3.0
				var t := ((y + fin) * 0.5 - 0.535) / 0.135
				_banda(perfil, y, fin, lerpf(0.374, 0.305, t), lerpf(0.472, 0.428, t))
				_banda(perfil, y, fin, lerpf(0.520, 0.558, t), lerpf(0.618, 0.687, t))
			_banda(perfil, 0.670, 0.740, 0.254, 0.739)
			for i in 5:
				var y := 0.740 + 0.190 * i / 5.0
				var fin := 0.740 + 0.190 * (i + 1) / 5.0
				var t := ((y + fin) * 0.5 - 0.740) / 0.190
				# El arco inferior se abre con rapidez al bajar hacia los pies.
				var hueco := sqrt(maxf(0.0, t))
				_banda(perfil, y, fin, lerpf(0.244, 0.056, t), lerpf(0.492, 0.252, hueco))
				_banda(perfil, y, fin, lerpf(0.500, 0.737, hueco), lerpf(0.748, 0.934, t))
			# El zócalo termina en y≈0.952 del recorte, antes de su margen
			# transparente. El último bisel se angosta en ambos extremos.
			_banda(perfil, 0.930, 0.950, 0.028, 0.256)
			_banda(perfil, 0.930, 0.950, 0.727, 0.958)
			_banda(perfil, 0.950, 0.952, 0.091, 0.241)
			_banda(perfil, 0.950, 0.952, 0.744, 0.888)
		"arco":
			# Dos remates, un dintel y tres columnas: nunca un bloque completo
			# hasta el suelo. Cada vano conserva la abertura de la ilustración.
			_banda(perfil, 0.040, 0.095, 0.090, 0.247)
			_banda(perfil, 0.040, 0.095, 0.780, 0.910)
			_banda(perfil, 0.095, 0.220, 0.086, 0.917)
			_banda(perfil, 0.220, 0.290, 0.056, 0.946)
			_banda(perfil, 0.290, 0.440, 0.088, 0.919)
			_banda(perfil, 0.440, 0.460, 0.090, 0.308)
			_banda(perfil, 0.440, 0.460, 0.398, 0.603)
			_banda(perfil, 0.440, 0.460, 0.708, 0.914)
			_banda(perfil, 0.460, 0.485, 0.090, 0.290)
			_banda(perfil, 0.460, 0.485, 0.417, 0.584)
			_banda(perfil, 0.460, 0.485, 0.723, 0.916)
			_banda(perfil, 0.485, 0.525, 0.088, 0.273)
			_banda(perfil, 0.485, 0.525, 0.432, 0.571)
			_banda(perfil, 0.485, 0.525, 0.738, 0.918)
			_banda(perfil, 0.525, 0.730, 0.081, 0.267)
			_banda(perfil, 0.525, 0.730, 0.438, 0.564)
			_banda(perfil, 0.525, 0.730, 0.741, 0.925)
			_banda(perfil, 0.730, 0.880, 0.049, 0.284)
			_banda(perfil, 0.730, 0.880, 0.430, 0.572)
			_banda(perfil, 0.730, 0.880, 0.729, 0.951)
			_banda(perfil, 0.880, 0.928, 0.034, 0.293)
			_banda(perfil, 0.880, 0.928, 0.416, 0.584)
			_banda(perfil, 0.880, 0.928, 0.716, 0.963)
			_banda(perfil, 0.928, 0.941, 0.108, 0.230)
			_banda(perfil, 0.928, 0.941, 0.443, 0.553)
			_banda(perfil, 0.928, 0.941, 0.770, 0.892)
		"planta":
			_banda(perfil, 0.025, 0.125, 0.345, 0.505)
			_banda(perfil, 0.125, 0.230, 0.165, 0.800)
			_banda(perfil, 0.230, 0.335, 0.160, 0.800)
			_banda(perfil, 0.335, 0.440, 0.070, 0.790)
			_banda(perfil, 0.440, 0.545, 0.055, 0.810)
			_banda(perfil, 0.545, 0.650, 0.145, 0.770)
			_banda(perfil, 0.650, 0.755, 0.105, 0.710)
			_banda(perfil, 0.755, 0.825, 0.305, 0.620)
			_banda(perfil, 0.825, 0.875, 0.380, 0.500)
		"inodoro":
			_banda(perfil, 0.010, 0.080, 0.125, 0.730)
			_banda(perfil, 0.080, 0.220, 0.100, 0.755)
			_banda(perfil, 0.220, 0.310, 0.145, 0.705)
			_banda(perfil, 0.310, 0.410, 0.195, 0.660)
			_banda(perfil, 0.410, 0.610, 0.160, 0.695)
			_banda(perfil, 0.610, 0.730, 0.175, 0.680)
			_banda(perfil, 0.730, 0.810, 0.225, 0.630)
			_banda(perfil, 0.810, 0.860, 0.300, 0.555)
		"silla":
			# El PNG incluye una sombra a la derecha que no es material comestible.
			_banda(perfil, 0.050, 0.140, 0.090, 0.745)
			_banda(perfil, 0.140, 0.310, 0.105, 0.695)
			_banda(perfil, 0.310, 0.450, 0.100, 0.730)
			_banda(perfil, 0.450, 0.600, 0.090, 0.745)
			_banda(perfil, 0.600, 0.750, 0.080, 0.755)
			_banda(perfil, 0.750, 0.835, 0.090, 0.705)
			_banda(perfil, 0.835, 0.880, 0.130, 0.655)
	return perfil

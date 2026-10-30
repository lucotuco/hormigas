extends Node
## Herramienta de autoría: nunca forma parte del juego ni lee la GPU por bocado.

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	if not Graficos.listo:
		await Graficos.preparado
	var imagen := Graficos.textura.get_image()
	var vistos: Dictionary = {}
	for datos: Dictionary in Graficos.catalogo_muebles():
		var id := Graficos.clave_mueble(datos)
		if vistos.has(id):
			continue
		vistos[id] = true
		var clave: String = Graficos._mueble_claves[id]
		var region: Rect2 = Graficos._regiones_muebles_crudas[clave]
		var original: Rect2 = Graficos._rects_muebles_crudos[clave]
		var base: Vector2 = Graficos._mueble_medidas[id]
		var origen := Vector2i(region.position)
		var tam := Vector2i(region.size)
		var minimo := tam
		var maximo := Vector2i.ZERO
		for y in tam.y:
			for x in tam.x:
				if imagen.get_pixelv(origen + Vector2i(x, y)).a > 0.5:
					minimo = minimo.min(Vector2i(x, y))
					maximo = maximo.max(Vector2i(x + 1, y + 1))
		assert(maximo.x > minimo.x and maximo.y > minimo.y, id)
		var ocupado := Rect2(Vector2(minimo), Vector2(maximo - minimo))
		var medidas := Vector2(maximo - minimo)
		var escala := region.size / original.size
		var limite := Rect2((original.position + ocupado.position / escala) / base, ocupado.size / escala / base)
		var filas: Array = []
		var formas: Array = []
		var abiertas: Dictionary = {}
		for y in range(minimo.y, maximo.y):
			var intervalos: Array = []
			var x := minimo.x
			while x < maximo.x:
				if imagen.get_pixelv(origen + Vector2i(x, y)).a <= 0.5:
					x += 1
					continue
				var inicio := x
				while x < maximo.x and imagen.get_pixelv(origen + Vector2i(x, y)).a > 0.5:
					x += 1
				intervalos.append(Vector2i(inicio - minimo.x, x - minimo.x))
			var siguientes: Dictionary = {}
			for intervalo: Vector2i in intervalos:
				if abiertas.has(intervalo):
					var indice: int = abiertas[intervalo]
					formas[indice][3] += 1
					siguientes[intervalo] = indice
				else:
					siguientes[intervalo] = formas.size()
					formas.append([intervalo.x, y - minimo.y, intervalo.y - intervalo.x, 1])
			abiertas = siguientes
			filas.append(intervalos)
		var perfil: Array = []
		for banda in 16:
			var y0 := floori(medidas.y * banda / 16.0)
			var y1 := floori(medidas.y * (banda + 1) / 16.0)
			var ocupada := PackedByteArray()
			ocupada.resize(int(medidas.x))
			for y in range(y0, y1):
				for intervalo: Vector2i in filas[y]:
					for x in range(intervalo.x, intervalo.y):
						ocupada[x] = 1
			var x := 0
			while x < ocupada.size():
				if ocupada[x] == 0:
					x += 1
					continue
				var inicio := x
				while x < ocupada.size() and ocupada[x] != 0:
					x += 1
				perfil.append([inicio, y0, x - inicio, y1 - y0])
		for conjunto: Array in [formas, perfil]:
			for zona: Array in conjunto:
				for i in 4:
					zona[i] = snappedf(float(zona[i]) / medidas[i % 2], 0.0000001)
		print("MATERIAL=" + JSON.stringify({"id": id, "datos": {"limites": [limite.position.x, limite.position.y, limite.size.x, limite.size.y], "formas": formas, "perfil": perfil}}))
	print("EXPORTACION_MATERIAL_OK " + str(vistos.size()))
	get_tree().quit()

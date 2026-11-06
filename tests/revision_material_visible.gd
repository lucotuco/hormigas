extends "res://tests/prueba_material_visible.gd"
## QA con renderer real: sólo esta revisión lee el atlas final una vez.
var _atlas: Image
var _parciales_contorno := 0

class MuestraConIndicadores extends Node2D:
	var datos: Dictionary
	func _draw() -> void:
		Graficos.dibujar_mueble(self, datos, true)
		draw_rect(Rect2(-30, -54, 60, 8), Color("c5d98b"))
		draw_rect(Rect2(-30, -42, 60, 5), Color.BLUE)
		draw_circle(Vector2(45, 0), 5, Color(0.92, 0.2, 0.1))


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Juego.reiniciar_estado()
	if DisplayServer.get_name() == "headless":
		verificar(false, "esta revisión necesita el renderer real")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	get_window().size = Vector2i(1920, 1080)
	if not Graficos.listo:
		await Graficos.preparado
	_atlas = Graficos.textura.get_image()
	verificar(_atlas != null and not _atlas.is_empty(), "el atlas final permite auditar sus píxeles sin conservar el viewport crudo")
	probar_png_originales()
	await probar_indicadores_con_sombra()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true # Fixture GPU manual, no presupuesto de juego.
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._activa = false
	run.colonia.hide()
	run.hud.hide()
	run.niebla.hide()
	await probar_retazos_visibles(run)
	verificar(_parciales_contorno > 0, "el atlas conserva cobertura subpíxel en los contornos del dibujo")
	await capturar_carton(run)
	run.queue_free()
	await get_tree().process_frame
	_atlas = null
	print("Revisión de material visible: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar_png_originales() -> void:
	var original := ArteCasa.DESTINOS.get_image()
	if original.is_compressed():
		original.decompress()
	var exterior := {
		"obelisco": [Vector2(0.02, 0.50), Vector2(0.98, 0.50), Vector2(0.50, 0.99)],
		"torre": [Vector2(0.02, 0.40), Vector2(0.98, 0.40), Vector2(0.50, 0.85)],
		"arco": [Vector2(0.01, 0.50), Vector2(0.34, 0.70), Vector2(0.65, 0.70)],
	}
	for tipo: String in exterior:
		var region: Rect2 = ArteCasa.OTROS[tipo]
		var sin_superficie_opaca := true
		for uv: Vector2 in exterior[tipo]:
			var p := Vector2i((region.position + region.size * uv).floor())
			sin_superficie_opaca = sin_superficie_opaca and original.get_pixelv(p).a <= 0.75
		verificar(sin_superficie_opaca, "%s: los márgenes y vanos originales no esconden sombra opaca que el cutoff convertiría en material" % tipo)


func probar_retazos_visibles(run: Run) -> void:
	var catalogo := catalogo_unico()
	for caso: String in catalogo:
		var datos: Dictionary = catalogo[caso].duplicate(true)
		datos.rect = rect_fixture(datos.rect)
		var entera := Graficos.region_porcion_mueble(datos, datos.rect)
		var radio_aa := radio_contorno(datos)
		var cuerpo := contar_alpha(entera, radio_aa)
		_parciales_contorno += cuerpo.parciales
		var cuerpo_valido: bool = entera.has_area() and Rect2(Vector2.ZERO, Vector2(_atlas.get_size())).grow(tolerancia_atlas(entera)).encloses(entera) and cuerpo.material > 0 and cuerpo.fuera_contorno == 0
		cuerpo_valido = cuerpo_valido and coincide_cuerpo_completo(datos, entera)
		if not cuerpo_valido:
			print("  DIAG CUERPO ", caso, " radioAA=", radio_aa, " alpha=", cuerpo)
			if cuerpo.primer_fuera.x >= 0:
				var vecinos: Array = []
				for y in range(cuerpo.primer_fuera.y - radio_aa, cuerpo.primer_fuera.y + radio_aa + 1):
					var fila: Array = []
					for x in range(cuerpo.primer_fuera.x - radio_aa, cuerpo.primer_fuera.x + radio_aa + 1):
						fila.append(snappedf(_atlas.get_pixel(x, y).a, 0.001))
					vecinos.append(fila)
				print("  DIAG VECINOS ", vecinos)
		var correctos := 0
		for lado in 4:
			var pieza := PiezaCasa.new()
			run.comidas.add_child(pieza)
			pieza.iniciar({"clave": "alpha:%s:%d" % [caso, lado], "tipo": datos.tipo, "rect": datos.rect, "color": datos.color, "pared": false, "dibujo": datos, "recortes": SiluetaMueble.rectangulos(datos)}, run.cocina)
			pieza._preparar_mordiscos()
			var direccion := Vector2.from_angle(lado * PI * 0.5)
			var lejos: Vector2 = datos.rect.get_center() + direccion * 300
			var boca := pieza.punto_contacto(lejos) + direccion * 10.5
			var antes := pieza.mordiscos._pixeles.duplicate()
			var aire := aire_exterior(antes, pieza.mordiscos.tamano_mascara())
			var valor := pieza.morder_local(1.0e6, boca, LADO)
			var region := pieza.region_bocado()
			var alfa := contar_alpha(region, radio_aa)
			var valido: bool = valor > 0 and region.has_area() and entera.grow(tolerancia_atlas(entera)).encloses(region) and alfa.material > 0 and alfa.fuera_contorno == 0
			# Una patita puede viajar con transparencia propia a su alrededor.
			# Cada centro opaco/vacío debe coincidir con la RLE del cuerpo;
			# nunca se acepta sombra ni material inventado en ese espacio.
			valido = valido and coincide_con_material(datos, entera, region)
			valido = valido and porcion_exterior(pieza.mordiscos, antes, aire, pieza._porcion_reciente)
			correctos += int(valido)
			if not valido:
				print("  DIAG %s lado%d: boca=%s; porción=%s; región=%s; alpha=%s; valor=%.12f" % [caso, lado, boca, pieza._porcion_reciente, region, alfa, valor])
			pieza.queue_free()
		verificar(cuerpo_valido and correctos == 4, "%s: material completo coincide con RLE; AA sólo en el contorno y cuatro bocados exteriores sin sombra" % caso)
		await get_tree().process_frame


func probar_indicadores_con_sombra() -> void:
	var visor := SubViewport.new()
	visor.size = Vector2i(192, 192)
	visor.transparent_bg = true
	visor.disable_3d = true
	visor.world_2d = World2D.new()
	visor.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(visor)
	var muestra := MuestraConIndicadores.new()
	muestra.position = Vector2(96, 96)
	muestra.datos = Graficos.catalogo_muebles()[0].duplicate(true)
	muestra.datos.rect = Rect2(-32, -32, 64, 64)
	var region := Graficos.region_porcion_mueble(muestra.datos, muestra.datos.rect)
	var tam_atlas := Vector2(_atlas.get_size())
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://mundo/recorte_bocados.gdshader")
	shader.set_shader_parameter("tamano", Vector2(64, 64))
	shader.set_shader_parameter("sombra_activa", true)
	shader.set_shader_parameter("region_cuerpo", Vector4(region.position.x / tam_atlas.x, region.position.y / tam_atlas.y, region.end.x / tam_atlas.x, region.end.y / tam_atlas.y))
	shader.set_shader_parameter("uv_por_unidad", region.size / tam_atlas / Vector2(64, 64))
	muestra.material = shader
	visor.add_child(muestra)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var imagen := visor.get_texture().get_image()
	var barra := imagen.get_pixel(96, 45)
	var franja := imagen.get_pixel(96, 56)
	var circulo := imagen.get_pixel(141, 96)
	verificar(barra.a > 0.99 and barra.g > 0.6 and franja.a > 0.99 and franja.b > 0.8, "las barras primitivas conservan color y opacidad con sombra_activa, incluso junto al cuerpo")
	verificar(circulo.a > 0.99 and circulo.r > 0.7 and circulo.r > circulo.g + 0.25, "un círculo primitivo no se interpreta como UV del atlas ni desaparece por el shader de sombra")
	imagen.save_png("res://.godot/qa/material_visible_indicadores.png")
	visor.queue_free()
	await get_tree().process_frame


func capturar_carton(run: Run) -> void:
	var caja := run.objetivo_practica
	caja._preparar_mordiscos()
	run.camara.position = caja.position
	run.camara.zoom = Vector2.ONE * 3.5
	run.camara.force_update_scroll()
	var derecha := caja.rect_mundo.get_center() + Vector2(caja.rect_mundo.size.x, 0)
	var boca := caja.punto_contacto(derecha) + Vector2(10.5, 0)
	var h := run.colonia._nacer("obrera", boca)
	run.colonia.show()
	h.scale = Vector2.ONE * 1.5
	h._dano = 1.0e6
	h._capacidad = 20
	h._porciones_ciclo = 1 # Esta captura compara un único retazo con su fuente inmediata.
	h.estado = Hormiga.Estado.MORDIENDO
	h.comida = caja
	h.rotation = PI
	h._actualizar_sprite()
	await captura("material_visible_carton_antes")
	h._reloj_mordida = 0
	h._morder(1.0 / 60.0)
	caja._process(0.13)
	h._reloj_vida += 0.3
	h._actualizar_sprite()
	var alfa := contar_alpha(caja.region_bocado(), radio_contorno(caja.pieza.dibujo))
	var cuerpo := Graficos.region_porcion_mueble(caja.pieza.dibujo, caja.rect_mundo)
	verificar(h.carga > 0 and h._retazos.size() == 1 and alfa.material > 0 and alfa.fuera_contorno == 0 and coincide_con_material(caja.pieza.dibujo, cuerpo, caja.region_bocado()), "el primer retazo del cartón principal coincide con su cuerpo y transparencia propia, nunca con la sombra derecha")
	verificar(h._tamanos_retazos.size() == 1 and h._tamanos_retazos[0].is_equal_approx(caja.tamano_bocado()), "la muestra transportada mantiene el tamaño del material que falta")
	await captura("material_visible_carton_un_bocado")
	var conectadas := true
	for i in 31:
		var antes := caja.mordiscos._pixeles.duplicate()
		var aire := aire_exterior(antes, caja.mordiscos.tamano_mascara())
		boca = caja.punto_contacto(derecha) + Vector2(10.5, 0)
		var valor := caja.morder_local(1.0e6, boca, LADO)
		conectadas = conectadas and valor > 0 and porcion_exterior(caja.mordiscos, antes, aire, caja._porcion_reciente)
	caja._process(0.13)
	verificar(conectadas, "32 bocados del cartón abren su borde de forma continua, sin pozos interiores")
	await captura("material_visible_carton_32_bocados")


func contar_alpha(region: Rect2, radio_aa := 2) -> Dictionary:
	var material := 0
	var parciales := 0
	var fuera_contorno := 0
	var primer_fuera := Vector2i(-1, -1)
	var cantidad := 0
	var borde_fuera := 0
	if region.has_area():
		for y in range(maxi(0, floori(region.position.y)), mini(_atlas.get_height(), ceili(region.end.y))):
			for x in range(maxi(0, floori(region.position.x)), mini(_atlas.get_width(), ceili(region.end.x))):
				# Auditar el centro de los texeles DENTRO del recorte. Floor/ceil
				# agregaba vecinos de fuera cuando end=entero+un ULP float32.
				# Un píxel transparente con centro interior sigue siendo fallo.
				if not region.has_point(Vector2(x + 0.5, y + 0.5)):
					borde_fuera += 1
					continue
				var a := _atlas.get_pixel(x, y).a
				material += int(a > 0.5)
				parciales += int(a > 0.001 and a < 0.999)
				if a > 0.001 and a < 0.999 and not parcial_en_contorno(Vector2i(x, y), radio_aa):
					fuera_contorno += 1
					if primer_fuera.x < 0:
						primer_fuera = Vector2i(x, y)
				cantidad += 1
		# Un trozo menor a un texel puede no contener ningún centro de la
		# grilla. Se comprueba su propio centro, no un vecino de la región.
		if cantidad == 0:
			var p := Vector2i(region.get_center().floor()).clamp(Vector2i.ZERO, _atlas.get_size() - Vector2i.ONE)
			var a := _atlas.get_pixelv(p).a
			material = int(a > 0.5)
			parciales = int(a > 0.001 and a < 0.999)
			fuera_contorno = int(parciales > 0 and not parcial_en_contorno(p, radio_aa))
			cantidad = 1
	return {"material": material, "parciales": parciales, "fuera_contorno": fuera_contorno, "primer_fuera": primer_fuera, "total": cantidad, "centros_fuera": borde_fuera}


func radio_contorno(datos: Dictionary) -> int:
	var clave: String = Graficos._mueble_claves[Graficos.clave_mueble(datos)]
	var original: Rect2 = Graficos._rects_muebles_crudos[clave]
	var region: Rect2 = Graficos._regiones_muebles_crudas[clave]
	var escala := region.size / original.size
	# AA de StyleBox/polyline: como máximo una unidad autorada más un texel
	# por el raster. No depende del zoom ni de tolerancias de la máscara R8.
	return ceili(maxf(escala.x, escala.y)) + 1


func parcial_en_contorno(pixel: Vector2i, radio: int) -> bool:
	var vacio := false
	var solido := false
	for y in range(maxi(0, pixel.y - radio), mini(_atlas.get_height(), pixel.y + radio + 1)):
		for x in range(maxi(0, pixel.x - radio), mini(_atlas.get_width(), pixel.x + radio + 1)):
			var a := _atlas.get_pixel(x, y).a
			vacio = vacio or a <= 0.001
			solido = solido or a > 0.5
			if vacio and solido:
				return true
	return false


func coincide_cuerpo_completo(datos: Dictionary, cuerpo: Rect2) -> bool:
	# Raster de referencia nativo de QA: comparar cada texel del cuerpo,
	# no sólo los cuatro retazos. El juego nunca ejecuta esta lectura GPU.
	var zona := Rect2i(Vector2i(cuerpo.position.round()), Vector2i(cuerpo.size.round()))
	if not zona.has_area():
		return false
	var referencia := Image.create(zona.size.x, zona.size.y, false, Image.FORMAT_R8)
	referencia.fill(Color.BLACK)
	for forma: Array in SiluetaMueble.datos_material(datos).formas:
		var inicio := Vector2i((Vector2(forma[0], forma[1]) * Vector2(zona.size)).round())
		var tam := Vector2i((Vector2(forma[2], forma[3]) * Vector2(zona.size)).round())
		referencia.fill_rect(Rect2i(inicio, tam), Color.WHITE)
	var declarado := referencia.get_data()
	var dibujado := _atlas.get_region(zona).get_data()
	for i in declarado.size():
		if (declarado[i] != 0) != (dibujado[i * 4 + 3] > 127):
			print("  DIAG RLE ", Graficos.clave_mueble(datos), " texel=", Vector2i(i % zona.size.x, i / zona.size.x as int))
			return false
	return true


func tolerancia_atlas(region: Rect2) -> float:
	# Unas pocas ULP en coordenadas del atlas (hasta 8192), nunca un texel.
	return maxf(EPS_POSICION, maxf(region.end.abs().x, region.end.abs().y) * 0.0000005)


func coincide_con_material(datos: Dictionary, cuerpo: Rect2, region: Rect2) -> bool:
	if not cuerpo.has_area() or not region.has_area():
		return false
	var material := SiluetaMueble.datos_material(datos)
	if material.is_empty():
		return false
	var auditados := 0
	for y in range(maxi(0, floori(region.position.y)), mini(_atlas.get_height(), ceili(region.end.y))):
		for x in range(maxi(0, floori(region.position.x)), mini(_atlas.get_width(), ceili(region.end.x))):
			var centro := Vector2(x + 0.5, y + 0.5)
			if not region.has_point(centro):
				continue
			auditados += 1
			if not texel_coincide(centro, cuerpo, material.formas):
				return false
	if auditados == 0:
		return texel_coincide(region.get_center(), cuerpo, material.formas)
	return true


func texel_coincide(punto: Vector2, cuerpo: Rect2, formas: Array) -> bool:
	var uv := (punto - cuerpo.position) / cuerpo.size
	var declarado := false
	for forma: Array in formas:
		if Rect2(forma[0], forma[1], forma[2], forma[3]).has_point(uv):
			declarado = true
			break
	var pixel := Vector2i(punto.floor()).clamp(Vector2i.ZERO, _atlas.get_size() - Vector2i.ONE)
	var alpha := _atlas.get_pixelv(pixel).a
	return (alpha > 0.5) == declarado


func captura(nombre: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/%s.png" % nombre)

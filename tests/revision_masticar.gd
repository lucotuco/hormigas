extends Node
## GPU real: compara las cabezas horneadas y después usa contacto/material
## del juego. La dosis diminuta confirma trabajo sin retirar un píxel; sólo
## el bocado final admite daño suficiente para mostrar carga y tirón reales.
const RUN := preload("res://mundo/run.tscn")
const CASTAS_MUESTRA := ["obrera", "reina", "carpintera", "demoledora"]
const POSES := ["abierta", "contacto", "cerrada", "reabre"]
const CABEZA := Rect2i(30, 15, 21, 24) # x1..8, y-4..4 dentro de (-9,-9), a3texeles/u.
const EPS_ALPHA := 1.0 / 255.0
var total := 0
var fallas := 0


func _init() -> void:
	Juego.guardado_habilitado = false


func _ready() -> void:
	var huellas := huellas_guardados()
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	if DisplayServer.get_name() == "headless":
		verificar(false, "masticar necesita renderer y ventana reales, no una imagen de referencia headless")
		get_tree().quit(1)
		return
	get_window().size = Vector2i(1920, 1080)
	if not Graficos.listo:
		await Graficos.preparado
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	var atlas_rid := Graficos.textura.get_rid()
	var medidas := Vector2i(Graficos.textura.get_width(), Graficos.textura.get_height())
	var bytes_reales := medidas.x * medidas.y * 4
	var atlas_vivos := 0
	for hijo in Graficos.get_children():
		if hijo is SubViewport:
			atlas_vivos += 1
	verificar(atlas_vivos == 1 and Graficos._viewport.get_texture().get_rid() == atlas_rid,
		"caminar y masticar comparten un único atlas GPU publicado")
	verificar(bytes_reales <= Graficos.MAX_BYTES_ATLAS and bytes_reales == int(Graficos.presupuesto_atlas.bytes_actual)
		and medidas == Graficos.presupuesto_atlas.actual,
		"los bytes reales del atlas respetan el tope anterior sin reducir los tres texeles por unidad")
	print("MASTICAR atlas=", medidas, " bytes_reales=", bytes_reales,
		" MiB=", bytes_reales / 1048576.0, " tope=", Graficos.MAX_BYTES_ATLAS)
	# Una sola lectura del atlas para toda la autoría; nunca se consulta GPU
	# para decidir daño, contacto, navegación ni economía de los fixtures.
	var atlas := Graficos.textura.get_image()
	probar_catalogo(atlas)
	await probar_frente("mesa_comedor")
	await probar_frente("sofa")
	verificar(Graficos.textura.get_rid() == atlas_rid
		and Graficos.textura.get_width() == medidas.x and Graficos.textura.get_height() == medidas.y,
		"los cambios de pose, contacto y zoom no regeneran ni duplican el atlas")
	verificar(huellas == huellas_guardados(), "la revisión conserva SHA de partida y ajustes personales")
	Juego.reiniciar_estado()
	print("Revisión GPU masticar: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar_catalogo(atlas: Image) -> void:
	var catalogo := Image.create(54 * 4, 54 * Juego.castas.size() * 3, false, Image.FORMAT_RGBA8)
	catalogo.fill(Color.TRANSPARENT)
	var fila := 0
	verificar(Graficos.CUADROS_MASTICAR == 4 and Juego.castas.size() == 9,
		"el catálogo contiene cuatro poses de trabajo para las nueve castas y sus tres evoluciones")
	for datos: Dictionary in Juego.castas:
		for evolucion in 3:
			var nombre := "%s/evolución%d" % [datos.id, evolucion]
			var regiones := Graficos.animacion(datos.id, evolucion, true)
			var cabezas: Array[Image] = []
			var margen := regiones.size() == 4
			var encuadre := margen
			for cuadro in regiones.size():
				var region: Rect2 = regiones[cuadro]
				encuadre = encuadre and region.size == Vector2(54, 54)
				var imagen := atlas.get_region(Rect2i(region))
				var borde_libre := bordes_transparentes(imagen)
				margen = margen and borde_libre
				if not borde_libre:
					diagnosticar_borde(datos.id, evolucion, cuadro, region, imagen, atlas, true)
				if imagen.get_width() >= CABEZA.end.x and imagen.get_height() >= CABEZA.end.y:
					cabezas.append(imagen.get_region(CABEZA))
					catalogo.blit_rect(imagen, Rect2i(Vector2i.ZERO, imagen.get_size()), Vector2i(cuadro * 54, fila * 54))
			verificar(encuadre and margen, nombre + ": las cuatro poses completas conservan escala3 y aire en todo el perímetro, sin cortar mandíbulas ni corona")
			var distintas := cabezas.size() == 4
			for i in cabezas.size():
				distintas = distintas and tiene_material(cabezas[i])
				for j in range(i + 1, cabezas.size()):
					distintas = distintas and pixeles_distintos(cabezas[i], cabezas[j]) > 0
			verificar(distintas, nombre + ": las cuatro cabezas difieren por píxeles reales, no sólo por región del atlas")
			var caminar := Graficos.animacion(datos.id, evolucion)
			var caminar_completo := caminar.size() == Graficos.CUADROS
			var lado := 72 if datos.id == "voladora" else 54
			for cuadro in caminar.size():
				var region: Rect2 = caminar[cuadro]
				caminar_completo = caminar_completo and region.size == Vector2(lado, lado)
				var imagen := atlas.get_region(Rect2i(region))
				var borde_libre := bordes_transparentes(imagen)
				caminar_completo = caminar_completo and borde_libre
				if not borde_libre:
					diagnosticar_borde(datos.id, evolucion, cuadro, region, imagen, atlas, false)
			verificar(caminar_completo, nombre + ": los ocho cuadros al caminar siguen completos a3texeles/u, incluidas alas y detalles de evolución")
			fila += 1
	verificar(catalogo.save_png("res://.godot/qa/masticar_catalogo_gpu.png") == OK,
		"catálogo de las108poses de trabajo recortado del atlas GPU real")


func bordes_transparentes(imagen: Image) -> bool:
	if imagen.is_empty():
		return false
	for x in imagen.get_width():
		if imagen.get_pixel(x, 0).a > EPS_ALPHA or imagen.get_pixel(x, imagen.get_height() - 1).a > EPS_ALPHA:
			return false
	for y in imagen.get_height():
		if imagen.get_pixel(0, y).a > EPS_ALPHA or imagen.get_pixel(imagen.get_width() - 1, y).a > EPS_ALPHA:
			return false
	return true


## Evidencia de un fallo, nunca una tolerancia nueva. El contexto conserva
## también los ocho texeles vecinos para distinguir recorte de bleed ajeno.
func diagnosticar_borde(casta: String, evolucion: int, cuadro: int, region: Rect2,
		imagen: Image, atlas: Image, masticando: bool) -> void:
	var familia := "comer" if masticando else "caminar"
	var puntos := 0
	for y in imagen.get_height():
		for x in imagen.get_width():
			if x != 0 and x != imagen.get_width() - 1 and y != 0 and y != imagen.get_height() - 1:
				continue
			var color := imagen.get_pixel(x, y)
			if color.a <= EPS_ALPHA:
				continue
			puntos += 1
			print("DIAG BORDE familia=", familia, " casta=", casta, " evolución=", evolucion,
				" cuadro=", cuadro, " región=", region, " local=", Vector2i(x, y),
				" atlas=", Vector2i(region.position) + Vector2i(x, y),
				" alpha=", color.a, " rgba=", color)
	var nombre := "masticar_borde_%s_%d_%d" % [casta, evolucion, cuadro]
	if masticando:
		nombre += "_comer"
	var archivo := "res://.godot/qa/" + nombre + ".png"
	var contexto := Rect2i(region.grow(8.0)).intersection(Rect2i(Vector2i.ZERO, atlas.get_size()))
	print("DIAG BORDE resumen familia=", familia, " casta=", casta, " evolución=", evolucion,
		" cuadro=", cuadro, " región=", region, " puntos=", puntos, " EPS_ALPHA=", EPS_ALPHA,
		" guardar=", imagen.save_png(archivo),
		" contexto=", atlas.get_region(contexto).save_png("res://.godot/qa/" + nombre + "_contexto.png"))


func tiene_material(imagen: Image) -> bool:
	for y in imagen.get_height():
		for x in imagen.get_width():
			if imagen.get_pixel(x, y).a > 0.5:
				return true
	return false


func pixeles_distintos(a: Image, b: Image) -> int:
	if a.get_size() != b.get_size():
		return -1
	var distintos := 0
	for y in a.get_height():
		for x in a.get_width():
			distintos += int(a.get_pixel(x, y) != b.get_pixel(x, y))
	return distintos


func probar_frente(tipo: String) -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	seed(47021)
	var run: Run = RUN.instantiate()
	run.preparacion_sincrona = true
	add_child(run)
	# Fixture de autoría, no autoplay ni medición del balance. Las únicas
	# transacciones ejecutadas abajo pasan por _morder() y el material reales.
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.radio_actual = 12000.0
	run.hud.hide()
	run.niebla.hide()
	run.eventos.hide()
	for h: Hormiga in run.colonia.hormigas:
		h.detener()
		h.hide()
	var pieza: PiezaCasa
	for candidata: PiezaCasa in run.comidas.partes:
		if candidata.pieza.tipo == tipo:
			pieza = candidata
			break
	verificar(pieza != null and pieza.preparar_material(), tipo + ": usa la pieza real de la casa y su material publicado")
	if pieza == null or pieza.mordiscos == null:
		run.queue_free()
		await get_tree().process_frame
		return
	var hormigas: Array[Hormiga] = []
	var puestos: Array[Vector2] = []
	var hijos: Array[int] = []
	var centro := Vector2.ZERO
	var vida := pieza.vida
	var pixeles := pieza.mordiscos._pixeles.duplicate()
	var ingreso := Juego.migas_run
	for i in CASTAS_MUESTRA.size():
		var desde := Vector2(pieza.rect_mundo.get_center().x + (i - 1.5) * 80.0, pieza.rect_mundo.position.y - 120.0)
		var puesto := pieza.punto_trabajo(desde, run.radio_actual, false, 3)
		verificar(puesto.is_finite() and pieza.alcanza_contacto(puesto) and run.cocina.libre(puesto, Cocina.MARGEN),
			"%s/%s: boca sobre frente exacto, no sobre sombra ni interior sólido" % [tipo, CASTAS_MUESTRA[i]])
		if not puesto.is_finite():
			continue
		var h := run.colonia._nacer(CASTAS_MUESTRA[i], puesto)
		h.comida = pieza
		h.estado = Hormiga.Estado.MORDIENDO
		h._dano = 1.0e-12
		h._intervalo_mordida = 4.0
		h._capacidad = 99
		h._porciones_ciclo = 1
		h._reloj_mordida = 0.0
		h._desfase_masticar = 0.0
		h._evolucion = 2 if i in [1, 2] else 0
		h.en_pantalla = true
		h.rotation = (pieza.punto_contacto(puesto) - puesto).angle()
		h._morder(1.0 / 60.0)
		hormigas.append(h)
		puestos.append(puesto)
		hijos.append(h.get_child_count())
		centro += puesto
	verificar(hormigas.size() == 4, tipo + ": obrera, reina, carpintera y demoledora comparten el frente sin una representación alternativa")
	if hormigas.is_empty():
		run.queue_free()
		await get_tree().process_frame
		return
	centro /= hormigas.size()
	for zoom: float in [1.0, 3.4]:
		run.camara.position = centro + Vector2(0, 35)
		run.camara.zoom = Vector2.ONE * zoom
		run.camara.force_update_scroll()
		for cuadro in 4:
			var correctas := true
			for i in hormigas.size():
				var h := hormigas[i]
				# Elegir el interior de cada pose evita empates de coma flotante
				# en sus límites. Sólo se adelanta el reloj VISUAL del fixture.
				h._reloj_vida = (cuadro + 0.05) / (4.0 * AspectoHormiga.CICLOS_MASTICAR)
				h._actualizar_sprite()
				correctas = correctas and h._masticando_animacion and h._cuerpo.region_rect == Graficos.animacion(h.casta, h._evolucion, true)[cuadro]
				correctas = correctas and h.position == puestos[i] and h.carga == 0.0 and h.bocados == 0
				correctas = correctas and h._cuerpo.texture.get_rid() == Graficos.textura.get_rid() and h.get_child_count() == hijos[i]
				correctas = correctas and AspectoHormiga.pulso_bocado(h._reloj_vida - h._tiempo_bocado, 0.19) == 0.0
			verificar(correctas, "%s/zoom%.1f/%s: cambia la boca con contacto confirmado, sin extracción, tirón, sprites ni movimiento físico nuevos" % [tipo, zoom, POSES[cuadro]])
			await capturar("%s_zoom%d_%s" % [tipo, roundi(zoom * 10), POSES[cuadro]])
	verificar(pieza.vida == vida and pieza.mordiscos._pixeles == pixeles and Juego.migas_run == ingreso,
		tipo + ": masticar durante las ocho capturas no borra material ni anticipa migas")
	await probar_tiron_real(run, pieza, hormigas[0], centro)
	var principal := hormigas[0]
	run.camara.zoom = Vector2.ONE * 0.2
	principal._actualizar_sprite()
	verificar(not principal._masticando_animacion, tipo + ": el detalle se desactiva al alejarse, sin agrandar hormigas")
	run.camara.zoom = Vector2.ONE
	run.activa = false
	principal._actualizar_sprite()
	verificar(not principal._masticando_animacion, tipo + ": una expedición inactiva no conserva la animación de trabajo")
	run.queue_free()
	await get_tree().process_frame


func probar_tiron_real(run: Run, pieza: PiezaCasa, h: Hormiga, centro: Vector2) -> void:
	var vida := pieza.vida
	var ingreso := Juego.migas_run
	h._dano = pieza.vida_max
	h._reloj_vida = 5.0
	h._reloj_mordida = 0.0
	h._morder(1.0 / 60.0)
	pieza._process(0.13)
	verificar(pieza.vida < vida and h.carga > 0.0 and h.bocados == 1 and h._tiempo_bocado == h._reloj_vida
		and h._retazos.size() == 1 and h._tamanos_retazos[0].is_equal_approx(pieza.tamano_bocado())
		and Juego.migas_run == ingreso,
		pieza.pieza.tipo + ": el tirón empieza sólo al desprender un retazo real y conserva tamaño y valor sin cobrarlo")
	var vida_despues := pieza.vida
	var carga := h.carga
	for zoom: float in [1.0, 3.4]:
		run.camara.position = centro + Vector2(0, 35)
		run.camara.zoom = Vector2.ONE * zoom
		run.camara.force_update_scroll()
		h._reloj_vida = h._tiempo_bocado + 0.01
		h._actualizar_sprite()
		verificar(AspectoHormiga.pulso_bocado(h._reloj_vida - h._tiempo_bocado, 0.19) > 0.9,
			"%s/zoom%.1f: tirón visible ligado al bocado real, no al ciclo continuo de mandíbula" % [pieza.pieza.tipo, zoom])
		await capturar("%s_zoom%d_tiron_real" % [pieza.pieza.tipo, roundi(zoom * 10)])
		h._reloj_vida = h._tiempo_bocado + 0.3
		h._actualizar_sprite()
		await capturar("%s_zoom%d_retazo_levantado" % [pieza.pieza.tipo, roundi(zoom * 10)])
	verificar(pieza.vida == vida_despues and h.carga == carga and Juego.migas_run == ingreso
		and AspectoHormiga.pulso_bocado(h._reloj_vida - h._tiempo_bocado, 0.19) == 0.0,
		pieza.pieza.tipo + ": el tirón termina sin ejecutar otro bocado ni transformar carga en ingreso")


func capturar(nombre: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var imagen := get_viewport().get_texture().get_image()
	verificar(imagen.get_size() == Vector2i(1920, 1080)
		and imagen.save_png("res://.godot/qa/masticar_" + nombre + ".png") == OK,
		"captura FullHD del juego: " + nombre)


func huellas_guardados() -> Dictionary:
	var huellas := {}
	for ruta: String in [Juego.RUTA_PARTIDA, Ajustes.RUTA]:
		huellas[ruta] = FileAccess.get_sha256(ruta) if FileAccess.file_exists(ruta) else "ausente"
	return huellas


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + mensaje)

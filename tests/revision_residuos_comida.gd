extends Node
## Regresión GPU: no quedan sombras ni grietas huérfanas al retirar alimento.
## Sólo este fixture lee el atlas y la GPU; el juego conserva su geometría CPU.
const TAMANO_VISOR := Vector2i(512, 512)
const ESCALA := 2.0
const DESPLAZAMIENTO_SOMBRA := Vector2(1.5, 2.5)
const UMBRAL_ALPHA := 0.55
## Transformación interpolada del quad GPU vs inversa CPU. Incluso sobre las
## 256 unidades locales del visor equivale a sólo 0.002048 píxeles de imagen.
const TOLERANCIA_LOCAL := TAMANO_VISOR.x / ESCALA * 0.000004
## Atlas/lectura RGBA8 y pesos de interpolación hardware: un nivel de alfa,
## no una cantidad de píxeles que se permita dejar flotando.
const TOLERANCIA_ALPHA := 1.0 / 255.0
var fallas := 0
var verificaciones := 0
var _atlas: Image
var _visor: SubViewport
var _etapa := "actual"
var _comparativa: Image
var _fila_comparativa := 0
var _tolerancias_subpixel := true


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Juego.reiniciar_estado()
	if DisplayServer.get_name() == "headless":
		comprobar(false, "esta revisión necesita renderer real")
		get_tree().quit(1)
		return
	var etiqueta := OS.get_environment("QA_RESIDUOS_ETAPA").to_lower()
	if etiqueta in ["antes", "despues"]:
		_etapa = etiqueta
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	get_window().size = Vector2i(1920, 1080)
	if not Graficos.listo:
		await Graficos.preparado
	_atlas = Graficos.textura.get_image()
	_probar_conexion_alimentos()
	_visor = SubViewport.new()
	_visor.size = TAMANO_VISOR
	_visor.transparent_bg = true
	_visor.disable_3d = true
	_visor.world_2d = World2D.new()
	_visor.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_visor)
	_comparativa = Image.create_empty(960, 960, false, Image.FORMAT_RGBA8)
	_comparativa.fill(Color("e9e0c7"))
	var catalogo := _catalogo()
	comprobar(catalogo.size() == 30, "se revisan los 27 alimentos y los tres envoltorios del mismo atlas")
	for tipo: Dictionary in catalogo:
		for angulo: float in [0.0, 0.37]:
			await _probar_alimento(tipo, angulo)
	comprobar(_tolerancias_subpixel and TOLERANCIA_LOCAL * ESCALA < 0.01,
		"el redondeo admitido es menor al 1% de un píxel físico y al 1% de un píxel de imagen")
	await _probar_materiales_independientes()
	await _probar_barra()
	_comparativa.save_png("res://.godot/qa/residuos_comida_%s.png" % _etapa)
	print("REVISIÓN RESIDUOS %s: %d verificaciones; %d fallas." % [_etapa.to_upper(), verificaciones, fallas])
	get_tree().quit(1 if fallas else 0)


func _catalogo() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for tipo: Dictionary in Juego.comidas:
		resultado.append(tipo.duplicate(true))
	for hallazgo: Dictionary in CatalogoHallazgos.todos():
		resultado.append({"id": hallazgo.id_envoltorio, "nombre": hallazgo.nombre,
			"forma": hallazgo.forma, "color": hallazgo.color, "radio": hallazgo.radio,
			"vida": 10.0, "recompensa": 1.0})
	return resultado


func _probar_conexion_alimentos() -> void:
	# No se eliminan componentes chicos del juego ni se perdona una cantidad
	# arbitraria de píxeles: detalles, hojas y coberturas de un alimento deben
	# pertenecer al mismo cuerpo. Este diagnóstico descubre autorías sueltas;
	# no altera el atlas, la silueta física ni el material que muerde la hormiga.
	for tipo: Dictionary in Juego.comidas:
		var tamanos := _componentes_atlas("comida:" + str(tipo.id))
		print("  COMPONENTES %s: %s" % [tipo.id, str(tamanos)])
		comprobar(tamanos.size() == 1, "%s: el atlas intacto forma un solo cuerpo a 8 vecinos, sin detalles flotantes (componentes %s)" % [tipo.id, str(tamanos)])


func _componentes_atlas(clave: String) -> Array[int]:
	var region: Rect2 = Graficos.regiones[clave]
	var imagen := _atlas.get_region(Rect2i(region))
	var ancho := imagen.get_width()
	var alto := imagen.get_height()
	var pendientes := PackedByteArray()
	pendientes.resize(ancho * alto)
	pendientes.fill(0)
	for y in alto:
		for x in ancho:
			pendientes[y * ancho + x] = int(imagen.get_pixel(x, y).a >= UMBRAL_ALPHA)
	var tamanos: Array[int] = []
	for inicio in pendientes.size():
		if pendientes[inicio] == 0:
			continue
		var cola: Array[int] = [inicio]
		pendientes[inicio] = 0
		var cantidad := 0
		while not cola.is_empty():
			var actual := cola.pop_back() as int
			cantidad += 1
			var x := actual % ancho
			var y := actual / ancho as int
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var vecino := Vector2i(x + dx, y + dy)
					if vecino.x < 0 or vecino.y < 0 or vecino.x >= ancho or vecino.y >= alto:
						continue
					var indice := vecino.y * ancho + vecino.x
					if pendientes[indice] != 0:
						pendientes[indice] = 0
						cola.append(indice)
		tamanos.append(cantidad)
	return tamanos


func _crear(tipo: Dictionary, angulo: float, preparar := true) -> Comida:
	var alimento := Comida.new()
	var datos := tipo.duplicate(true)
	# HP bajo sólo evita barras en la prueba del cuerpo. El ID, el atlas y la
	# silueta son los originales; los 90% dañados sí provocan grietas antiguas.
	datos.vida = 10.0
	alimento.configurar(datos, 123)
	alimento.rotation = angulo
	alimento.scale = Vector2.ONE * ESCALA
	alimento.position = Vector2(TAMANO_VISOR) * 0.5
	_visor.add_child(alimento)
	# No hay Run ni trabajos pendientes: referencia CPU explícita y aislada.
	if preparar:
		alimento._preparar_mordiscos()
	return alimento


func _probar_alimento(tipo: Dictionary, angulo: float) -> void:
	var alimento := _crear(tipo, angulo, false)
	var sin_mascara := await _capturar()
	alimento._preparar_mordiscos()
	var paso := Vector2.ONE * alimento.radio * 2.0 / Vector2(alimento.mordiscos.tamano_mascara())
	_tolerancias_subpixel = _tolerancias_subpixel and TOLERANCIA_LOCAL < minf(paso.x, paso.y) * 0.01
	var intacta := await _capturar()
	var nombre := "%s rotación %.2f" % [tipo.id, angulo]
	comprobar(_contar_alpha(intacta) > 0, nombre + ": intacto visible")
	var masa_oculta := _material_opaco_oculto(sin_mascara, intacta, alimento)
	comprobar(masa_oculta == 0, nombre + ": preparar la máscara sin comer no oculta masa opaca real (%d píxeles)" % masa_oculta)
	if angulo == 0.0 and tipo.id in ["frutilla", "bombon"]:
		_guardar_intacto_preparado(tipo.id, sin_mascara, intacta)
	# No se libera el Node ni se oculta. Retirar material y luego vaciar la
	# máscara debe bastar para que desaparezca todo su dibujo, no sólo ±radio.
	alimento.mordiscos.recortar_bulk(0, 9.0, Vector2(-alimento.radio - 10.0, 0))
	alimento.vida = 1.0
	alimento.mordiscos.actualizar_textura()
	alimento.queue_redraw()
	var parcial := await _capturar()
	var soporte := _residuos_sin_material(parcial, alimento)
	comprobar(_contar_alpha(parcial) > 0 and alimento.mordiscos.area_total() > 0,
		nombre + ": conserva el remanente real luego de retirar aproximadamente 90%")
	comprobar(soporte == 0, nombre + ": cuerpo y sombra no flotan fuera del material (%d píxeles huérfanos)" % soporte)
	alimento.mordiscos.limpiar_celda(0)
	alimento.mordiscos.actualizar_textura()
	alimento.queue_redraw()
	var vacia := await _capturar()
	var restos := _contar_alpha(vacia, 0.0)
	comprobar(restos == 0, nombre + ": máscara vacía deja alfa cero también en márgenes (%d píxeles restantes)" % restos)
	if angulo == 0.0 and tipo.id in ["cereal", "miga", "galletita"]:
		_guardar_fila(intacta, parcial, vacia)
	alimento.queue_free()
	await get_tree().process_frame


func _residuos_sin_material(imagen: Image, alimento: Comida) -> int:
	var residuos := 0
	for y in imagen.get_height():
		for x in imagen.get_width():
			if imagen.get_pixel(x, y).a <= 0.005:
				continue
			var local := alimento.to_local(Vector2(x + 0.5, y + 0.5))
			if not _soporte_render(alimento, local) and not _soporte_render(alimento, local - DESPLAZAMIENTO_SOMBRA):
				residuos += 1
				if residuos <= 3:
					print("  DIAG %s rot%.2f píxel%s local%s RGBA%s; máscara=%s/%s atlas_bilineal=%.8f/%.8f" % [alimento.id, alimento.rotation,
						Vector2i(x, y), local, imagen.get_pixel(x, y), alimento.mordiscos.contiene(local), alimento.mordiscos.contiene(local - DESPLAZAMIENTO_SOMBRA),
						_alpha_atlas(alimento.id, local), _alpha_atlas(alimento.id, local - DESPLAZAMIENTO_SOMBRA)])
	return residuos


func _soporte_render(alimento: Comida, local: Vector2) -> bool:
	# La R8 usa nearest y el atlas usa bilinear. No reemplazar este muestreo
	# por píxeles cercanos ni permitir una cantidad arbitraria de residuos.
	# Sólo se toleran la precisión interpolada del quad rotado y un nivel
	# RGBA8 de filtrado. Toda muestra sigue necesitando material R8 presente.
	for dy: float in [-TOLERANCIA_LOCAL, 0.0, TOLERANCIA_LOCAL]:
		for dx: float in [-TOLERANCIA_LOCAL, 0.0, TOLERANCIA_LOCAL]:
			var punto := local + Vector2(dx, dy)
			if alimento.mordiscos.contiene(punto) and _alpha_atlas(alimento.id, punto) >= UMBRAL_ALPHA - TOLERANCIA_ALPHA:
				return true
	return false


func _alpha_atlas(id: String, local: Vector2) -> float:
	var clave := "comida:" + id
	var rect: Rect2 = Graficos.tamanos[clave]
	if not rect.has_point(local):
		return 0.0
	var region: Rect2 = Graficos.regiones[clave]
	# En normalized UV los centros de texel están en (n + 0.5) / tamaño.
	var punto := region.position + (local - rect.position) / rect.size * region.size - Vector2.ONE * 0.5
	var base := Vector2i(punto.floor())
	var fraccion := punto - Vector2(base)
	var arriba := lerpf(_alpha_texel(base), _alpha_texel(base + Vector2i.RIGHT), fraccion.x)
	var abajo := lerpf(_alpha_texel(base + Vector2i.DOWN), _alpha_texel(base + Vector2i.ONE), fraccion.x)
	return lerpf(arriba, abajo, fraccion.y)


func _alpha_texel(punto: Vector2i) -> float:
	var limite := _atlas.get_size() - Vector2i.ONE
	return _atlas.get_pixelv(punto.clamp(Vector2i.ZERO, limite)).a


func _material_opaco_oculto(antes: Image, despues: Image, alimento: Comida) -> int:
	var ocultos := 0
	for y in antes.get_height():
		for x in antes.get_width():
			if antes.get_pixel(x, y).a < 0.56 or despues.get_pixel(x, y).a > 0.5:
				continue
			var local := alimento.to_local(Vector2(x + 0.5, y + 0.5))
			# El cuerpo intacto ya estaba visible: preparar la máscara no debe
			# esconderlo. No filtrar por la CPU, pues eso escondería justamente
			# una discrepancia entre la silueta física y el dibujo original.
			if _alpha_atlas(alimento.id, local) >= UMBRAL_ALPHA:
				ocultos += 1
				if ocultos <= 3:
					print("  DIAG INTACTO %s rot%.2f píxel%s local%s alfa=%.8f→%.8f atlas=%.8f material=%s" % [alimento.id,
						alimento.rotation, Vector2i(x, y), local, antes.get_pixel(x, y).a, despues.get_pixel(x, y).a,
						_alpha_atlas(alimento.id, local), alimento.mordiscos.contiene(local)])
	return ocultos


func _probar_barra() -> void:
	var datos: Dictionary = Juego.comidas[2].duplicate(true)
	var alimento := _crear(datos, 0.37)
	alimento.vida_max = 100.0
	alimento.vida = 10.0
	alimento.mordiscos.limpiar_celda(0)
	alimento.mordiscos.actualizar_textura()
	alimento.queue_redraw()
	var imagen := await _capturar()
	var alto := maxf(2.0, alimento.radio * 0.12)
	var centro := alimento.position + Vector2(0, -alimento.radio - alto * 0.5 - 4.0) * ESCALA
	var presentes := 0
	for y in range(floori(centro.y - alto * ESCALA * 0.4), ceili(centro.y + alto * ESCALA * 0.4)):
		for x in range(floori(centro.x - alimento.radio * ESCALA * 0.7), ceili(centro.x + alimento.radio * ESCALA * 0.7)):
			presentes += int(imagen.get_pixel(x, y).a > 0.1)
	comprobar(presentes > 0, "la barra de vida conserva su dibujo aunque la máscara corporal esté vacía y el alimento rotado")
	alimento.veneno_restante = 0.5
	alimento.queue_redraw()
	var con_veneno := await _capturar()
	var indicadores := 0
	for y in con_veneno.get_height():
		for x in con_veneno.get_width():
			var previo := imagen.get_pixel(x, y)
			var actual := con_veneno.get_pixel(x, y)
			indicadores += int(actual.a > previo.a + 0.05 and actual.g > actual.r)
	comprobar(indicadores > 0, "los indicadores de veneno siguen visibles junto a la barra sin confundirlos con el cuerpo vacío")
	alimento.queue_free()
	await get_tree().process_frame


func _probar_materiales_independientes() -> void:
	var datos: Dictionary = Juego.comidas[2].duplicate(true)
	var primero := _crear(datos, 0.0, false)
	var segundo := _crear(datos, 0.0, false)
	primero.hide()
	var compartido := primero.material as ShaderMaterial
	comprobar(compartido != null and compartido == segundo.material,
		"dos alimentos intactos del mismo tipo comparten el mismo material visual")
	comprobar(primero.mordiscos == null and segundo.mordiscos == null,
		"el material intacto compartido no obliga a preparar máscaras físicas por instancia")
	var textura_cache: Texture2D = compartido.get_shader_parameter("mascara_bocados") if compartido != null else null
	var cache_antes := textura_cache.get_image().get_data() if textura_cache != null else PackedByteArray()
	var intacto_antes := await _capturar()
	primero._preparar_mordiscos()
	segundo._preparar_mordiscos()
	var propio := primero.material
	comprobar(primero.material != compartido and segundo.material != compartido and primero.material != segundo.material,
		"preparar dos alimentos crea materiales privados sin modificar el compartido")
	comprobar(primero.mordiscos != null and segundo.mordiscos != null and primero.mordiscos != segundo.mordiscos,
		"las dos preparaciones conservan máscaras físicas independientes")
	var mascara_primero := primero.mordiscos.textura_mascara()
	var mascara_segundo := segundo.mordiscos.textura_mascara()
	comprobar(mascara_primero != mascara_segundo and mascara_primero != textura_cache and mascara_segundo != textura_cache,
		"las texturas mutables de bocado no se comparten con otro alimento ni con el cache intacto")
	var cpu_segundo := segundo.mordiscos._pixeles.duplicate()
	var textura_segundo := mascara_segundo.get_image().get_data()
	var preparado_antes := await _capturar()
	primero.mordiscos.recortar_bulk(0, 9.0, Vector2(-primero.radio - 10.0, 0))
	primero.vida = 1.0
	primero.mordiscos.actualizar_textura()
	primero.queue_redraw()
	var preparado_despues := await _capturar()
	comprobar(segundo.mordiscos._pixeles == cpu_segundo and mascara_segundo.get_image().get_data() == textura_segundo,
		"comer uno no cambia la geometría ni los texeles de su compañero")
	comprobar(preparado_antes.get_data() == preparado_despues.get_data(),
		"el alimento compañero sigue dibujándose exactamente igual mientras se come el otro")
	comprobar(textura_cache != null and cache_antes == textura_cache.get_image().get_data(),
		"los bocados privados nunca modifican la máscara estática del cache intacto")
	# Simula la señal tardía de atlas preparado o un refresco de presentación.
	# No tiene permitido reemplazar la máscara privada por el material intacto.
	primero._preparar_visual()
	comprobar(primero.material == propio and primero.mordiscos.textura_mascara() == mascara_primero,
		"un callback visual tardío no repone el material intacto sobre uno ya mordido")
	segundo.queue_free()
	primero.queue_free()
	await get_tree().process_frame
	var tercero := _crear(datos, 0.0, false)
	var intacto_despues := await _capturar()
	comprobar(tercero.material == compartido and tercero.mordiscos == null and intacto_antes.get_data() == intacto_despues.get_data(),
		"otro intacto reutiliza el mismo cache sin heredar agujeros de los anteriores")
	tercero.queue_free()
	await get_tree().process_frame


func _capturar() -> Image:
	for cuadro in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return _visor.get_texture().get_image()


func _contar_alpha(imagen: Image, umbral := 0.005) -> int:
	var presentes := 0
	for y in imagen.get_height():
		for x in imagen.get_width():
			presentes += int(imagen.get_pixel(x, y).a > umbral)
	return presentes


func _guardar_fila(intacta: Image, parcial: Image, vacia: Image) -> void:
	var columna := 0
	for imagen: Image in [intacta, parcial, vacia]:
		var recorte := imagen.get_region(Rect2i(208, 208, 96, 96))
		recorte.resize(320, 320, Image.INTERPOLATE_NEAREST)
		_comparativa.blend_rect(recorte, Rect2i(0, 0, 320, 320), Vector2i(columna * 320, _fila_comparativa * 320))
		columna += 1
	_fila_comparativa += 1


func _guardar_intacto_preparado(id: String, intacta: Image, preparada: Image) -> void:
	var comparativa := Image.create_empty(640, 320, false, Image.FORMAT_RGBA8)
	comparativa.fill(Color("e9e0c7"))
	var columna := 0
	for imagen: Image in [intacta, preparada]:
		var recorte := imagen.get_region(Rect2i(192, 192, 128, 128))
		recorte.resize(320, 320, Image.INTERPOLATE_NEAREST)
		comparativa.blend_rect(recorte, Rect2i(0, 0, 320, 320), Vector2i(columna * 320, 0))
		columna += 1
	comparativa.save_png("res://.godot/qa/residuos_%s_intacto_preparado_%s.png" % [id, _etapa])


func comprobar(ok: bool, detalle: String) -> void:
	verificaciones += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)

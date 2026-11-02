extends Node
## Prueba administrativa de conservación/restauración. El daño bulk permite
## terminar componentes exactos, no pretende medir IA, ritmo ni duración humana.
const RUN := preload("res://mundo/run.tscn")
var total := 0
var fallas := 0


class CocinaSinDestino:
	extends Cocina
	var permitir := false

	func ajustar_destino(_pos: Vector2, _radio: float, _volando := false) -> Vector2:
		return Vector2.ZERO if permitir else Vector2.INF


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	probar_catalogo()
	for datos in ComponentesProyecto.todos():
		await probar_objetivo(datos)
	await probar_tesoro_unico()
	await probar_tesoro_postergado()
	await probar_tesoro_sin_posicion()
	await probar_objeto_sin_tesoro_emitido()
	await probar_terminacion_real()
	await probar_historico_y_casa()
	await probar_casa_opcional()
	probar_migracion_y_fundacion()
	await probar_checkpoint_y_contextos()
	Juego.reiniciar_estado()
	print("Componentes de proyectos: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func verificar(condicion: bool, mensaje: String) -> void:
	total += 1
	if condicion:
		print("OK ", mensaje)
	else:
		fallas += 1
		print("FALLA ", mensaje)


func cerca(a: float, b: float) -> bool:
	return absf(a - b) <= maxf(0.00001, maxf(absf(a), absf(b)) * 0.00000001)


func preparar(destino: String) -> void:
	Juego.reiniciar_estado()
	for anterior in Mundos.ORDEN:
		if anterior == destino:
			break
		Juego.coronas_cobradas[anterior] = true
		Juego.lugares_completados[anterior] = true
		Juego.coronas += int(Mundos.INFO[anterior].coronas)
	Juego.lugar_actual = destino
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()


func crear_run() -> Run:
	var run: Run = RUN.instantiate()
	run.preparacion_sincrona = true # Restauración/comida unitaria, sin reloj de frames.
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.radio_actual = 12000
	run.cocina.limite_rutas_por_cuadro = 0
	return run


func buscar(run: Run, id: String) -> PiezaCasa:
	for parte in run.comidas.partes:
		if parte.pieza.get("componentes_id", "") == id:
			return parte
	return null


func vaciar_componente(parte: PiezaCasa, componente: Dictionary) -> void:
	# Una extracción ambiental exacta por celda. No acredita en la cuenta
	# el valor devuelto: sólo comprueba geometría/callbacks/fragmentos nativos.
	for celda: int in componente.celdas:
		if not is_instance_valid(parte) or parte.muerta or parte.vidas[celda] <= 0:
			continue
		var formas: Array = parte._formas_por_celda[celda]
		if formas.is_empty():
			continue
		parte.morder_en(parte.vidas[celda], formas[0].get_center())


func probar_catalogo() -> void:
	var todos := ComponentesProyecto.todos()
	verificar(todos.size() == 12, "doce muebles concretos tienen componentes; no agrega muebles ni mapas")
	var cantidad := 0
	for datos in todos:
		var usadas: Dictionary = {}
		var celdas: int = datos.grilla.x * datos.grilla.y
		verificar(celdas <= 16 and datos.componentes.size() in [2, 3, 4], datos.id + ": dos a cuatro partes y hasta dieciséis celdas")
		for componente: Dictionary in datos.componentes:
			cantidad += 1
			verificar(ComponentesProyecto.componente_valido(componente.id)
				and ComponentesProyecto.objetivo_del_componente(componente.id) == datos.id,
				componente.id + ": identidad estable y decodificación validada")
			for celda: int in componente.celdas:
				verificar(celda >= 0 and celda < celdas and not usadas.has(celda), componente.id + ": material de celda exclusivo")
				usadas[celda] = true
		verificar(usadas.size() == celdas, datos.id + ": toda la silueta tiene dueño sin duplicarse")
	verificar(cantidad == 35, "treinta y cinco componentes explícitos no son cuatro cuadrados genéricos por objeto")
	verificar(ComponentesProyecto.objetivo("eiffel/torre").is_empty()
		and ComponentesProyecto.objetivo("casa/silla_inicial").is_empty(), "no persiste la primera silla ni altera la canónica Eiffel")
	var copia := ComponentesProyecto.objetivo("casa/carton_inicial")
	copia.componentes.clear()
	verificar(ComponentesProyecto.ids_objetivo("casa/carton_inicial").size() == 2, "el catálogo sólo entrega copias profundas")
	var primer_id: String = ComponentesProyecto.ids_objetivo("casa/carton_inicial")[0]
	var estado := ComponentesProyecto.normalizar_completos({primer_id: true, "inventado#x": true}, {})
	verificar(estado.size() == 1 and estado.has(primer_id), "normalización descarta componentes desconocidos")
	var completos := ComponentesProyecto.normalizar_completos({}, {"casa/carton_inicial": true})
	verificar(ComponentesProyecto.objetivo_terminado("casa/carton_inicial", completos)
		and not ComponentesProyecto.objetivo_terminado("inventado", completos), "un objetivo completo normaliza sus partes pero uno inexistente no se completa")


func probar_objetivo(datos: Dictionary) -> void:
	preparar(datos.destino)
	var run := crear_run()
	var parte := buscar(run, datos.id)
	verificar(is_instance_valid(parte), datos.id + ": corresponde a un mueble real")
	if not is_instance_valid(parte):
		run.queue_free()
		await get_tree().process_frame
		return
	var vida_original := parte.vida_max
	var valor_original := parte.recompensa
	var dieta_original := parte.nivel_requerido
	var region_original := Graficos.clave_mueble(parte.pieza.dibujo)
	var clave: String = parte.pieza.clave
	var cantidad_piezas := run.comidas.partes.size()
	var primero: Dictionary = datos.componentes[0]
	var hp_componente := 0.0
	var mascara := 0
	for celda: int in primero.celdas:
		hp_componente += parte._vidas_iniciales[celda]
		mascara |= 1 << celda
	for componente: Dictionary in datos.componentes:
		var material := 0.0
		for celda: int in componente.celdas:
			material += parte._vidas_iniciales[celda]
		verificar(material > 0, componente.id + ": el componente representa material opaco real")
	var punto_borrado: Vector2 = parte._formas_por_celda[primero.celdas[0]][0].get_center()
	var ingresos_antes := Juego.migas
	var ingresos_run_antes := Juego.migas_run
	var coronas_antes := Juego.coronas
	vaciar_componente(parte, primero)
	verificar(Juego.componente_proyecto_completo(primero.id), datos.id + ": completa la parte sólo al agotar sus celdas")
	verificar(not parte.muerta and cerca(parte.vida, vida_original - hp_componente), datos.id + ": persiste el resto del mueble con sus HP originales")
	verificar(Juego.migas == ingresos_antes and Juego.migas_run == ingresos_run_antes and Juego.coronas == coronas_antes,
		datos.id + ": terminar una parte no inventa monedas ni coronas")
	verificar(not Juego.objetivo_proyecto_completo(datos.id), datos.id + ": una parte no completa el proyecto entero")
	var resumen := parte.resumen_componentes()
	verificar(resumen.completados == 1 and resumen.total == datos.componentes.size()
		and resumen.id != primero.id, datos.id + ": el HUD distingue avance y próxima parte")
	var pendiente: Dictionary = datos.componentes[1]
	for celda: int in pendiente.celdas:
		if parte.vidas[celda] > 0 and not parte._formas_por_celda[celda].is_empty():
			parte.morder_en(parte.vidas[celda] * 0.1, parte._formas_por_celda[celda][0].get_center())
			break
	verificar(not Juego.componente_proyecto_completo(pendiente.id)
		and parte.vida < vida_original - hp_componente, datos.id + ": el daño parcial no se convierte en componente regalado")
	var captura := Juego.datos_partida()
	run.queue_free()
	await get_tree().process_frame
	Juego.restaurar_partida(captura)
	var saldo_antes := Juego.migas
	var segundo := crear_run()
	var restaurada := buscar(segundo, datos.id)
	verificar(is_instance_valid(restaurada), datos.id + ": cargar repone sólo el mueble pendiente")
	if not is_instance_valid(restaurada):
		segundo.queue_free()
		await get_tree().process_frame
		return
	verificar(cerca(restaurada.vida_max, vida_original) and cerca(restaurada.vida, vida_original - hp_componente),
		datos.id + ": no redistribuye la resistencia de partes comidas sobre el resto")
	verificar(cerca(restaurada.recompensa, valor_original) and restaurada.nivel_requerido == dieta_original
		and Graficos.clave_mueble(restaurada.pieza.dibujo) == region_original, datos.id + ": conserva valor dieta y atlas nativos")
	verificar(segundo.comidas.partes.size() == cantidad_piezas and Juego.migas == saldo_antes,
		datos.id + ": cargar no genera más nodos ni paga material omitido")
	verificar(restaurada.mordiscos == null and restaurada._componentes_mask == mascara
		and int(restaurada._mascara.get_shader_parameter("celdas_omitidas")) == mascara,
		datos.id + ": el hueco inicial usa dieciséis bits sin reservar una textura de daño")
	verificar(not restaurada.dentro_silueta(punto_borrado), datos.id + ": no vuelve a aparecer el contorno entero por el atajo intacto")
	var punto_vivo: Vector2 = restaurada._formas_por_celda[restaurada.vivas[0]][0].get_center()
	verificar(restaurada.dentro_silueta(punto_vivo), datos.id + ": las partes vivas conservan la selección bajo el cursor")
	var nav: Dictionary = segundo.cocina._obstaculos[clave]
	var bloquea := false
	for forma: Rect2 in nav.get("recortes", [nav.rect]):
		bloquea = bloquea or forma.has_point(punto_borrado)
	verificar(not bloquea, datos.id + ": la navegación inicial respeta el mismo hueco")
	restaurada._preparar_mordiscos()
	var hp_mascara := 0.0
	var omitidas_vacias := true
	for celda in restaurada.celdas.size():
		hp_mascara += restaurada.mordiscos.vida_celda(celda)
		if primero.celdas.has(celda):
			omitidas_vacias = omitidas_vacias and restaurada.mordiscos.area_celda(celda) == 0
	verificar(omitidas_vacias and cerca(hp_mascara, restaurada.vida),
		datos.id + ": la R8 lazy no recrea material ni HP de la parte guardada")
	var objetivo_pendiente: String = restaurada.pieza.get("objetivo_proyecto", "")
	if datos.destino == "casa":
		verificar(objetivo_pendiente == "" and not restaurada.pieza.has("proyecto_vida"),
			datos.id + ": descubrimiento opcional no endurece la casa ni condiciona la conquista")
	segundo.queue_free()
	await get_tree().process_frame


func probar_tesoro_unico() -> void:
	preparar("restaurante")
	var run := crear_run()
	var parte := buscar(run, "restaurante_despensa/alacena")
	verificar(not parte._tesoro_abierto and not Juego.tesoro_proyecto_abierto("restaurante_despensa/alacena"), "la alacena no empieza con premio cobrado")
	# Simula la llamada de Sondeo DESPUÉS de una extracción real, sin conceder
	# la evolución ni convertir el callback en una prueba de comportamiento IA.
	var punto: Vector2 = parte._formas_por_celda[0][0].position - Vector2(5, 0)
	parte.morder_local(parte.vida_max, punto)
	var cantidad := run.comidas._tesoros
	verificar(parte.abrir_escondite() and Juego.tesoro_proyecto_abierto("restaurante_despensa/alacena"),
		"Sondeo y puerta comparten una única marca permanente de tesoro")
	verificar(run.comidas._tesoros > cantidad and not parte.abrir_escondite(), "abrir de nuevo no duplica el escondite nativo")
	var datos := Juego.datos_partida()
	run.queue_free()
	await get_tree().process_frame
	Juego.restaurar_partida(datos)
	var siguiente := crear_run()
	parte = buscar(siguiente, "restaurante_despensa/alacena")
	verificar(parte._tesoro_abierto and siguiente.comidas._tesoros == 0 and not parte.abrir_escondite(),
		"cargar conserva el descubrimiento sin regalar copias de su comida")
	siguiente.queue_free()
	await get_tree().process_frame


func probar_tesoro_postergado() -> void:
	preparar("restaurante")
	var run := crear_run()
	var id := "restaurante_despensa/alacena"
	var parte := buscar(run, id)
	var puerta: Dictionary = ComponentesProyecto.objetivo(id).componentes[0]
	run.comidas._tesoros = 24
	vaciar_componente(parte, puerta)
	verificar(Juego.componente_proyecto_completo(puerta.id) and parte._tesoro_pendiente
		and not Juego.tesoro_proyecto_abierto(id), "el tope de tesoros conserva la puerta terminada y su apertura pendiente")
	var datos := Juego.datos_partida()
	run.queue_free()
	await get_tree().process_frame
	Juego.restaurar_partida(datos)
	var siguiente := crear_run()
	parte = buscar(siguiente, id)
	verificar(siguiente.comidas._tesoros == 0 and parte._tesoro_pendiente and not parte._tesoro_abierto,
		"restaurar una puerta pendiente no genera comida ni pierde el escondite")
	var celda := parte.vivas[0]
	var antes := parte.vida
	parte.morder_en(parte.vidas[celda] * 0.01, parte._formas_por_celda[celda][0].get_center())
	var creadas := siguiente.comidas._tesoros
	verificar(parte.vida < antes and creadas > 0 and Juego.tesoro_proyecto_abierto(id)
		and not parte._tesoro_pendiente, "una extracción real posterior abre una sola vez el escondite postergado")
	parte.morder_en(parte.vidas[celda] * 0.01, parte._formas_por_celda[celda][0].get_center())
	verificar(siguiente.comidas._tesoros == creadas and not parte.abrir_escondite(), "otras mordidas no duplican el tesoro recuperado")
	siguiente.queue_free()
	await get_tree().process_frame


func probar_tesoro_sin_posicion() -> void:
	preparar("restaurante")
	var run := crear_run()
	var parte := buscar(run, "restaurante_despensa/alacena")
	var cocina := CocinaSinDestino.new()
	run.add_child(cocina)
	run.cocina = cocina
	var cantidad := run.comidas.lista.size()
	verificar(not parte.abrir_escondite() and run.comidas._tesoros == 0 and run.comidas.lista.size() == cantidad,
		"sin posición válida no se crea comida invisible")
	verificar(not Juego.tesoro_proyecto_abierto("restaurante_despensa/alacena")
		and not Juego.hitos.has("primer_tesoro") and run.reglas.festin == 0.0,
		"un intento sin spawn no cobra el flag ni el hallazgo ni el servicio en cadena")
	cocina.permitir = true
	verificar(parte.abrir_escondite() and Juego.tesoro_proyecto_abierto("restaurante_despensa/alacena")
		and run.comidas._tesoros > 0, "cuando aparece una posición válida autoriza antes de crear el único premio")
	var creadas := run.comidas._tesoros
	verificar(not parte.abrir_escondite() and run.comidas._tesoros == creadas, "el reintento exitoso no admite otra copia")
	run.queue_free()
	await get_tree().process_frame


func probar_objeto_sin_tesoro_emitido() -> void:
	preparar("restaurante")
	var run := crear_run()
	var id := "restaurante_cocina/heladera"
	var parte := buscar(run, id)
	run.comidas._tesoros = 24
	for componente: Dictionary in ComponentesProyecto.objetivo(id).componentes:
		vaciar_componente(parte, componente)
	verificar(Juego.objetivo_proyecto_completo(id) and not Juego.tesoro_proyecto_abierto(id),
		"terminar todo el mueble no inventa una apertura si no pudo aparecer su comida")
	var guardado: Dictionary = JSON.parse_string(JSON.stringify(Juego.datos_partida()))
	run.queue_free()
	await get_tree().process_frame
	Juego.restaurar_partida(guardado)
	verificar(Juego.objetivo_proyecto_completo(id) and not Juego.tesoro_proyecto_abierto(id),
		"el roundtrip v9 conserva la diferencia entre mueble consumido y escondite realmente abierto")


func probar_terminacion_real() -> void:
	preparar("restaurante")
	var run := crear_run()
	var parte := buscar(run, "restaurante_cocina/heladera")
	var datos := ComponentesProyecto.objetivo("restaurante_cocina/heladera")
	var valor := parte.recompensa
	var saldo := Juego.migas_run
	for componente: Dictionary in datos.componentes:
		vaciar_componente(parte, componente)
	verificar(Juego.objetivo_proyecto_completo(datos.id) and ComponentesProyecto.objetivo_terminado(datos.id, Juego.componentes_proyecto_devorados),
		"el último componente conserva el callback de objetivo completo")
	verificar(cerca(Juego.migas_run - saldo, valor * Juego.stat("bonus_destruir") * Juego.stat("multiplicador_migas")),
		"el bonus nativo se paga una vez por objeto y no por componente")
	var captura := Juego.datos_partida()
	run.queue_free()
	await get_tree().process_frame
	Juego.restaurar_partida(captura)
	var siguiente := crear_run()
	verificar(buscar(siguiente, datos.id) == null, "un objeto terminado no vuelve a producir sus componentes")
	siguiente.queue_free()
	await get_tree().process_frame


func probar_historico_y_casa() -> void:
	preparar("museo")
	Juego.completar_destino()
	var run := crear_run()
	var nativos := 0
	for parte in run.comidas.partes:
		if parte.pieza.tipo == "biblioteca":
			nativos += 1
			verificar(not parte.pieza.has("componentes_id") and not parte.pieza.has("objetivo_proyecto"),
				"replay histórico repone bibliotecas nativas sin progreso ni resistencia de proyecto")
	verificar(nativos > 0, "el replay histórico no deja vacío el museo")
	run.queue_free()
	await get_tree().process_frame


func probar_migracion_y_fundacion() -> void:
	preparar("restaurante")
	var id := "restaurante_despensa/alacena"
	var otro := "restaurante_cocina/heladera"
	var ids := ComponentesProyecto.ids_objetivo(id)
	var datos := Juego.datos_partida()
	datos.version = 8
	datos.migas = 4321.0
	datos.objetivos_proyecto_devorados = {id: true}
	datos.erase("componentes_proyecto_devorados")
	datos.erase("tesoros_proyecto_abiertos")
	Juego.restaurar_partida(datos)
	verificar(Juego.VERSION_PARTIDA == 10 and ComponentesProyecto.objetivo_terminado(id, Juego.componentes_proyecto_devorados)
		and Juego.tesoro_proyecto_abierto(id), "v8 con objeto entero hereda componentes y escondite sin exigir repetirlo")
	verificar(not ComponentesProyecto.objetivo_terminado(otro, Juego.componentes_proyecto_devorados)
		and Juego.migas == 4321.0, "migrar no regala objetivos pendientes ni premios retroactivos")
	datos.objetivos_proyecto_devorados = {}
	for invalido in [null, [], 17, "verdadero"]:
		datos.componentes_proyecto_devorados = invalido
		datos.tesoros_proyecto_abiertos = invalido
		Juego.restaurar_partida(datos)
		verificar(Juego.componentes_proyecto_devorados.is_empty() and Juego.tesoros_proyecto_abiertos.is_empty(),
			"normaliza un contenedor de componentes/tesoros que no es diccionario")
	datos.componentes_proyecto_devorados = {ids[0]: true, ids[1]: 1, "inventado#x": true}
	datos.tesoros_proyecto_abiertos = {id: 1, "inventado": true}
	Juego.restaurar_partida(datos)
	verificar(Juego.componentes_proyecto_devorados.size() == 1 and Juego.componente_proyecto_completo(ids[0])
		and Juego.tesoros_proyecto_abiertos.is_empty(), "cargar rechaza IDs desconocidos y valores que no sean true booleano")
	verificar(Juego.registrar_tesoro_proyecto(id) and not Juego.registrar_tesoro_proyecto(id),
		"el registro de escondite es idempotente")
	var componentes := Juego.componentes_proyecto_devorados.duplicate()
	var tesoros := Juego.tesoros_proyecto_abiertos.duplicate()
	verificar(Juego.fundar_colonia() and Juego.lugar_actual == "casa" and Juego.metas_devoradas.is_empty()
		and Juego.coronas_cobradas.is_empty(), "fundar inicia otra colonia sin mantener las metas o coronas cobradas")
	verificar(Juego.componentes_proyecto_devorados == componentes and Juego.tesoros_proyecto_abiertos == tesoros,
		"fundar conserva el componente físico y el escondite ya abierto")
	datos = Juego.datos_partida()
	Juego.restaurar_partida(datos)
	verificar(Juego.componentes_proyecto_devorados == componentes and Juego.tesoros_proyecto_abiertos == tesoros,
		"guardar la colonia nueva no pierde el avance permanente")


func probar_checkpoint_y_contextos() -> void:
	preparar("restaurante")
	var id := "restaurante_despensa/alacena"
	var base := Juego.datos_partida()
	var intacta := crear_run()
	var contexto_a := intacta.recorrido.contexto_inicial
	intacta.queue_free()
	await get_tree().process_frame
	var ids := ComponentesProyecto.ids_objetivo(id)
	Juego.registrar_componente_proyecto(ids[0])
	var adelantada := crear_run()
	var contexto_b := adelantada.recorrido.contexto_inicial
	adelantada.queue_free()
	await get_tree().process_frame
	Juego.registrar_tesoro_proyecto(id)
	var abierta := crear_run()
	var contexto_c := abierta.recorrido.contexto_inicial
	abierta.queue_free()
	await get_tree().process_frame
	verificar(contexto_a != contexto_b and contexto_b != contexto_c and contexto_a != contexto_c,
		"el contexto de récord distingue mueble entero componente comido y escondite abierto")
	var registro := {"destino": "restaurante", "version_mapa": Mundos.VERSION_CONTENIDO,
		"dieta": 3, "territorio": 12000.0, "completa": false, "recorrido": contexto_a}
	var clave_a := Juego.clave_limpieza(registro)
	registro.recorrido = contexto_b
	verificar(clave_a != Juego.clave_limpieza(registro), "las limpiezas con distinto trabajo inicial no compiten por el mismo récord")
	base.migas = 7654.0
	base.metas_devoradas = {"restaurante": true}
	var flags: Dictionary = {}
	for componente_id in ids:
		flags[componente_id] = true
	base.componentes_proyecto_devorados = flags
	base.tesoros_proyecto_abiertos = {}
	Juego.restaurar_partida(base)
	verificar(Juego.objetivo_proyecto_completo(id) and Juego.meta_destino_devorada("restaurante")
		and not Juego.coronas_cobradas.has("restaurante"), "el checkpoint del último componente recupera el objeto sin perder la meta pendiente")
	var saldo := Juego.migas
	var recuperada := crear_run()
	verificar(buscar(recuperada, id) == null and Juego.migas == saldo and is_zero_approx(Juego.migas_run),
		"recuperar el checkpoint no repone cuerpo ni paga bonus o alijo retroactivo")
	verificar(not recuperada.objetivo_completado and not Juego.proyectos_completos("restaurante"),
		"un objeto recuperado no completa los demás proyectos ni inventa una corona")
	recuperada.queue_free()
	await get_tree().process_frame


func probar_casa_opcional() -> void:
	preparar("casa")
	var run := crear_run()
	verificar(is_instance_valid(run.objetivo_practica)
		and run.objetivo_practica.pieza.get("componentes_id", "") == "casa/carton_inicial",
		"el cartón cercano ofrece partes opcionales sin tocar la primera comida")
	var silla: PiezaCasa = null
	for parte in run.comidas.partes:
		if parte.pieza.get("perfil", "") == "silla_inicial":
			silla = parte
	verificar(is_instance_valid(silla) and not silla.pieza.has("componentes_id"),
		"la primera silla sigue disponible como recurso normal para el primer retorno")
	verificar(is_instance_valid(silla) and silla.resumen_componentes().is_empty(),
		"un mueble sin componentes no muestra una línea vacía de cero sobre cero")
	run.queue_free()
	await get_tree().process_frame

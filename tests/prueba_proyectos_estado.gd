extends Node
## Progreso por objetos enteros: historial, coronas por colonia y migración.
## No extrae material por script ni carga/escribe la partida del jugador.
var total := 0
var fallas := 0
var _cambios := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	var existia := FileAccess.file_exists(Juego.RUTA_PARTIDA)
	var huella := hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) if existia else 0
	Juego.progreso_cambio.connect(_contar_cambio)
	probar_catalogo_y_registro()
	probar_historial_y_meta()
	probar_migracion_y_validacion()
	probar_proxima_meta()
	probar_contexto_limpieza()
	Juego.progreso_cambio.disconnect(_contar_cambio)
	Juego.reiniciar_estado()
	var intacta := FileAccess.file_exists(Juego.RUTA_PARTIDA) == existia
	if existia:
		intacta = intacta and hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) == huella
	verificar(not Juego.guardado_habilitado and intacta, "las pruebas no escriben ni alteran la partida real")
	print("Proyectos, estado y migración: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func _contar_cambio() -> void:
	_cambios += 1


func probar_catalogo_y_registro() -> void:
	Juego.reiniciar_estado()
	verificar(Juego.VERSION_PARTIDA == 9 and Juego.datos_partida().version == 9, "el guardado identifica el esquema9 de componentes")
	verificar(ProyectosCampana.todos().size() == 20 and Juego.proyectos_completos("casa"), "hay veinte proyectos y la casa conserva su arranque sin proyectos")
	verificar(not Juego.proyectos_completos("inventado") and not Juego.proyecto_completo("inventado"), "IDs desconocidos no simulan proyectos o destinos terminados")
	verificar(Juego.resumen_proyectos("inventado").is_empty() and Juego.entradas_proyectos("inventado") == 0, "consultar un destino desconocido no concede entradas")
	var saldo := Juego.migas
	var coronas := Juego.coronas
	var legado := Juego.legado
	var anterior := _cambios
	verificar(not Juego.registrar_objetivo_proyecto("inventado/objeto") and _cambios == anterior and Juego.objetivos_proyecto_devorados.is_empty(), "registrar un objetivo desconocido no muta estado ni emite progreso")
	var resumen := Juego.resumen_proyectos("restaurante")
	verificar(resumen.size() == 4, "cada destino de campaña ofrece cuatro proyectos")
	var proyecto: Dictionary = resumen[0]
	var objetivo: Dictionary = proyecto.objetivos[0]
	verificar(proyecto.completados == 0 and proyecto.total == proyecto.objetivos.size() and proyecto.total >= 1, "el resumen cuenta objetos enteros pendientes")
	verificar(Juego.registrar_objetivo_proyecto(objetivo.id) and Juego.objetivo_proyecto_completo(objetivo.id) and _cambios == anterior + 1, "un objetivo real se registra una vez y emite un único cambio")
	verificar(not Juego.registrar_objetivo_proyecto(objetivo.id) and _cambios == anterior + 1, "repetir el mismo objetivo es idempotente")
	verificar(Juego.migas == saldo and Juego.coronas == coronas and Juego.legado == legado and Juego.migas_run == 0, "registrar progreso no inventa ingresos, coronas ni legado")
	var parcial := Juego.resumen_proyectos("restaurante")
	verificar(parcial[0].completados == 1 and parcial[0].total == proyecto.total, "el resumen conserva el avance parcial entre objetos del proyecto")
	resumen[0].nombre = "mutado"
	resumen[0].objetivos[0].id = "mutado/objeto"
	var original := ProyectosCampana.por_id(proyecto.id)
	verificar(original.nombre != "mutado" and original.objetivos[0].id != "mutado/objeto", "las fichas no pueden modificar ni el proyecto ni sus objetivos originales")
	var logistica: Dictionary = {}
	for candidato in ProyectosCampana.del_destino("restaurante"):
		if candidato.entrada > 0:
			logistica = candidato
	verificar(not logistica.is_empty(), "el catálogo declara un proyecto logístico con una entrada")
	if logistica.is_empty():
		return
	Juego.reiniciar_estado()
	for i in range(logistica.objetivos.size() - 1):
		Juego.registrar_objetivo_proyecto(logistica.objetivos[i].id)
	verificar(not Juego.proyecto_completo(logistica.id) and Juego.entradas_proyectos("restaurante") == 0, "un proyecto incompleto no da su entrada aunque falte un solo objeto")
	Juego.registrar_objetivo_proyecto(logistica.objetivos.back().id)
	verificar(Juego.proyecto_completo(logistica.id) and Juego.entradas_proyectos("restaurante") == logistica.entrada and Juego.entradas_proyectos("museo") == 0, "la entrada se concede una vez y sólo en el destino del proyecto")


func probar_historial_y_meta() -> void:
	Juego.reiniciar_estado()
	Juego.lugar_actual = "restaurante"
	var anterior := _cambios
	verificar(Juego.registrar_meta_destino() and Juego.meta_destino_devorada("restaurante") and _cambios == anterior + 1, "la meta canónica devorada queda registrada en la colonia")
	verificar(not Juego.registrar_meta_destino() and _cambios == anterior + 1, "registrar de nuevo la meta no repite cambios")
	verificar(Juego.coronas == 0 and Juego.coronas_cobradas.is_empty() and Juego.lugares_completados.is_empty(), "devorar la meta antes de sus proyectos no conquista ni cobra coronas")
	var pendiente: Dictionary = JSON.parse_string(JSON.stringify(Juego.datos_partida()))
	Juego.reiniciar_estado()
	Juego.restaurar_partida(pendiente)
	verificar(Juego.meta_destino_devorada("restaurante") and not Juego.proyectos_completos("restaurante") and Juego.coronas == 0 and Juego.coronas_cobradas.is_empty(), "una meta devorada pendiente sobrevive a cargar sin coronas ni proyectos inventados")
	# Volver al contexto administrativo: esta fixture no conquistó la casa.
	Juego.lugar_actual = "restaurante"
	for objetivo in ProyectosCampana.objetivos_destino("restaurante"):
		Juego.registrar_objetivo_proyecto(objetivo.id)
	verificar(Juego.proyectos_completos("restaurante") and Juego.coronas == 0, "terminar los proyectos deja la conquista a la coordinación explícita de la run")
	var pagadas := Juego.completar_destino()
	verificar(pagadas == int(Mundos.INFO.restaurante.coronas) and Juego.coronas_cobradas.has("restaurante") and Juego.meta_destino_devorada("restaurante"), "conquistar registra la meta y paga sus coronas por colonia")
	var coronas := Juego.coronas
	var saldo := Juego.migas
	verificar(Juego.completar_destino() == 0 and Juego.coronas == coronas and Juego.migas == saldo, "la misma conquista no duplica coronas ni ingresos")
	var guardado: Dictionary = JSON.parse_string(JSON.stringify(Juego.datos_partida()))
	var cantidad := Juego.objetivos_proyecto_devorados.size()
	Juego.reiniciar_estado()
	Juego.restaurar_partida(guardado)
	verificar(Juego.objetivos_proyecto_devorados.size() == cantidad and Juego.proyectos_completos("restaurante") and Juego.meta_destino_devorada("restaurante"), "objetivos enteros y meta pendiente sobreviven al roundtripJSON")
	verificar(Juego.fundar_colonia() and Juego.lugar_actual == "casa" and Juego.metas_devoradas.is_empty() and Juego.coronas_cobradas.is_empty(), "fundar vuelve a casa y reinicia sólo las metas y coronas de esta colonia")
	verificar(Juego.objetivos_proyecto_devorados.size() == cantidad and Juego.proyectos_completos("restaurante") and not Juego.meta_destino_devorada("restaurante"), "los proyectos históricos no se exigen otra vez tras fundar")
	Juego.lugar_actual = "museo"
	Juego.completar_destino()
	verificar(Juego.proyectos_completos("museo") and Juego.meta_destino_devorada("museo"), "la API administrativa de conquista completa todos los objetos para las fixtures")
	Juego.lugar_actual = "inventado"
	verificar(not Juego.registrar_meta_destino() and Juego.completar_destino() == 0, "un destino inexistente no puede registrar meta ni coronas")
	Juego.reiniciar_estado()
	verificar(Juego.objetivos_proyecto_devorados.is_empty() and Juego.metas_devoradas.is_empty(), "empezar desde cero borra ambos registros")


func probar_migracion_y_validacion() -> void:
	var vieja := {"version": 7, "migas": 4321.0, "coronas": 2, "legado": 9,
		"destinos": {"restaurante": true}, "coronas_cobradas": {"casa": true}, "lugar": "restaurante"}
	Juego.restaurar_partida(vieja)
	verificar(Juego.proyectos_completos("restaurante") and not Juego.proyectos_completos("museo"), "una partida vieja conserva sólo los proyectos de sus victorias históricas")
	verificar(Juego.meta_destino_devorada("casa") and not Juego.meta_destino_devorada("restaurante"), "la migración de metas distingue coronas actuales de victorias históricas")
	verificar(Juego.migas == 4321.0 and Juego.coronas == 2 and Juego.legado == 9 and Juego.lugar_actual == "restaurante", "migrar no paga alijos, dinero ni coronas retroactivas ni cambia el viaje válido")
	var sin_coronas := vieja.duplicate(true)
	sin_coronas.erase("coronas_cobradas")
	Juego.restaurar_partida(sin_coronas)
	verificar(Juego.meta_destino_devorada("restaurante"), "la migración antigua sin coronas explícitas sigue tomando las victorias conocidas como cobradas")
	var objetivos := ProyectosCampana.objetivos_destino("restaurante")
	var objetivo_museo: Dictionary = ProyectosCampana.objetivos_destino("museo")[0]
	var parcial: Dictionary = {}
	parcial[objetivos[0].id] = true
	parcial[objetivo_museo.id] = true
	for registro in [{}, parcial]:
		var historica := vieja.duplicate(true)
		historica.version = 8
		historica.objetivos_proyecto_devorados = registro
		var cambios_antes := _cambios
		Juego.restaurar_partida(historica)
		verificar(Juego.proyectos_completos("restaurante") and not Juego.proyectos_completos("museo"), "una captura v8 histórica con proyectos vacíos o parciales conserva la victoria sin bloquear su reconquista")
		verificar(Juego.objetivo_proyecto_completo(objetivo_museo.id) == registro.has(objetivo_museo.id), "normalizar el historial conserva sólo el avance explícito de los destinos todavía no conquistados")
		verificar(Juego.migas == 4321.0 and Juego.coronas == 2 and Juego.legado == 9 and _cambios == cambios_antes and not Juego.meta_destino_devorada("restaurante"), "normalizar la victoria histórica no paga premios ni emite eventos ni completa la meta de la colonia actual")
	var corrupta := {"version": 8, "objetivos_proyecto_devorados": {}, "metas_devoradas": {
		"restaurante": true, "museo": 1, "obelisco": "true", "eiffel": {}, "inventado": true}}
	corrupta.objetivos_proyecto_devorados[objetivos[0].id] = true
	corrupta.objetivos_proyecto_devorados[objetivos[1].id] = 1
	corrupta.objetivos_proyecto_devorados[objetivos[2].id] = "true"
	corrupta.objetivos_proyecto_devorados["inventado/objeto"] = true
	corrupta.objetivos_proyecto_devorados[17] = true
	Juego.restaurar_partida(corrupta)
	verificar(Juego.objetivos_proyecto_devorados.size() == 1 and Juego.objetivo_proyecto_completo(objetivos[0].id), "el cargador acepta sólo IDs reales con valores booleanos verdaderos")
	verificar(Juego.metas_devoradas.size() == 1 and Juego.meta_destino_devorada("restaurante"), "las metas cargadas ignoran IDs y tipos inválidos")
	for valor in [[], "texto", 12, null]:
		Juego.restaurar_partida({"version": 8, "objetivos_proyecto_devorados": valor, "metas_devoradas": valor})
		verificar(Juego.objetivos_proyecto_devorados.is_empty() and Juego.metas_devoradas.is_empty(), "contenedores inválidos de proyectos y metas se descartan sin inferir progreso")
	Juego.registrar_objetivo_proyecto(objetivos[0].id)
	var propia := Juego.datos_partida()
	Juego.restaurar_partida(propia)
	verificar(Juego.objetivo_proyecto_completo(objetivos[0].id), "restaurar una captura en memoria no vacía sus propios diccionarios antes de leerlos")
	propia.objetivos_proyecto_devorados.clear()
	verificar(Juego.objetivo_proyecto_completo(objetivos[0].id), "la captura de proyectos devuelta por datos_partida no comparte el estado mutable")


func probar_proxima_meta() -> void:
	Juego.reiniciar_estado()
	verificar(Juego.proxima_meta().tipo != "proyecto", "la próxima meta inicial de la casa no cambia por los proyectos de viaje")
	Juego.lugar_actual = "restaurante"
	verificar(Juego.proxima_meta().tipo in ["nivel", "migas"], "sin dieta para los objetivos pendientes se sigue guiando hacia la compra de material")
	Juego.niveles.mordida_madera = 1
	Juego._cache_stats.clear()
	var recomendada := Juego.proxima_meta()
	var trabajable := false
	if recomendada.tipo == "proyecto":
		for objetivo in ProyectosCampana.por_id(recomendada.id).objetivos:
			trabajable = trabajable or MaterialesCasa.nivel_tipo(objetivo.tipo) <= int(Juego.stat("materiales"))
	verificar(recomendada.tipo == "proyecto" and recomendada.accion == "mapa" and trabajable and recomendada.objetivo >= 1, "un proyecto de madera trabajable aparece antes de exigir resistentes o muros")
	for objetivo in ProyectosCampana.objetivos_destino("restaurante"):
		if MaterialesCasa.nivel_tipo(objetivo.tipo) <= 1:
			Juego.registrar_objetivo_proyecto(objetivo.id)
	verificar(Juego.proxima_meta().tipo in ["nivel", "migas"], "si quedan sólo objetos de una dieta futura vuelve a señalar su desbloqueo")
	Juego.niveles.mordida_resistente = 1
	Juego.niveles.mordida_muros = 1
	Juego._cache_stats.clear()
	for objetivo in ProyectosCampana.objetivos_destino("restaurante"):
		Juego.registrar_objetivo_proyecto(objetivo.id)
	verificar(Juego.proxima_meta().tipo == "objetivo", "terminados los proyectos vuelve a señalar el gran objetivo canónico")
	Juego.completar_destino()
	verificar(Juego.proxima_meta().tipo == "viaje" and Juego.proxima_meta().id == "museo", "conquista y proyectos completos permiten señalar el viaje siguiente")


func probar_contexto_limpieza() -> void:
	var legado := {"destino": "restaurante", "version_mapa": 5, "dieta": 3, "territorio": 620.0,
		"completa": false, "tiempo_limpieza": 8.0, "tiempo_total": 9.0, "migas": 10.0,
		"produccion": 1.0, "pendiente": 0.0}
	var original := Juego._validar_limpieza(legado)
	verificar(not original.is_empty() and original.recorrido == "" and Juego.clave_limpieza(original) == "restaurante:v5:d3:r620:0", "los registros sin recorrido conservan su clave histórica exacta")
	var nuevo := legado.duplicate(true)
	nuevo.recorrido = "a".repeat(64)
	var validado := Juego._validar_limpieza(nuevo)
	verificar(not validado.is_empty() and validado.recorrido == nuevo.recorrido and Juego.clave_limpieza(validado) == Juego.clave_limpieza(original) + ":" + nuevo.recorrido, "el contexto inicial de proyectos separa la clave de una expedición intacta")
	for recorrido in [17, true, [], null, "x".repeat(65)]:
		nuevo.recorrido = recorrido
		verificar(Juego._validar_limpieza(nuevo).is_empty(), "un recorrido de tipo o longitud inválidos se rechaza")
	Juego.reiniciar_estado()
	Juego.runs_jugadas = 1
	nuevo.recorrido = "recorrido_qa"
	verificar(Juego.registrar_limpieza(nuevo) and Juego.archivo_expediciones[0].recorrido == "recorrido_qa", "el archivo conserva el contexto de proyectos al registrar la limpieza")
	var datos: Dictionary = JSON.parse_string(JSON.stringify(Juego.datos_partida()))
	Juego.restaurar_partida(datos)
	verificar(Juego.archivo_expediciones.size() == 1 and Juego.archivo_expediciones[0].recorrido == "recorrido_qa", "el recorrido del archivo sobrevive al guardado y carga")


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", detalle)

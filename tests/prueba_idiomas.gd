extends Node
## Idiomas: todo texto visible del juego tiene su traducción en idiomas/en.po,
## las traducciones respetan los %d / %s del original (si no, el formato rompe
## en inglés) y la interfaz en inglés no muestra restos en español.
##   godot --headless --fixed-fps 60 --path . res://tests/prueba_idiomas.tscn
## Si falta una traducción, la prueba imprime la línea exacta para pegar en el .po.
const RUTA_PO := "res://idiomas/en.po"
const CARPETAS_CODIGO := ["res://global", "res://hormigas", "res://mundo", "res://ui"]
## Palabras que delatan texto en español en una interfaz en inglés.
const PALABRAS_ESPANOL := ["de", "la", "el", "los", "las", "del", "y", "con", "para", "por", "una", "que",
	"migas", "hormigas", "mejoras", "nivel", "colonia", "comida", "jalea", "reina", "gran", "destino",
	"obreras", "castas", "viajes", "sonido", "volver", "jugar", "salir", "partida"]
## Nombres propios que se escriben igual en los dos idiomas.
const NOMBRES_PROPIOS := ["Hormigas", "Español"]
var fallas := 0
var total := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Sonido.silenciado = true
	var po: Translation = load(RUTA_PO)
	verificar(po != null, "existe %s" % RUTA_PO)
	if po:
		probar_catalogo(po)
		await probar_interfaz_en_ingles()
	Juego.usar_idioma("es")
	Juego.reiniciar_estado()
	print("Idiomas: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


# =====================================================================
# El catálogo: claves completas, sin sobrantes y con el mismo formato
# =====================================================================

func probar_catalogo(po: Translation) -> void:
	var claves := claves_del_juego()
	verificar(claves.size() > 300, "se juntaron los textos del juego (%d)" % claves.size())
	var faltan: Array[String] = []
	for clave in claves:
		if po.get_message(clave) == "":
			faltan.append(clave)
	verificar(faltan.is_empty(), "todos los textos tienen traducción al inglés (faltan %d)" % faltan.size())
	for clave in faltan:
		print("    msgid %s\n    msgstr \"\"\n" % JSON.stringify(clave))
	var sobran: Array[String] = []
	for mensaje in po.get_message_list():
		if not claves.has(mensaje):
			sobran.append(mensaje)
	verificar(sobran.is_empty(), "en.po no tiene traducciones de textos que ya no existen (%d)" % sobran.size())
	for mensaje in sobran:
		print("    sobra: %s" % JSON.stringify(mensaje))
	# Sólo los textos del código se formatean con %: en los de /datos un
	# "12% más rápido" es literal.
	var mal_formato: Array[String] = []
	for clave in claves:
		if claves[clave] != "codigo":
			continue
		var traduccion := String(po.get_message(clave))
		if traduccion != "" and formatos(clave) != formatos(traduccion):
			mal_formato.append(clave)
	verificar(mal_formato.is_empty(), "cada traducción usa los mismos %d / %s, en el mismo orden")
	for clave in mal_formato:
		print("    formato distinto: %s → %s" % [JSON.stringify(clave), JSON.stringify(String(po.get_message(clave)))])


## Lo que el jugador puede llegar a leer: los tr("…") del código y los textos
## de las tablas (CSV) y constantes que se traducen al mostrarse.
func claves_del_juego() -> Dictionary:
	var claves := {}
	var regex := RegEx.create_from_string("\\btr\\(\"((?:[^\"\\\\]|\\\\.)*)\"\\)")
	for carpeta in CARPETAS_CODIGO:
		for ruta in _scripts(carpeta):
			for m in regex.search_all(FileAccess.get_file_as_string(ruta)):
				claves[m.get_string(1).c_unescape()] = "codigo"
	# La sesión jugable F6 es una herramienta de pruebas, pero su interfaz
	# también se entrega en ambos idiomas. No escanear los fixtures completos.
	var herramienta := "res://tests/registro_sesion_casa.gd"
	if FileAccess.file_exists(herramienta):
		for m in regex.search_all(FileAccess.get_file_as_string(herramienta)):
			claves[m.get_string(1).c_unescape()] = "codigo"
	for m in Juego.mejoras:
		_sumar(claves, [m.nombre, m.descripcion])
	for c in Juego.castas:
		_sumar(claves, [c.nombre, c.rol, c.descripcion, c.habilidad])
	for c in Juego.comidas:
		_sumar(claves, [c.nombre])
	for n in Juego.nodos_jalea:
		_sumar(claves, [n.nombre, n.descripcion])
	for d in Juego.decretos:
		_sumar(claves, [d.nombre, d.descripcion])
	for a in Juego.adaptaciones:
		_sumar(claves, [a.nombre, a.descripcion])
	for e in EvolucionesHormiga.DATOS.values():
		_sumar(claves, [e.nombre, e.detalle])
	_sumar(claves, ReglasDestino.DESCRIPCIONES.values())
	for h in Juego.HITOS.values():
		_sumar(claves, [h.nombre, h.detalle, h.premio])
	_sumar(claves, Juego.REVELABLES.values())
	for id in Mundos.ORDEN:
		var info: Dictionary = Mundos.INFO[id]
		_sumar(claves, [info.nombre, info.subtitulo, info.meta])
		for a in Mundos.plano(id).ambientes:
			_sumar(claves, [a.nombre])
	_sumar(claves, MaterialesCasa.NIVELES)
	_sumar(claves, MaterialesCasa.NOMBRES.values())
	var tienda := load("res://ui/tienda.gd")
	for sala in tienda.SALAS.values():
		_sumar(claves, [sala.titulo, sala.detalle])
	_sumar(claves, tienda.NOMBRES_PESTANAS.values())
	for preparacion in VentanaFundar.PREPARACIONES.values():
		_sumar(claves, [preparacion.nombre, preparacion.detalle])
	return claves


func _sumar(claves: Dictionary, textos: Array) -> void:
	for texto in textos:
		if String(texto) != "" and not claves.has(String(texto)):
			claves[String(texto)] = "datos"


func _scripts(carpeta: String) -> Array[String]:
	var rutas: Array[String] = []
	for archivo in DirAccess.get_files_at(carpeta):
		if archivo.ends_with(".gd"):
			rutas.append(carpeta.path_join(archivo))
	for sub in DirAccess.get_directories_at(carpeta):
		rutas.append_array(_scripts(carpeta.path_join(sub)))
	return rutas


## Los marcadores de formato de un texto, en orden: "%d de %s" -> ["%d", "%s"].
func formatos(texto: String) -> Array[String]:
	var lista: Array[String] = []
	var regex := RegEx.create_from_string("%[-+ 0#]*\\d*(?:\\.\\d+)?[sdfxXcoi%]")
	for m in regex.search_all(texto):
		lista.append(m.get_string())
	return lista


# =====================================================================
# La interfaz en inglés: armar pantallas y buscar restos en español
# =====================================================================

func probar_interfaz_en_ingles() -> void:
	Juego.usar_idioma("es")
	verificar(tr("Mejoras") == "Mejoras", "en español se ve el texto original (el idioma de respaldo es el español)")
	Juego.usar_idioma("en")
	verificar(tr("Mejoras") == "Upgrades", "en inglés, tr() traduce")
	_partida_avanzada()
	var textos := PackedStringArray()
	var tienda: Control = preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await get_tree().process_frame
	for rama in tienda.SALAS:
		tienda._seleccionar(rama)
		textos.append_array(_textos(tienda))
	tienda._cambiar_pestana("castas")
	for c in Juego.castas:
		if c.comprable:
			tienda._panel_castas._seleccionar(c.id)
			textos.append_array(_textos(tienda._panel_castas))
	tienda._cambiar_pestana("viajes")
	await get_tree().process_frame
	textos.append_array(_textos(tienda._panel_viajes))
	tienda._cambiar_pestana("legado")
	await get_tree().process_frame
	textos.append_array(_textos(tienda._panel_legado))
	tienda._panel_legado._pedir_fundacion()
	textos.append_array(_textos(tienda._panel_legado._confirmar))
	tienda.abrir_configuracion()
	textos.append_array(_textos(tienda._ventana))
	tienda.abrir_estadisticas()
	textos.append_array(_textos(tienda._ventana))
	tienda.queue_free()
	await get_tree().process_frame
	var menu: Control = preload("res://ui/menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	textos.append_array(_textos(menu))
	menu.queue_free()
	Juego.runs_jugadas = 0
	menu = preload("res://ui/menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	textos.append_array(_textos(menu))
	menu.queue_free()
	Juego.runs_jugadas = 40
	await get_tree().process_frame
	for id in Mundos.ORDEN:
		Juego.lugar_actual = id
		var run: Run = preload("res://mundo/run.tscn").instantiate()
		add_child(run)
		await get_tree().process_frame
		await get_tree().process_frame
		run.hud._actualizar_meta()
		for comida in run.comidas.lista.slice(0, 40):
			if is_instance_valid(comida):
				run.hud.mostrar_inspeccion(comida)
				textos.append(run.hud._lbl_objetivo.text)
		run.hud.pausar()
		textos.append_array(_textos(run.hud))
		run.hud.reanudar()
		run.hud.mostrar_fin()
		await get_tree().process_frame
		textos.append_array(_textos(run.hud))
		run.queue_free()
		await get_tree().process_frame
	var en_espanol := PackedStringArray()
	for texto in textos:
		if _parece_espanol(texto) and not en_espanol.has(texto):
			en_espanol.append(texto)
	verificar(textos.size() > 200, "se revisaron los textos de las pantallas (%d)" % textos.size())
	verificar(en_espanol.is_empty(), "la interfaz en inglés no muestra texto en español (%d restos)" % en_espanol.size())
	for texto in en_espanol:
		print("    en español: %s" % JSON.stringify(texto))


func _partida_avanzada() -> void:
	Juego.reiniciar_estado()
	Juego.runs_jugadas = 40
	Juego.lugares_completados = {"casa": true, "restaurante": true, "museo": true, "obelisco": true, "coliseo": true}
	Juego.coronas_cobradas = {"casa": true}
	Juego.coronas = 3
	Juego.fundaciones = 2
	Juego.legado = 40
	Juego.jalea = 14
	Juego.migas_colonia = 4.2e9
	Juego.migas = 3.1e8
	Juego.niveles_jalea = {"obreras_reales": 3, "despensa": 1, "linaje": 1}
	Juego.niveles = {"mas_obreras": 30, "mandibulas": 49, "pisada": 24, "mordida_madera": 1, "buche": 10}
	Juego.hitos = {"primera_silla": true}
	for id in Juego.REVELABLES:
		Juego.descubiertos[id] = false
	Juego._cache_stats.clear()


func _textos(nodo: Node) -> PackedStringArray:
	var salida := PackedStringArray()
	if nodo is Label or nodo is Button:
		salida.append(nodo.text)
	if nodo is Control and nodo.tooltip_text != "":
		salida.append(nodo.tooltip_text)
	if nodo is AcceptDialog:
		salida.append_array([nodo.title, nodo.dialog_text, nodo.ok_button_text])
	if nodo is ConfirmationDialog:
		salida.append(nodo.cancel_button_text)
	for hijo in nodo.get_children():
		salida.append_array(_textos(hijo))
	return salida


func _parece_espanol(texto: String) -> bool:
	for nombre in NOMBRES_PROPIOS:
		texto = texto.replace(nombre, "")
	if RegEx.create_from_string("[áéíóúñ¡¿]").search(texto.to_lower()):
		return true
	for palabra in RegEx.create_from_string("[a-záéíóúñ]+").search_all(texto.to_lower()):
		if palabra.get_string() in PALABRAS_ESPANOL:
			return true
	return false


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)

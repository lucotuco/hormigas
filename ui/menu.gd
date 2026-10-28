extends Control
## Menú principal: jugar, estadísticas, configuración y salir. De fondo, el
## destino actual visto desde arriba con una fila de hormigas.

const ESCENA_RUN := "res://mundo/run.tscn"
const ESCENA_TIENDA := "res://ui/tienda.tscn"
## El nombre del juego no se traduce.
const NOMBRE_JUEGO := "Hormigas"

var _boton_jugar: Button
var _ventana: VentanaModal


class FondoDestino extends Control:
	## El plano del destino actual, dibujado una sola vez. Se dibuja en un
	## Node2D escalado porque los dibujos de muebles reinician draw_set_transform.
	var _lienzo := Lienzo.new()

	func _ready() -> void:
		add_child(_lienzo)
		resized.connect(_ajustar)
		_ajustar()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("161a16"))

	func _ajustar() -> void:
		var limites := PlanoCasa.limites()
		var escala := maxf(size.x / limites.size.x, size.y / limites.size.y) * 1.08
		_lienzo.scale = Vector2.ONE * escala
		_lienzo.position = size * 0.5 - limites.get_center() * escala + Vector2(size.x * 0.14, 0)


class Lienzo extends Node2D:
	func _draw() -> void:
		for a in PlanoCasa.ambientes():
			draw_rect(a.rect, a.color)
		DibujoCasa.dibujar(self, true)
		# En los destinos, muebles y muros los dibuja cada pieza en la run.
		if Juego.lugar_actual != "casa":
			for m in PlanoCasa.muebles():
				DibujoCasa.mueble(self, m)
			for r in PlanoCasa.paredes():
				DibujoCasa.pared(self, r)


class FilaHormigas extends Control:
	## Hormigas que cruzan la pantalla en fila, algunas cargando migas.
	var reloj := 0.0
	const CANTIDAD := 46

	func _process(delta: float) -> void:
		reloj += delta
		queue_redraw()

	func _draw() -> void:
		var largo := size.x + 200.0
		for i in CANTIDAD:
			var avance := fposmod(reloj * 46.0 + i * largo / CANTIDAD, largo) - 100.0
			var y := size.y * 0.78 + sin(avance * 0.012 + 1.3) * 46.0 + sin(i * 2.1) * 6.0
			var proximo := Vector2(avance + 4.0, size.y * 0.78 + sin((avance + 4.0) * 0.012 + 1.3) * 46.0 + sin(i * 2.1) * 6.0)
			var pos := Vector2(avance, y)
			draw_set_transform(pos, (proximo - pos).angle(), Vector2.ONE * 2.6)
			AspectoHormiga.dibujar(self, "obrera", Color("392b22"), reloj * 14.0 + i, i % 3 == 0, Color("e9c98a"))
		draw_set_transform(Vector2.ZERO)


func _ready() -> void:
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fondo := FondoDestino.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)
	var velo := ColorRect.new()
	velo.color = Color(0.06, 0.07, 0.06, 0.55)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(velo)
	var fila := FilaHormigas.new()
	fila.set_anchors_preset(Control.PRESET_FULL_RECT)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fila)

	var columna_fondo := PanelContainer.new()
	columna_fondo.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	columna_fondo.custom_minimum_size.x = 440
	columna_fondo.add_theme_stylebox_override("panel", Estilo.caja(Color(0.07, 0.08, 0.07, 0.88), 0, Color.TRANSPARENT, 0, 48))
	add_child(columna_fondo)
	var columna := VBoxContainer.new()
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	columna.add_theme_constant_override("separation", 12)
	columna_fondo.add_child(columna)
	columna.add_child(Estilo.etiqueta(NOMBRE_JUEGO, 64, Estilo.ACENTO, 6))
	var lema := Estilo.etiqueta(tr("Una colonia. Una casa entera para comer."), 16, Estilo.TEXTO_SUAVE)
	lema.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(lema)
	var progreso := Estilo.etiqueta(_resumen(), 13, Color("b8c993"))
	progreso.name = "Resumen"
	progreso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(progreso)
	var espacio := Control.new()
	espacio.custom_minimum_size.y = 18
	columna.add_child(espacio)
	_boton_jugar = _boton(columna, tr("Continuar") if Juego.runs_jugadas > 0 else tr("Jugar"), jugar, true)
	_boton(columna, tr("Estadísticas"), abrir_estadisticas)
	_boton(columna, tr("Configuración"), abrir_configuracion)
	_boton(columna, tr("Salir"), func() -> void: get_tree().quit())
	_boton_jugar.grab_focus()


func _boton(columna: VBoxContainer, texto: String, accion: Callable, principal := false) -> Button:
	var boton := Estilo.boton(texto, 20 if principal else 17, Color("46593e") if principal else Color("262e25"), Color("94b47e") if principal else Color("4b5945"))
	boton.custom_minimum_size = Vector2(300, 58 if principal else 48)
	boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	boton.pressed.connect(accion)
	columna.add_child(boton)
	return boton


func _resumen() -> String:
	if Juego.runs_jugadas == 0:
		return tr("Guiá a tus hormigas, pisá migas y comete la casa entera.")
	var lineas := PackedStringArray()
	lineas.append(tr("Destino: %s") % tr(Mundos.INFO[Juego.lugar_actual].nombre))
	var migas := Juego.formatear(Juego.estadistica("migas_totales"))
	lineas.append(tr("1 expedición · %s migas juntadas") % migas if Juego.runs_jugadas == 1 else tr("%d expediciones · %s migas juntadas") % [Juego.runs_jugadas, migas])
	if Juego.fundaciones > 0:
		var colonias := tr("1 colonia fundada") if Juego.fundaciones == 1 else tr("%d colonias fundadas") % Juego.fundaciones
		lineas.append(tr("%s · %d de jalea real") % [colonias, Juego.jalea])
	return "\n".join(lineas)


## La primera vez se entra directo a la casa; después, al hormiguero.
func escena_de_jugar() -> String:
	return ESCENA_RUN if Juego.runs_jugadas == 0 else ESCENA_TIENDA


func jugar() -> void:
	Sonido.tocar("clic", 1.0)
	get_tree().change_scene_to_file(escena_de_jugar())


func abrir_estadisticas() -> void:
	_abrir(PanelEstadisticas.new())


func abrir_configuracion() -> void:
	var panel := PanelConfiguracion.new()
	panel.idioma_cambiado.connect(func() -> void: get_tree().reload_current_scene())
	_abrir(panel)


func _abrir(ventana: VentanaModal) -> void:
	if is_instance_valid(_ventana):
		_ventana.queue_free()
	Sonido.tocar("clic", 0.9)
	_ventana = ventana
	add_child(ventana)
	ventana.cerrada.connect(func() -> void: _boton_jugar.grab_focus())

extends Node
var fallas := 0
var total := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Juego.reiniciar_estado()
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await get_tree().process_frame
	var textos := _textos(tienda)
	verificar(not "Un hogar que crece" in textos and not "ENTRE RAÍCES Y MIGAS" in textos, "el encabezado no contiene frases de relleno")
	verificar(not "detalle" in tienda.SALAS.Colonia and not "detalle" in tienda.SALAS.Feromonas, "los accesos de ramas tampoco contienen eslóganes en sus tooltips")
	verificar(not FileAccess.file_exists("res://mundo/recorte_pieza.gdshader"), "se retiró el shader de franjas viejo que ya no tenía consumidores")
	var arte := FileAccess.get_file_as_string("res://ui/arte_camara.gd")
	verificar(not "_objeto_recuerdo" in arte and not "canasto" in arte and not "transporte" in arte, "el arte del hormiguero no contiene canastos ni miniaturas turísticas")
	tienda.queue_free()
	await get_tree().process_frame
	var vuelo := VueloMigas.new()
	add_child(vuelo)
	var antes := Juego.datos_partida().duplicate(true)
	var nodos := vuelo.get_child_count()
	for tanda in 100:
		vuelo.emitir(Vector2.ZERO, Vector2(400, 100), 100)
		verificar(vuelo.cantidad <= VueloMigas.MAXIMO, "pool de vuelo limitado en tanda %d" % tanda)
		vuelo._process(1.0)
	verificar(vuelo.get_child_count() == nodos and nodos == 0 and vuelo.migas.size() == VueloMigas.MAXIMO, "cien tandas no crean nodos ni tweens por miga")
	verificar(vuelo.cantidad == 0 and not vuelo.is_processing(), "el pool vacío no sigue procesando")
	verificar(Juego.datos_partida() == antes, "el feedback no acredita recursos ni modifica el guardado")
	vuelo.emitir(Vector2.ZERO, Vector2.ONE, 20)
	vuelo.limpiar()
	verificar(vuelo.cantidad == 0 and not vuelo.is_processing(), "limpiar elimina el feedback pendiente sin callbacks tardíos")
	vuelo.queue_free()
	var run := preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	await get_tree().process_frame
	run.hud._actualizar_poderes()
	verificar(run.hud._boton_rafaga.disabled and "0/20" in run.hud._boton_rafaga.text, "la interfaz muestra la carga real de Ráfaga y no permite activarla vacía")
	verificar(not run.hud._boton_entrada.visible, "sin entradas compradas no se ofrece un acceso inventado")
	var objeto: PiezaCasa = run.comidas.partes[0]
	objeto.vida = objeto.vida_max * 0.5 # Lectura de UI, sin extracción ni premio.
	run.hud.mostrar_inspeccion(objeto)
	verificar("50% consumido" in run.hud._lbl_objetivo.text and not "resistencia" in run.hud._lbl_objetivo.text, "la inspección usa un porcentaje discreto y no barras ni resistencia numérica")
	var fiesta := Conquista.celebrar(run, objeto, 0) # Sólo presentación, no conquista ni recursos.
	run._detener_extraccion()
	var particulas: int = run.efectos._particulas.size()
	fiesta._estallido(0)
	verificar(fiesta._cancelada and fiesta.is_queued_for_deletion() and run.efectos._particulas.size() == particulas, "el silbato también cancela los callbacks cosméticos de una conquista")
	run.queue_free()
	await get_tree().process_frame
	print("INTERFAZ ACTIVA: %d verificaciones; %d fallas" % [total, fallas])
	get_tree().quit(1 if fallas else 0)

func _textos(nodo: Node) -> String:
	var texto := str(nodo.text) if nodo is Label or nodo is Button else ""
	for hijo in nodo.get_children():
		texto += "\n" + _textos(hijo)
	return texto

func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)

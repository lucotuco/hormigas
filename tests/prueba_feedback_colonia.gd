extends Node
## Integración de estímulos: sólo confirma trabajo real, sin nuevos ingresos.
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	var existia := FileAccess.file_exists(Juego.RUTA_PARTIDA)
	var huella := hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) if existia else 0
	Juego.reiniciar_estado()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	var saldo := Juego.migas_run
	for i in 20:
		run._reloj += 0.1
		run.depositar(2.0)
	verificar(is_equal_approx(Juego.migas_run - saldo, 40.0) and run.combo == 20,
		"los acentos de racha no multiplican el ingreso de las veinte entregas")
	verificar(run.poderes.lista(), "el poder se carga con las veinte entregas reales")
	run.hud._actualizar_poderes()
	verificar(run.hud._rafaga_lista and run.hud._pulso_poder > 0.0,
		"el HUD distingue la transición a poder disponible")
	var tweens := get_tree().get_processed_tweens().size()
	for i in 1000:
		run.hud._miga_llego()
		run.hud.mostrar_combo(25)
	verificar(get_tree().get_processed_tweens().size() == tweens,
		"mil entregas y combos no crean tweens nuevos")
	var combo_previo := run.hud._lbl_combo.text
	for i in range(26, 1026):
		run.hud.mostrar_combo(i)
	verificar(run.hud._lbl_combo.text == combo_previo and run.hud._combo_pendiente == 1025,
		"mil cambios de combo se acumulan sin traducir ni formatear por hormiga")
	run.hud._process(0.0)
	verificar(run.hud._lbl_combo.text == tr("COMBO x%d") % 1025 and not run.hud._combo_sucio,
		"un cuadro presenta el último combo completo, sin perder entregas intermedias")
	saldo = Juego.migas_run
	verificar(run.activar_rafaga() and not run.activar_rafaga() and Juego.migas_run == saldo,
		"activar el poder sólo consume su carga una vez, sin migas regaladas")
	var h := run.colonia._nacer("cargadora", Vector2(80, 80))
	h.estado = Hormiga.Estado.VOLVIENDO
	h.carga = 13.0
	h._carga_origen.assign([0.0, 5.0, 8.0])
	h._material_carga = 3
	h.bocados = 2
	h._retazos.append(Rect2(0, 0, 6, 6))
	h._angulos_retazos.append(0.2)
	h._tamanos_retazos.append(Vector2(6, 6))
	h._origenes_retazos.append(Vector2(2, 2))
	h._tiempos_retazos.append(0.0)
	var posicion := h.position
	var rutas := run.cocina.consultas_ruta
	var robo := h.soltar_carga_para_robo()
	verificar(robo == {"valor": 13.0, "material": 3} and h.carga == 0.0 and h.bocados == 0
		and h._carga_origen == [0.0, 0.0, 0.0], "robar traslada exactamente la carga y vacía sus orígenes")
	verificar(h._retazos.is_empty() and h._angulos_retazos.is_empty() and h._tamanos_retazos.is_empty()
		and h._origenes_retazos.is_empty() and h._tiempos_retazos.is_empty(),
		"el material robado no deja retazos visuales en la hormiga")
	verificar(h.position == posicion and h.estado == Hormiga.Estado.EXPLORANDO
		and run.cocina.consultas_ruta == rutas and Juego.migas_run == saldo,
		"la víctima vuelve a explorar sin saltos, ingresos ni A* inmediato")
	verificar(h.soltar_carga_para_robo().is_empty(), "el mismo robo no puede cobrarse dos veces")
	run.activa = false
	h.carga = 7.0
	verificar(h.soltar_carga_para_robo().is_empty() and h.carga == 7.0,
		"el silbato impide el robo tardío de una carga en retirada")
	run.terminada = true
	run.depositar(1000.0)
	verificar(Juego.migas_run == saldo, "un estímulo tardío no revive el ingreso al finalizar")
	run.queue_free()
	await get_tree().process_frame
	await probar_ganancias()
	var intacta := FileAccess.file_exists(Juego.RUTA_PARTIDA) == existia
	if existia:
		intacta = intacta and hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) == huella
	verificar(intacta, "las pruebas de estímulos no escriben la partida personal")
	print("Feedback de colonia: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar_ganancias() -> void:
	Juego.reiniciar_estado()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.depositar(0.125)
	verificar(is_equal_approx(Juego.migas_run, 0.125) and run.hud._lbl_ganancia.visible
		and run.hud._lbl_ganancia.text == "+" + Efectos.formatear_importe(0.125)
		and run.hud._lbl_ganancia.text != "+0",
		"la primera entrega fraccional se cobra y se ve con sus decimales")
	run.depositar(0.25)
	verificar(is_equal_approx(Juego.migas_run, 0.375) and is_equal_approx(run.hud._ganancia_reciente, 0.375),
		"el HUD suma cada pago anterior al gate de adornos sin duplicarlo")
	run.hud._ganancia_ventana = 0
	run.depositar(0.5, Vector2.ZERO, 1, [0.1, 0.4, 0.0])
	verificar(is_equal_approx(Juego.migas_run, 0.875) and is_equal_approx(run.hud._ganancia_reciente, 0.5)
		and is_equal_approx(run.ingresos[0], 0.475) and is_equal_approx(run.ingresos[1], 0.4),
		"la tanda siguiente reinicia sólo el recibo visual y conserva el desglose mixto")
	run.hud._ganancia_ventana = 0
	run.registrar_ingreso(3.25, 2)
	verificar(is_equal_approx(Juego.migas_run, 4.125) and run.hud._lbl_ganancia.text == "+3.25",
		"bonus y créditos ambientales reales también confirman su importe una vez")
	var saldo := Juego.migas_run
	for i in 1000:
		run.hud.migas_voladoras(Vector2(400, 300), 1000)
	verificar(run.hud._vuelo_migas.cantidad == VueloMigas.MAXIMO
		and run.hud._vuelo_migas.migas.size() == VueloMigas.MAXIMO and Juego.migas_run == saldo,
		"los vuelos grandes mantienen el mismo pool de cuarenta y no crean dinero")
	run.hud.mostrar_racha(25)
	verificar(run.hud._lbl_racha.visible and run.hud._racha_visible > 0.0
		and run.hud._lbl_racha.label_settings.font_size >= 30 and Juego.migas_run == saldo,
		"el hito de entregas tiene un cartel grande sin falso multiplicador")
	run.terminada = true
	run.hud.mostrar_fin()
	run.hud.registrar_ganancia(1000)
	run.hud.mostrar_racha(1000)
	run.hud.mostrar_combo(1000)
	verificar(not run.hud._lbl_ganancia.visible and not run.hud._lbl_racha.visible
		and not run.hud._lbl_combo.visible and not run.hud._combo_sucio,
		"el resultado y callbacks tardíos no reabren ganancias ni rachas")
	run.queue_free()
	await get_tree().process_frame


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)

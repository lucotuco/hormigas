extends Node
## Las compras cambian la presentación de hechos reales, nunca su economía.
## No mide FPS: verifica snapshot, puertas, pools y el cierre de la expedición.
var total := 0
var fallas := 0
const CENTRO := Vector2(320, 180)
const COMPRAS := {"migas_brillantes": 1, "mandibulas_destello": 1, "pulso_colonia": 1}


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	var existia := FileAccess.file_exists(Juego.RUTA_PARTIDA)
	var huella := hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) if existia else 0
	probar_snapshot()
	probar_contactos()
	probar_halo()
	probar_limites_y_cierre()
	await probar_integracion_real()
	var intacta := existia == FileAccess.file_exists(Juego.RUTA_PARTIDA)
	if existia:
		intacta = intacta and huella == hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA))
	verificar(intacta and not Juego.guardado_habilitado, "las mejoras visuales no escriben la partida personal")
	print("Mejoras visuales: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar_integracion_real() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = COMPRAS.duplicate()
	Juego.runs_jugadas = 5
	Juego._cache_stats.clear()
	var r: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	verificar(r.efectos._migas_brillantes and r.efectos._mandibulas_destello and r.efectos._pulso_colonia,
		"la expedición real configura las compras al arrancar, sin depender del fixture del lienzo")
	for i in 20:
		r.depositar(0.125)
	verificar(r.frenesi_restante > 0.0 and r.efectos._frenesi_restante == r.frenesi_restante
		and r.efectos._entradas_halo == PackedVector2Array(r.entradas.puntos),
		"veinte entregas verdaderas activan el frenesí y el halo en las entradas reales")
	r._iniciar_retirada()
	r.depositar(0.125)
	r._process(0.1)
	verificar(not r.activa and r.efectos._frenesi_restante == 0.0 and r.efectos._entradas_halo.is_empty(),
		"el silbato apaga el halo y las últimas entregas no vuelven a activar el frenesí")
	r.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()


func lienzo(niveles: Dictionary = {}) -> Efectos:
	var e := Efectos.new()
	add_child(e)
	e.process_mode = Node.PROCESS_MODE_DISABLED
	e.configurar_mejoras(niveles)
	return e


func probar_snapshot() -> void:
	var niveles := COMPRAS.duplicate()
	var e := lienzo(niveles)
	niveles.clear()
	verificar(e._migas_brillantes and e._mandibulas_destello and e._pulso_colonia,
		"la expedición guarda tres booleanos y no relee el diccionario mutable en cada efecto")
	verificar(not e.is_processing() and e.get_child_count() == 0,
		"tener compras sin un hecho visible no despierta procesamiento ni crea emisores")
	e.configurar_mejoras({})
	verificar(not e._migas_brillantes and not e._mandibulas_destello and not e._pulso_colonia,
		"un snapshot vacío conserva exactamente la presentación base")
	e.queue_free()


func probar_contactos() -> void:
	var base := lienzo()
	var e := lienzo(COMPRAS)
	var saldo := Juego.migas
	var ingreso := Juego.migas_run
	e.entrega(CENTRO, 0.0)
	e.entrega(CENTRO, -1.0)
	verificar(e._particulas.is_empty() and e._ondas.is_empty(), "comprar brillo no inventa entregas sin importe")
	e.entrega(Vector2(1000000, 1000000), 1.0)
	e.mordida(Vector2(1000000, 1000000), Color.WHITE)
	verificar(e._particulas.is_empty() and e._ondas.is_empty() and e._pausa_entrega == 0.0 and e._pausa_mordida == 0.0,
		"las compras también rechazan contactos fuera de cámara antes de ocupar puertas o memoria")
	for i in 1000:
		base.entrega(CENTRO, 0.125)
		e.entrega(CENTRO, 0.125)
	verificar(base._particulas.size() == 4 and e._particulas.size() == 8 and e._ondas.size() == 2,
		"una entrega comprada añade cuatro brillos y un recibo; mil callbacks respetan la misma puerta")
	var brillos := 0
	for p in e._particulas:
		if p.forma == Efectos.Forma.BRILLO:
			brillos += 1
	verificar(brillos == 4 and e._ondas.back().estilo == Efectos.Pulso.RECIBO,
		"los acentos nuevos son cruces y arcos, no monedas o material extraído adicional")
	e._process(2.0)
	base._process(2.0)
	for i in 1000:
		base.mordida(CENTRO, Color("b89161"), 1, Vector2.RIGHT)
		e.mordida(CENTRO, Color("b89161"), 1, Vector2.RIGHT)
	verificar(base._particulas.size() == 3 and base._ondas.size() == 1 and e._particulas.size() == 5 and e._ondas.size() == 2,
		"la mordida confirmada conserva tres astillas y agrega un corte con sólo dos chispas")
	var mismas_astillas := true
	for i in 3:
		mismas_astillas = mismas_astillas and e._particulas[i].color == base._particulas[i].color \
			and e._particulas[i].material_id == base._particulas[i].material_id and e._particulas[i].inicio == CENTRO
	verificar(mismas_astillas and e._ondas.back().estilo == Efectos.Pulso.CORTE,
		"el destello no altera el color, material ni origen del bocado físico")
	verificar(Juego.migas == saldo and Juego.migas_run == ingreso, "la presentación no vuelve a pagar ni modifica economía")
	base.queue_free()
	e.queue_free()


func probar_halo() -> void:
	var base := lienzo()
	var e := lienzo(COMPRAS)
	var entradas := PackedVector2Array([CENTRO, CENTRO + Vector2(70, 0)])
	base.actualizar_frenesi(3.0, entradas)
	e.actualizar_frenesi(0.0, entradas)
	verificar(base._entradas_halo.is_empty() and e._entradas_halo.is_empty() and not e.is_processing(),
		"ni una compra sin frenesí ni un frenesí sin compra dibujan un halo")
	e.actualizar_frenesi(3.0, entradas)
	verificar(e._entradas_halo.size() == 2 and e._frenesi_restante == 3.0 and e.is_processing(),
		"sólo el frenesí verdadero activa las entradas conocidas, sin buscar hormigas")
	e._process(0.25)
	var fase := e._fase_halo
	e.actualizar_frenesi(2.75, entradas)
	verificar(e._fase_halo == fase and e._frenesi_restante == 2.75,
		"refrescar el estado real no reinicia la respiración ni encadena tweens")
	entradas[0] = Vector2.ZERO
	verificar(e._entradas_halo[0] == CENTRO, "el halo no conserva una referencia mutable a las entradas externas")
	e._process(3.0)
	e._process(0.0)
	verificar(e._entradas_halo.is_empty() and e._frenesi_restante == 0.0 and not e.is_processing(),
		"al vencer el frenesí vuelve a reposo aunque no lleguen más refrescos de la run")
	e.actualizar_frenesi(2.0, PackedVector2Array([CENTRO]))
	e.actualizar_frenesi(INF, entradas)
	verificar(e._entradas_halo.is_empty() and e._frenesi_restante == 0.0, "una duración no finita no puede dejar un aura eterna")
	e.actualizar_frenesi(2.0, PackedVector2Array([CENTRO]))
	e.actualizar_frenesi(0.0, PackedVector2Array())
	e._process(0.0)
	verificar(e._entradas_halo.is_empty() and not e.is_processing(), "el fin explícito apaga el aura de inmediato")
	base.queue_free()
	e.queue_free()


func probar_limites_y_cierre() -> void:
	var e := lienzo(COMPRAS)
	var entradas := PackedVector2Array()
	for i in 1000:
		entradas.append(CENTRO + Vector2(i, 0))
	e.actualizar_frenesi(3.0, entradas)
	e.chispas(CENTRO, Color.WHITE, 100000)
	for i in 1000:
		e.entrega(CENTRO, 1.0)
		e.mordida(CENTRO, Color.WHITE)
		e._agregar_onda(CENTRO, 20, 0.2, Color.WHITE)
	verificar(e._entradas_halo.size() == Efectos.MAX_ENTRADAS_HALO and e._particulas.size() == Efectos.MAX_PARTICULAS \
		and e._ondas.size() == Efectos.MAX_ONDAS and e.get_child_count() == 0,
		"las compras comparten los techos de 600 partículas, 24 ondas y ocho entradas en un lienzo")
	e._process(4.0)
	e._process(0.0)
	verificar(e._libres.size() == Efectos.MAX_PARTICULAS and e._ondas_libres.size() == Efectos.MAX_ONDAS and not e.is_processing(),
		"la saturación devuelve los mismos objetos al pool y el lienzo deja de procesar")
	e.actualizar_frenesi(3.0, entradas)
	e.limpiar()
	e.configurar_mejoras(COMPRAS)
	e.actualizar_frenesi(20.0, entradas)
	e.entrega(CENTRO, 1.0)
	e.mordida(CENTRO, Color.WHITE)
	verificar(e._entradas_halo.is_empty() and e._frenesi_restante == 0.0 and e.halos_dibujados == 0 \
		and e._particulas.is_empty() and e._ondas.is_empty() and not e.is_processing(),
		"el silbato cierra también las compras y los refrescos tardíos no reviven efectos ni halos")
	e.queue_free()


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)

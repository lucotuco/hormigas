extends Node
## Contratos del lienzo: dirección, intención, puertas, memoria y cámara.
## No mide FPS ni reemplaza la revisión visual con el renderer real.
var total := 0
var fallas := 0
const CENTRO := Vector2(320, 180)


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	var existia := FileAccess.file_exists(Juego.RUTA_PARTIDA)
	var huella := hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) if existia else 0
	probar_entrega()
	probar_numeros()
	probar_contactos()
	probar_limites_y_cierre()
	await probar_camara()
	var intacta := existia == FileAccess.file_exists(Juego.RUTA_PARTIDA)
	if existia:
		intacta = intacta and huella == hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA))
	verificar(intacta and not Juego.guardado_habilitado, "los estímulos no escriben la partida personal")
	print("Estímulos: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func lienzo() -> Efectos:
	var e := Efectos.new()
	add_child(e)
	e.process_mode = Node.PROCESS_MODE_DISABLED
	return e


func probar_entrega() -> void:
	var e := lienzo()
	verificar(not e.is_processing() and e.get_child_count() == 0, "el lienzo vacío no procesa ni crea emisores")
	var migas := Juego.migas
	var ingreso := Juego.migas_run
	seed(1947)
	var esperado := randf()
	seed(1947)
	e.entrega(CENTRO, 0)
	e.entrega(CENTRO, -1)
	verificar(e._particulas.is_empty() and e._ondas.is_empty(), "sin entrega real no se representa un cobro")
	for i in 1000:
		e.entrega(CENTRO, 1, 0)
	verificar(e._particulas.size() == 4 and e._ondas.size() == 1 and e._textos.is_empty(),
		"una sola obrera ya tiene cuatro estelas y un aro; mil callbacks no los multiplican")
	var hacia_dentro := true
	var distancia_previa := 0.0
	for p in e._particulas:
		hacia_dentro = hacia_dentro and p.convergente and p.forma == Efectos.Forma.ESTELA and p.vel.dot(p.pos - CENTRO) < 0.0
		distancia_previa += p.pos.distance_to(CENTRO)
	e._process(0.16)
	var distancia_actual := 0.0
	for p in e._particulas:
		distancia_actual += p.pos.distance_to(CENTRO)
	verificar(hacia_dentro and distancia_actual < distancia_previa * 0.5 and e._ondas[0].estilo == Efectos.Pulso.ENTREGA,
		"las estelas viajan hacia la entrada, no salen como otra moneda")
	verificar(randf() == esperado and Juego.migas == migas and Juego.migas_run == ingreso,
		"el feedback no consume azar de IA ni acredita premios")
	e._process(2.0)
	e._process(0.0)
	verificar(not e.is_processing() and e._particulas.is_empty() and e._ondas.is_empty(), "al terminar vuelve a reposo")
	var reutilizable: Efectos.Particula = e._libres.back()
	e.entrega(CENTRO, 1, 32)
	verificar(e._particulas.has(reutilizable) and e._particulas.size() == 8 and e._ondas.size() == 1 and e._ondas[0].acentos == 6,
		"el combo agrega acentos dentro del mismo pool y mantiene el contrato de ocho partículas")
	e.queue_free()


func probar_contactos() -> void:
	var e := lienzo()
	for i in 1000:
		e.mordida(CENTRO, Color("b89161"), 1, Vector2.RIGHT)
	verificar(e._particulas.size() == 3 and e._ondas.size() == 1, "mil bocas simultáneas producen un solo contacto acotado")
	var material_real := true
	for p in e._particulas:
		material_real = material_real and p.material_id == 1 and p.color == Color("b89161") and p.inicio == CENTRO and not p.convergente
	verificar(material_real and e._ondas[0].estilo == Efectos.Pulso.GOLPE,
		"la astilla nace en el contacto con el color y material del objeto, sin convertirlo en premio")
	e.amenaza(CENTRO, "inexistente")
	verificar(e._ondas.size() == 1, "una fase de amenaza desconocida no genera una señal falsa")
	for i in 1000:
		e.amenaza(CENTRO, "aviso", 42, Vector2.RIGHT, 1.8)
		e.amenaza(CENTRO, "impacto", 42)
		e.amenaza(CENTRO, "repelido", 42, Vector2.RIGHT)
	var estilos := {}
	for o in e._ondas:
		estilos[o.estilo] = true
	verificar(e._ondas.size() == 4 and estilos.has(Efectos.Pulso.AVISO) and estilos.has(Efectos.Pulso.IMPACTO) and estilos.has(Efectos.Pulso.REPELIDO),
		"aviso, impacto y rechazo tienen siluetas y puertas independientes, sin spam")
	verificar(is_equal_approx(e._ondas[1].vida_max, 1.8) and e._ondas[1].radio_max == 42,
		"el aviso respeta la duración declarada y el área nativa de la amenaza")
	for i in 1000:
		e.rafaga(CENTRO)
		e.racha(CENTRO, 2)
		e.explosion(CENTRO, Color("cda973"), 20)
		e.epico(CENTRO, Color("f0d277"), 70)
	verificar(e._ondas.size() == 9 and e._textos.is_empty() and e.get_child_count() == 0,
		"ráfaga, racha, destrucción y victoria se distinguen sin nodos, textos ni cobros nuevos")
	e._process(3.0)
	e._process(0.0)
	verificar(not e.is_processing(), "también las puertas de los nuevos gestos terminan")
	e.queue_free()


func probar_numeros() -> void:
	for caso in [[0.125, "0.125"], [0.004, "0.004"], [3.25, "3.25"], [12.75, "12.75"], [999.5, "999.5"]]:
		verificar(Efectos.formatear_importe(caso[0]) == caso[1],
			"el importe %s conserva decimales reales sin inventar una moneda" % caso[1])
	var pequenos_validos := true
	for valor: float in [0.96, 0.049, 0.000001, 0.000000000001]:
		var contenido := Efectos.formatear_importe(valor)
		pequenos_validos = pequenos_validos and contenido != "0" and contenido.to_float() > 0.0 and contenido.to_float() <= valor * (1.0 + 0.00000001)
	verificar(pequenos_validos, "ninguna fracción positiva se oculta como +0 ni se redondea a dinero todavía no cobrado")
	var e := lienzo()
	var saldo := Juego.migas_run
	e.deposito(CENTRO, 0.125, 1, 0)
	var t: Efectos.TextoFlotante = e._textos[0]
	verificar(t.clase == "deposito" and t.cantidad == 0.125 and t.texto == "+0.125" and t.origen == CENTRO,
		"la primera entrega fraccional produce un número de depósito desde la única obrera")
	verificar(t.pantalla_minima >= 24.0 and Efectos.tamano_numero_pantalla(t) > t.pantalla_minima * 1.3,
		"la entrega nace con un pop fuerte y un mínimo de veinticuatro píxeles")
	var rotulo_inicial := t.texto
	for i in 1000:
		e.deposito(CENTRO, 0.001, 1, 0)
	verificar(e._textos.size() == 1 and is_equal_approx(t.cantidad, 1.125) and t.sucio and t.texto == rotulo_inicial,
		"mil pagos suman su valor exacto sin formatear ni medir una fuente por hormiga")
	e._actualizar_texto(t)
	verificar(not t.sucio and t.texto.begins_with("+") and t.texto.substr(1).to_float() > 1.0 and t.texto.substr(1).to_float() <= t.cantidad,
		"el rótulo agrupado se resuelve una vez y nunca muestra un cobro superior al real")
	e._process(0.2)
	var vida_previa := t.vida
	e.deposito(CENTRO, 0.25, 2, 0)
	verificar(e._textos.size() == 1 and is_equal_approx(t.cantidad, 1.375) and t.vida == vida_previa,
		"sumar durante la ventana no reinicia ni prolonga la vida del número")
	e._process(0.09)
	e.deposito(CENTRO, 0.5, 3, 0)
	verificar(e._textos.size() == 2 and is_equal_approx(e._textos[0].cantidad, 1.375) and e._textos[1].cantidad == 0.5,
		"a los 0.28 segundos cierra una cuenta y empieza otra, sin perder el ingreso anterior")
	e.deposito(CENTRO + Vector2(2, 0), 0.3, 1, 0)
	e.deposito(CENTRO, 0.4, 1, 1)
	verificar(e._textos.size() == 4 and e._textos[2].origen != CENTRO and e._textos[3].color != t.color,
		"entradas distintas y categorías distintas no mezclan sus cuentas ni sus colores")
	e.numero(CENTRO, 0.125, t.color, 1.5)
	var bonus: Efectos.TextoFlotante = e._textos.back()
	verificar(e._textos.size() == 5 and bonus.clase == "bonus" and bonus.cantidad == 0.125 and bonus.pantalla_minima == 32.0,
		"un bonus real mantiene su cifra, clase y mínimo de treinta y dos píxeles, separado del depósito")
	verificar(Juego.migas_run == saldo and e._particulas.size() <= Efectos.MAX_PARTICULAS and e._ondas.size() <= Efectos.MAX_ONDAS,
		"los números no pagan otra vez y comparten los límites de presentación")
	e.limpiar()
	e.deposito(CENTRO, 1000)
	verificar(e._textos.is_empty() and e.depositos_dibujados == 0 and e.fracciones_dibujadas == 0,
		"un depósito tardío no revive números ni contadores de dibujo al cerrar")
	e.queue_free()


func probar_limites_y_cierre() -> void:
	var e := lienzo()
	e.chispas(CENTRO, Color.WHITE, 1000000, 1)
	for i in 1000:
		e._agregar_onda(CENTRO, 25, 0.4, Color.WHITE)
		e.texto(CENTRO, "fixture", Color.WHITE)
		e.habilidad(CENTRO, CENTRO + Vector2(20, 0), Color.WHITE)
	verificar(e._particulas.size() == Efectos.MAX_PARTICULAS and e._ondas.size() == Efectos.MAX_ONDAS
		and e._textos.size() == Efectos.MAX_TEXTOS and e._marcas.size() == 1 and e.get_child_count() == 0,
		"la saturación mantiene todos los techos y un solo nodo")
	e._process(4.0)
	e._process(0.0)
	verificar(e._libres.size() == Efectos.MAX_PARTICULAS and e._ondas_libres.size() == Efectos.MAX_ONDAS
		and e._textos_libres.size() == Efectos.MAX_TEXTOS and e._marcas_libres.size() == 1,
		"partículas, ondas, textos y marcas vuelven a sus pools sin crecer")
	e.chispas(CENTRO, Color.WHITE, 1000000)
	var todos_reiniciados := true
	for p in e._particulas:
		todos_reiniciados = todos_reiniciados and not p.convergente and p.estela == 0.0 and p.material_id == -1 and p.giro == 0.0
	verificar(todos_reiniciados and e._libres.is_empty(), "reutilizar una partícula no conserva el comportamiento de una entrega o astilla anterior")
	e.limpiar()
	emitir_todos(e, CENTRO)
	verificar(e._particulas.is_empty() and e._ondas.is_empty() and e._textos.is_empty() and e._marcas.is_empty()
		and not e.is_processing(), "limpiar es terminal también para mordida, amenaza, racha y ráfaga tardías")
	verificar(e._libres.size() <= Efectos.MAX_PARTICULAS and e._ondas_libres.size() <= Efectos.MAX_ONDAS
		and e._textos_libres.size() <= Efectos.MAX_TEXTOS and e._marcas_libres.size() <= Efectos.MAX_MARCAS,
		"la memoria libre también está acotada tras cerrar")
	e.queue_free()


func emitir_todos(e: Efectos, pos: Vector2) -> void:
	e.entrega(pos, 1, 50)
	e.deposito(pos, 0.125, 1, 0)
	e.mordida(pos, Color.WHITE, 1)
	e.rafaga(pos)
	e.racha(pos, 3)
	for fase in ["aviso", "impacto", "repelido"]:
		e.amenaza(pos, fase)
	e.epico(pos, Color.WHITE)
	e.explosion(pos, Color.WHITE, 30)
	e.chispas(pos, Color.WHITE, 20)
	e.habilidad(pos, pos + Vector2(10, 0), Color.WHITE)
	e.numero(pos, 5, Color.WHITE)
	e.texto(pos, "fixture", Color.WHITE)


func probar_camara() -> void:
	var visor := SubViewport.new()
	visor.size = Vector2i(640, 360)
	visor.world_2d = World2D.new()
	add_child(visor)
	var camara := Camera2D.new()
	camara.position = Vector2(5000, -3000)
	camara.zoom = Vector2.ONE * 0.5
	visor.add_child(camara)
	var e := Efectos.new()
	visor.add_child(e)
	e.process_mode = Node.PROCESS_MODE_DISABLED
	camara.force_update_scroll()
	await get_tree().process_frame
	verificar(e._en_vista(camara.position) and not e._en_vista(Vector2.ZERO) and is_equal_approx(e._zoom(), 0.5),
		"el culling usa la cámara y el zoom de su propio viewport")
	emitir_todos(e, Vector2.ZERO)
	verificar(e._particulas.is_empty() and e._ondas.is_empty() and e._textos.is_empty() and e._marcas.is_empty()
		and not e.is_processing(), "todos los caminos rechazan efectos lejanos antes de consumir una puerta o pool")
	e.entrega(camara.position, 1)
	verificar(e._particulas.size() == 4, "un efecto fuera de vista no bloquea la siguiente entrega visible")
	e._process(2.0)
	camara.zoom = Vector2.ONE * 0.2
	camara.force_update_scroll()
	e.mordida(camara.position, Color.WHITE, 1)
	verificar(e._particulas.size() == 1 and e._ondas.is_empty(), "el zoom lejano conserva el contacto sin dibujar tres astillas y un golpe diminutos")
	visor.queue_free()
	await get_tree().process_frame


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)

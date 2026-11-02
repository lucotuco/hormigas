extends Node
## Autoría/economía de los tres papeles. No acelera una colonia, no mide
## duración ni sustituye la revisión visual y la prueba integrada de apertura.
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	var todos := CatalogoHallazgos.todos()
	verificar(todos.size() == 3, "tres encuentros acotados sin filas nuevas en comidas.csv")
	var ids: Dictionary = {}
	for datos in todos:
		verificar(not ids.has(datos.id), datos.id + ": identidad única para guardado")
		ids[datos.id] = true
		probar_descriptor(datos)
	var copia := CatalogoHallazgos.por_id("sobre_azucar")
	copia.radio = 10000.0
	verificar(CatalogoHallazgos.por_id("sobre_azucar").radio == 11.0, "modificar una copia no altera el catálogo")
	verificar(CatalogoHallazgos.por_id("inventado").is_empty()
		and CatalogoHallazgos.por_envoltorio("azucar").is_empty(), "IDs desconocidos y comida nativa no se confunden con envoltorios")
	verificar(CatalogoHallazgos.dividir("inventado", {}).is_empty(), "un hallazgo inválido no crea comida")
	Juego.reiniciar_estado()
	print("Arte y catálogo de hallazgos: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func verificar(condicion: bool, mensaje: String) -> void:
	total += 1
	if condicion:
		print("OK ", mensaje)
	else:
		fallas += 1
		print("FALLA ", mensaje)


func cerca(a: float, b: float) -> bool:
	return absf(a - b) <= maxf(0.000001, maxf(absf(a), absf(b)) * 0.000000001)


func original(id: String) -> Dictionary:
	for datos in Juego.comidas:
		if datos.id == id:
			return datos.duplicate(true)
	return {}


func probar_descriptor(datos: Dictionary) -> void:
	verificar(datos.comida != "miga" and datos.distancia_min == 250.0 and datos.distancia_max == 620.0 and datos.distancia_respaldo == 900.0,
		datos.id + ": conserva las migas del primer ingreso y el anillo preferido")
	verificar(CatalogoHallazgos.por_envoltorio(datos.id_envoltorio).id == datos.id,
		datos.id + ": el sprite del papel se decodifica al hallazgo estable")
	verificar(DibujoHallazgo.tiene_forma(datos.forma), datos.id + ": tiene arte procedural propio")
	var formas := DibujoHallazgo.silueta(datos.forma, datos.radio)
	var cuerpo := Rect2(Vector2.ONE * -float(datos.radio), Vector2.ONE * float(datos.radio) * 2.0)
	verificar(not formas.is_empty() and formas.size() <= 4, datos.id + ": el cuerpo usa pocos rectángulos opacos")
	var superficie := 0.0
	var solapes := false
	for i in formas.size():
		verificar(formas[i].has_area() and cuerpo.encloses(formas[i]), datos.id + ": la geometría cabe dentro del dibujo")
		superficie += formas[i].get_area()
		for j in i:
			solapes = solapes or formas[i].intersection(formas[j]).get_area() > 0.000001
	verificar(not solapes and superficie > 0.0, datos.id + ": el papel no duplica material por superponer pliegues")
	verificar(Graficos.formas_alimento(datos.id_envoltorio) == formas,
		datos.id + ": headless y atlas comparten el mismo cuerpo autorado")
	verificar(DibujoHallazgo.silueta("inventado", datos.radio).is_empty()
		and DibujoHallazgo.silueta(datos.forma, 0).is_empty(), datos.id + ": no inventa un cuadrado para arte desconocido")
	var base := original(datos.comida)
	verificar(not base.is_empty(), datos.id + ": reserva un alimento que ya existe")
	if base.is_empty():
		return
	var radio_contenido := float(base.radio)
	var cuerpo_contenido := Rect2(Vector2.ONE * -radio_contenido, Vector2.ONE * radio_contenido * 2.0)
	verificar(not formas.is_empty() and formas[0].encloses(cuerpo_contenido),
		datos.id + ": el cuerpo principal del paquete contiene el tamaño real de la comida reservada")
	var sin_cambios := base.duplicate(true)
	for factor in [1.0, 1.7, 2.8]:
		var balance := base.duplicate(true)
		balance.recompensa = float(balance.recompensa) * factor
		var dividido := CatalogoHallazgos.dividir(datos.id, balance)
		verificar(not dividido.is_empty(), datos.id + ": el reparto admite el valor de destino sin redondearlo")
		if dividido.is_empty():
			continue
		var papel: Dictionary = dividido.envoltorio
		var contenido: Dictionary = dividido.contenido
		verificar(cerca(float(papel.vida) + float(contenido.vida), float(balance.vida))
			and cerca(float(papel.recompensa) + float(contenido.recompensa), float(balance.recompensa)),
			datos.id + ": papel y contenido conservan HP y valor exactos")
		verificar(cerca(float(papel.recompensa) * 0.25 + float(contenido.recompensa) * 0.25,
			float(balance.recompensa) * 0.25), datos.id + ": ambos bonus suman el bonus nativo sin otro premio original")
		verificar(papel.vida >= 1.0 and contenido.vida >= 1.0 and papel.recompensa > 0.0 and contenido.recompensa > 0.0,
			datos.id + ": no depende de convertir papel sin valor en carga ni del clamp de HP")
		verificar(papel.id == datos.id_envoltorio and papel.forma == datos.forma and papel.radio == datos.radio
			and contenido.id == base.id and contenido.forma == base.forma and contenido.radio == base.radio,
			datos.id + ": el papel tiene cuerpo propio y el contenido conserva su tamaño real")
	verificar(base == sin_cambios, datos.id + ": el reparto puro no modifica el alimento del generador")
	var equivocado := base.duplicate(true)
	equivocado.id = "miga"
	verificar(CatalogoHallazgos.dividir(datos.id, equivocado).is_empty(), datos.id + ": no acepta sustituir migas por un paquete")
	for invalido in [0.0, -1.0, INF, NAN]:
		var balance := base.duplicate(true)
		balance.vida = invalido
		verificar(CatalogoHallazgos.dividir(datos.id, balance).is_empty(), datos.id + ": rechaza HP inválido sin inventar material")
	var diminuto := base.duplicate(true)
	diminuto.vida = 1.0
	verificar(CatalogoHallazgos.dividir(datos.id, diminuto).is_empty(), datos.id + ": no infla dos partes de un HP mínimo")
	probar_porciones(datos, base, formas)


func probar_porciones(datos: Dictionary, base: Dictionary, formas: Array[Rect2]) -> void:
	var dividido := CatalogoHallazgos.dividir(datos.id, base)
	var papel: Dictionary = dividido.envoltorio
	var m := MordiscosMaterial.new()
	var radio: float = datos.radio
	var rect := Rect2(Vector2.ONE * -radio, Vector2.ONE * radio * 2.0)
	m.configurar(rect, Vector2i.ONE, [formas], PackedFloat64Array([float(papel.vida)]))
	var retirado := 0.0
	var porciones := 0
	var todas_locales := true
	var lados: Array[Vector2] = [Vector2(-radio - 4, 0), Vector2(radio + 4, 0),
		Vector2(0, -radio - 4), Vector2(0, radio + 4)]
	for paso in 4000:
		if m.vida_celda(0) <= 0:
			break
		var real := m.recortar_local(0, float(papel.vida), lados[paso % lados.size()], 6.0)
		if real <= 0:
			continue
		retirado += real
		porciones += 1
		todas_locales = todas_locales and m.ultima_porcion.has_area()
		todas_locales = todas_locales and m.ultima_porcion.size.x <= 6.00001 and m.ultima_porcion.size.y <= 6.00001
	verificar(todas_locales and porciones > 1, datos.id + ": hasta un daño enorme sólo retira porciones reales de seis por lado")
	verificar(m.vida_celda(0) == 0.0 and cerca(retirado, float(papel.vida)), datos.id + ": todo el papel físico se puede extraer sin HP fantasma")
	var valor_retirado := float(papel.recompensa) * retirado / float(papel.vida)
	verificar(cerca(valor_retirado + float(dividido.contenido.recompensa), float(base.recompensa)),
		datos.id + ": papel retirado más comida reservada no crean valor")

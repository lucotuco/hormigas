extends Node
## Estado global del juego (autoload "Juego").
##
## - Lee las tablas de balance de /datos (CSV editables desde una planilla).
## - Calcula las estadísticas de la colonia según las mejoras compradas.
## - Guarda y carga la partida.
## - Lleva la cuenta de la run en curso.
##
## Cualquier script puede usarlo directamente: Juego.stat("velocidad"), Juego.migas, etc.

signal migas_cambiaron(total: float)
signal mejora_comprada(id: String, nivel: int)
signal partida_borrada
signal casta_comprada(id: String, cantidad: int)
signal modo_compra_cambio
signal progreso_cambio
const HITOS := {
	"primera_silla": {"nombre": "La primera silla", "detalle": "Devorá una silla", "premio": "Carpinteras: daño +20%"},
	"primer_derrumbe": {"nombre": "Efecto dominó", "detalle": "Provocá un derrumbe al quitar soportes", "premio": "Demoledoras: daño +20%"},
	"cuatro_sillas": {"nombre": "Sin dónde sentarse", "detalle": "Devorá 4 sillas en una expedición", "premio": "Cargadoras: +2 bocados"},
	"primer_tesoro": {"nombre": "¿Qué había adentro?", "detalle": "Abrí un mueble con comida escondida", "premio": "Toda la colonia: olfato +10"},
	"cocina_vacia": {"nombre": "Cocina desmantelada", "detalle": "Devorá los muebles de la cocina en una expedición", "premio": "Migas +10% permanentes"},
	"primer_monumento": {"nombre": "Una colonia monumental", "detalle": "Devorá tu primer monumento", "premio": "Migas +15% y corona evolucionada"},
}
var cantidad_compra := 1 # 0 = máximo que alcanza

const RUTA_PARTIDA := "user://partida.json"
const VERSION_PARTIDA := 4
const RUTA_STATS := "res://datos/stats_base.csv"
const RUTA_MEJORAS := "res://datos/mejoras.csv"
const RUTA_COMIDAS := "res://datos/comidas.csv"
const RUTA_CASTAS := "res://datos/castas.csv"
const RUTA_JALEA := "res://datos/jalea.csv"
const RUTA_DECRETOS := "res://datos/decretos.csv"

# --- Prestigio (ver docs/DISENO_PROGRESION.md) ---
## Jalea al fundar = JALEA_POR_CORONA × coronas + ⌊(migas de la colonia / DIVISOR_JALEA_MIGAS) ^ EXPONENTE_JALEA_MIGAS⌋
const JALEA_POR_CORONA := 3
const DIVISOR_JALEA_MIGAS := 100000.0
## Raíz cuarta: con la cúbica el prestigio se desbocaba (el bonus pasivo da
## más migas, las migas dan más jalea): la 4.ª fundación daba 5.000 de jalea.
const EXPONENTE_JALEA_MIGAS := 0.25
## Bonus pasivo de daño y migas por cada punto de jalea ganado en la historia.
const BONUS_LEGADO := 0.03
## Niveles extra de tope por cada nivel de "Cámaras más hondas".
const NIVELES_POR_TECHO := 5
## Efectos especiales del árbol de la reina (columna "efecto" de jalea.csv).
const EFECTOS_JALEA := ["stat", "herencia", "despensa", "techo", "linaje", "corona"]
## Ninguna expedición dura menos que esto, aunque un decreto reste tiempo.
const DURACION_MINIMA := 20.0

const SUFIJOS: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

# --- Datos de balance (vienen de /datos) ---
var stats_base: Dictionary = {}          # nombre -> valor base
var mejoras: Array[Dictionary] = []      # en el orden del CSV
var mejoras_por_id: Dictionary = {}
var comidas: Array[Dictionary] = []
var ramas: Array[String] = []            # ramas del árbol en orden de aparición
var castas: Array[Dictionary] = []
var castas_por_id: Dictionary = {}
var nodos_jalea: Array[Dictionary] = []  # árbol de la reina, en el orden del CSV
var jalea_por_id: Dictionary = {}
## Decretos de la reina: al fundar se elige uno, que rige toda la colonia nueva.
var decretos: Array[Dictionary] = []
var decretos_por_id: Dictionary = {}

# --- Partida guardada ---
var migas: float = 0.0
var niveles: Dictionary = {}             # id de mejora -> nivel
var reclutadas: Dictionary = {}          # casta -> unidades permanentes por expedición
var runs_jugadas: int = 0
var mejor_run: float = 0.0
var radio_visto: float = 0.0             # último radio de territorio que vio el jugador
var lugar_actual := "casa"
var lugares_completados: Dictionary = {}
var coronas_cobradas: Dictionary = {}    # destinos que ya pagaron coronas en esta colonia
var hitos: Dictionary = {}
## Jalea real ganada en toda la historia: da el bonus pasivo (no baja al gastar).
var legado := 0
## Jalea real disponible para gastar en el árbol de la reina.
var jalea := 0
var niveles_jalea: Dictionary = {}       # id de nodo -> nivel (permanente)
var migas_colonia: float = 0.0           # migas juntadas desde la última fundación
var coronas := 0
var fundaciones := 0
## Decreto de la colonia actual ("" en la primera colonia).
var decreto := ""
var prioridad := "automatico"
## Mecánicas de la interfaz que ya se revelaron: id -> true si el jugador ya
## las vio, false si son nuevas. Ver REVELABLES.
var descubiertos: Dictionary = {}

## Las mecánicas aparecen de a una para no abrumar al empezar.
## Cada una se revela cuando se cumple su condición (ver _condicion_revelar)
## y queda visible para siempre, incluso después de fundar una colonia.
const REVELABLES := {
	"compra_lote": "Comprar de a 10 o el máximo",
	"frenesi": "Frenesí: 20 depósitos seguidos aceleran a la colonia",
	"gran_objetivo": "Gran objetivo: buscalo con G",
	"castas": "Castas: hormigas especialistas",
	"prioridades": "Prioridades: elegí qué come la colonia",
	"viajes": "Viajes: nuevos destinos",
	"legado": "Jalea real: fundá colonias y mejorá a la reina",
	"doradas": "Migas doradas: pisalas antes de que desaparezcan",
	"amenazas": "Amenazas: cada destino tiene la suya; pisalas para salvar a la colonia",
}
## Desbloqueos clave que marcan la progresión; el HUD muestra el próximo.
const DIETAS := ["mordida_madera", "mordida_resistente", "mordida_muros"]

# --- Run en curso ---
var migas_run: float = 0.0
var comidas_destruidas_run: int = 0
var partes_destruidas_run: int = 0
var mejor_combo_run: int = 0
var ultima_run_fue_record := false

## Ponerlo en false evita escribir el archivo de partida (lo usan las pruebas).
var guardado_habilitado := true

## Estadísticas de toda la partida: no se reinician al fundar una colonia.
## Las muestra la pantalla de estadísticas (ui/panel_estadisticas.gd).
const ESTADISTICAS := ["migas_totales", "migas_gastadas", "tiempo_total", "tiempo_en_runs",
	"comidas_devoradas", "partes_devoradas", "pisotones", "derrumbes", "hormigas_nacidas",
	"mayor_colonia", "mejor_combo", "objetivos_conquistados", "coronas_ganadas",
	"niveles_comprados", "castas_reclutadas", "jalea_gastada",
	"amenazas_vencidas", "hormigas_perdidas", "migas_doradas"]
var estadisticas: Dictionary = {}
var _inicio_run := 0.0

var _cache_stats: Dictionary = {}


func _ready() -> void:
	Engine.max_fps = 60
	# Todo texto visible pasa por tr() a mano (ver idiomas/LEEME.md): sin la
	# traducción automática de los nodos, lo que falte traducir se nota.
	get_tree().root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	usar_idioma(idioma_del_sistema())
	_cargar_datos()
	cargar()


# =====================================================================
# Idioma
# =====================================================================

## Los textos se escriben en español en el código; idiomas/en.po trae el inglés.
const IDIOMAS := ["es", "en"]
var idioma := "es"


func idioma_del_sistema() -> String:
	return "es" if OS.get_locale_language() == "es" else "en"


func _process(delta: float) -> void:
	estadisticas.tiempo_total = estadistica("tiempo_total") + delta


func usar_idioma(codigo: String) -> void:
	idioma = codigo if codigo in IDIOMAS else "es"
	TranslationServer.set_locale(idioma)


func _unhandled_input(event: InputEvent) -> void:
	# Atajos de desarrollo: solo funcionan al correr desde el editor.
	if not OS.is_debug_build():
		return
	var tecla := event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	match tecla.keycode:
		KEY_F1:
			migas += 1000.0
			migas_cambiaron.emit(migas)
			guardar()
		KEY_F2:
			migas *= 10.0
			migas_cambiaron.emit(migas)
			guardar()
		KEY_F9:
			borrar_partida()


# =====================================================================
# Estadísticas y mejoras
# =====================================================================

## Valor actual de una estadística: base + mejoras sumadas, por mejoras que
## multiplican, por hitos de nivel, por el árbol de la reina y el legado.
func stat(nombre: String) -> float:
	if _cache_stats.has(nombre):
		return _cache_stats[nombre]
	if not stats_base.has(nombre):
		push_error("Stat desconocida: '%s'. Agregala en %s." % [nombre, RUTA_STATS])
		return 0.0
	var resultado := _calcular(nombre)
	_cache_stats[nombre] = resultado
	return resultado


## Cálculo de una stat. Con `id_extra` suma `niveles_extra` a esa mejora (vista previa).
func _calcular(nombre: String, id_extra := "", niveles_extra := 0) -> float:
	var valor: float = stats_base[nombre]
	var multiplicador := 1.0
	for m in mejoras:
		if m.stat != nombre:
			continue
		var nivel := nivel_de(m.id) + (niveles_extra if m.id == id_extra else 0)
		if nivel <= 0:
			continue
		if m.tipo == "suma":
			valor += m.valor * nivel
		else:
			multiplicador *= pow(m.valor, nivel)
		if m.bonus_cada > 0:
			multiplicador *= pow(m.bonus_mult, floori(float(nivel) / m.bonus_cada))
	for n in nodos_jalea:
		if n.efecto != "stat" or n.stat != nombre:
			continue
		var nivel := nivel_jalea(n.id)
		if nivel <= 0:
			continue
		if n.tipo == "suma":
			valor += n.valor * nivel
		else:
			multiplicador *= pow(n.valor, nivel)
	if decretos_por_id.has(decreto):
		for efecto in decretos_por_id[decreto].efectos:
			if efecto.stat == nombre:
				if efecto.tipo == "suma":
					valor += efecto.valor
				else:
					multiplicador *= efecto.valor
	var resultado := valor * multiplicador
	if nombre == "duracion_run":
		resultado = maxf(resultado, DURACION_MINIMA)
	return _aplicar_legado(nombre, resultado)

func _aplicar_legado(nombre: String, resultado: float) -> float:
	if nombre in ["dano", "multiplicador_migas"]:
		resultado *= 1.0 + legado * BONUS_LEGADO
	if nombre == "olfato" and hitos.has("primer_tesoro"):
		resultado += 10
	if nombre == "multiplicador_migas":
		resultado *= (1.1 if hitos.has("cocina_vacia") else 1.0) * (1.15 if hitos.has("primer_monumento") else 1.0)
	return resultado


func nivel_de(id: String) -> int:
	return int(niveles.get(id, 0))


## Vista previa exacta sin modificar niveles, caché ni partida.
func stat_tras_comprar(id: String, cantidad := 1) -> float:
	var nombre: String = mejoras_por_id[id].stat
	return _calcular(nombre, id, mini(cantidad, nivel_maximo(id) - nivel_de(id)))


## Nivel máximo actual: el del CSV, más lo que suman los destinos conquistados
## y, en las mejoras elevables, las Cámaras más hondas del árbol de la reina.
func nivel_maximo(id: String) -> int:
	var m: Dictionary = mejoras_por_id[id]
	var tope: int = m.nivel_max + m.tope_por_destino * lugares_completados.size()
	if m.elevable:
		tope += NIVELES_POR_TECHO * nivel_jalea("techo")
	return tope


## Próximo nivel en que la mejora multiplica su stat (0 si no tiene hitos).
func proximo_hito_nivel(id: String) -> int:
	var m: Dictionary = mejoras_por_id[id]
	if m.bonus_cada <= 0:
		return 0
	return (floori(float(nivel_de(id)) / m.bonus_cada) + 1) * m.bonus_cada


func costo(id: String) -> float:
	var m: Dictionary = mejoras_por_id[id]
	return floor(m.costo_base * pow(m.crecimiento, nivel_de(id)))


func esta_al_maximo(id: String) -> bool:
	return nivel_de(id) >= nivel_maximo(id)


func esta_desbloqueada(id: String) -> bool:
	var m: Dictionary = mejoras_por_id[id]
	if m.destino != "" and not destino_desbloqueado(m.destino):
		return false
	if m.requiere_id == "":
		return true
	return nivel_de(m.requiere_id) >= m.requiere_nivel


func puede_comprar(id: String) -> bool:
	return esta_desbloqueada(id) and not esta_al_maximo(id) and migas >= costo(id)


func comprar(id: String) -> bool:
	return comprar_lote(id, 1) > 0


func cambiar_cantidad_compra(cantidad: int) -> void:
	if cantidad not in [0, 1, 10]:
		return
	cantidad_compra = cantidad
	modo_compra_cambio.emit()


func _cotizar(base: float, crecimiento: float, nivel: int, maximo: int, cantidad: int, habilitada: bool) -> Dictionary:
	var disponibles := maxi(0, maximo - nivel)
	var objetivo := disponibles if cantidad == 0 else mini(maxi(1, cantidad), disponibles)
	var total := 0.0
	var unidades := 0
	for i in objetivo:
		var precio := floorf(base * pow(crecimiento, nivel + i))
		if cantidad == 0 and total + precio > migas:
			break
		total += precio
		unidades += 1
	var puede := habilitada and unidades > 0 and migas >= total
	if unidades == 0 and disponibles > 0:
		total = floor(base * pow(crecimiento, nivel))
	return {"cantidad": unidades, "costo": total, "puede": puede}


func cotizar_mejora(id: String, cantidad := 1) -> Dictionary:
	var m: Dictionary = mejoras_por_id[id]
	return _cotizar(m.costo_base, m.crecimiento, nivel_de(id), nivel_maximo(id), cantidad, esta_desbloqueada(id))


func comprar_lote(id: String, cantidad := 1) -> int:
	var oferta := cotizar_mejora(id, cantidad)
	if not oferta.puede:
		return 0
	migas -= oferta.costo
	niveles[id] = nivel_de(id) + int(oferta.cantidad)
	sumar_estadistica("migas_gastadas", oferta.costo)
	sumar_estadistica("niveles_comprados", oferta.cantidad)
	_cache_stats.clear()
	guardar()
	migas_cambiaron.emit(migas)
	mejora_comprada.emit(id, niveles[id])
	return oferta.cantidad


func cantidad_casta(id: String) -> int:
	return int(reclutadas.get(id, 0))


func costo_casta(id: String) -> float:
	if not castas_por_id.has(id):
		return INF
	var c: Dictionary = castas_por_id[id]
	return floor(c.costo_base * pow(c.crecimiento, cantidad_casta(id)))


func puede_comprar_casta(id: String) -> bool:
	if not castas_por_id.has(id):
		return false
	var c: Dictionary = castas_por_id[id]
	return c.comprable and casta_desbloqueada(id) and cantidad_casta(id) < c.maximo and migas >= costo_casta(id)

func casta_desbloqueada(id: String) -> bool:
	return (id != "carpintera" or stat("materiales") >= 1) and (id != "demoledora" or stat("materiales") >= 3)


func comprar_casta(id: String) -> bool:
	return comprar_castas_lote(id, 1) > 0


func cotizar_casta(id: String, cantidad := 1) -> Dictionary:
	if not castas_por_id.has(id):
		return {"cantidad": 0, "costo": 0.0, "puede": false}
	var c: Dictionary = castas_por_id[id]
	return _cotizar(c.costo_base, c.crecimiento, cantidad_casta(id), c.maximo, cantidad, c.comprable and casta_desbloqueada(id))


func comprar_castas_lote(id: String, cantidad := 1) -> int:
	var oferta := cotizar_casta(id, cantidad)
	if not oferta.puede:
		return 0
	migas -= oferta.costo
	reclutadas[id] = cantidad_casta(id) + int(oferta.cantidad)
	sumar_estadistica("migas_gastadas", oferta.costo)
	sumar_estadistica("castas_reclutadas", oferta.cantidad)
	guardar()
	migas_cambiaron.emit(migas)
	casta_comprada.emit(id, cantidad_casta(id))
	return oferta.cantidad


func total_especialistas() -> int:
	var total := 0
	for id in reclutadas:
		total += cantidad_casta(id)
	return total


## Estadísticas reales: las mejoras generales también benefician a las castas.
func stats_casta(id: String) -> Dictionary:
	var c: Dictionary = castas_por_id[id]
	return {
		"velocidad": stat("velocidad") * c.velocidad,
		"dano": stat("dano") * c.dano,
		"capacidad": maxi(1, int(stat("capacidad") * c.capacidad)) + (2 if id == "cargadora" and hitos.has("cuatro_sillas") else 0),
		"olfato": stat("olfato") * c.olfato,
		"intervalo_mordida": maxf(0.05, stat("intervalo_mordida")),
	}

## ¿La mecánica ya se le mostró al jugador? Si recién se cumple su condición,
## queda registrada como nueva (para marcarla con "¡Nuevo!").
func revelado(id: String) -> bool:
	if descubiertos.has(id):
		return true
	if not _condicion_revelar(id):
		return false
	descubiertos[id] = false
	guardar()
	return true


func es_nuevo(id: String) -> bool:
	return descubiertos.get(id, true) == false


func marcar_visto(id: String) -> void:
	if descubiertos.get(id, true) == false:
		descubiertos[id] = true
		guardar()


func _condicion_revelar(id: String) -> bool:
	match id:
		"compra_lote", "frenesi":
			return runs_jugadas >= 2
		"gran_objetivo":
			return runs_jugadas >= 3
		"castas":
			return runs_jugadas >= 4 or total_especialistas() > 0
		"prioridades":
			return stat("materiales") >= 1
		"viajes":
			return not lugares_completados.is_empty()
		"legado":
			return not hitos.is_empty() or coronas > 0 or legado > 0 or fundaciones > 0
		"doradas":
			return runs_jugadas >= 3
		"amenazas":
			return runs_jugadas >= 6
	return true


## La próxima meta concreta para mostrar siempre en pantalla.
## tipo "migas": juntar migas para comprar una dieta; "nivel": subir la mejora
## que la habilita; "objetivo": comer el gran objetivo; "viaje": ir al próximo destino.
func proxima_meta() -> Dictionary:
	for id in DIETAS:
		if nivel_de(id) >= 1:
			continue
		var m: Dictionary = mejoras_por_id[id]
		if not esta_desbloqueada(id):
			var previa: Dictionary = mejoras_por_id[m.requiere_id]
			return {"tipo": "nivel", "nombre": tr("%s nivel %d") % [tr(previa.nombre), m.requiere_nivel],
				"detalle": tr("habilita: %s") % tr(m.nombre), "actual": float(nivel_de(previa.id)), "objetivo": float(m.requiere_nivel)}
		return {"tipo": "migas", "nombre": tr(m.nombre), "detalle": tr(m.descripcion),
			"actual": migas + migas_run, "objetivo": costo(id)}
	if not lugares_completados.has(lugar_actual):
		return {"tipo": "objetivo", "nombre": tr(Mundos.INFO[lugar_actual].meta), "detalle": tr("gran objetivo · %d coronas") % int(Mundos.INFO[lugar_actual].coronas)}
	var indice := Mundos.ORDEN.find(lugar_actual)
	if indice + 1 < Mundos.ORDEN.size():
		return {"tipo": "viaje", "nombre": tr("Viajar a %s") % tr(Mundos.INFO[Mundos.ORDEN[indice + 1]].nombre), "detalle": tr("desde la pestaña Viajes")}
	return {"tipo": "viaje", "nombre": tr("Fundar una colonia nueva"), "detalle": tr("convertí coronas y migas en jalea real")}


func nivel_visual() -> int:
	return mini(2, int(nivel_de("mandibulas") >= 4) + int(nivel_de("buche") >= 3 or legado > 0))

func obtener_hito(id: String) -> bool:
	if hitos.has(id) or not HITOS.has(id):
		return false
	hitos[id] = true
	_cache_stats.clear()
	guardar()
	progreso_cambio.emit()
	return true

func destino_desbloqueado(id: String) -> bool:
	var indice := Mundos.ORDEN.find(id)
	return indice == 0 or (indice > 0 and lugares_completados.has(Mundos.ORDEN[indice - 1]))

func elegir_destino(id: String) -> bool:
	if not destino_desbloqueado(id):
		return false
	lugar_actual = id
	guardar()
	progreso_cambio.emit()
	return true

## Las coronas de un destino se cobran una vez por colonia: repetir el mismo
## destino no las vuelve a dar hasta fundar una colonia nueva.
## Devuelve las coronas entregadas (0 si ya se habían cobrado).
func completar_destino() -> int:
	lugares_completados[lugar_actual] = true
	var entregadas := 0
	if not coronas_cobradas.has(lugar_actual):
		coronas_cobradas[lugar_actual] = true
		entregadas = int(Mundos.INFO[lugar_actual].coronas) + nivel_jalea("corona_doble")
		coronas += entregadas
		sumar_estadistica("coronas_ganadas", entregadas)
	sumar_estadistica("objetivos_conquistados")
	guardar()
	progreso_cambio.emit()
	return entregadas

# =====================================================================
# Prestigio: fundar colonias y el árbol de la reina
# =====================================================================

## Desglose de lo que daría fundar ahora: coronas, migas y total de jalea.
func detalle_fundar() -> Dictionary:
	var por_coronas := coronas * JALEA_POR_CORONA
	var por_migas := floori(pow(maxf(0.0, migas_colonia) / DIVISOR_JALEA_MIGAS, EXPONENTE_JALEA_MIGAS) + 0.000001)
	return {"coronas": por_coronas, "migas": por_migas, "total": por_coronas + por_migas}


func jalea_por_fundar() -> int:
	return detalle_fundar().total


func puede_fundar() -> bool:
	return jalea_por_fundar() >= 1


## Reinicia la economía de la colonia y la convierte en jalea real.
## Se conservan destinos, hitos, jalea, el árbol de la reina y lo revelado.
## `decreto_nuevo` rige la colonia que nace ("" = sin decreto).
func fundar_colonia(decreto_nuevo := "") -> bool:
	var ganada := jalea_por_fundar()
	if ganada < 1:
		return false
	decreto = decreto_nuevo if decretos_por_id.has(decreto_nuevo) else ""
	var conservar_migas := migas * 0.1 * nivel_jalea("despensa")
	var porcion_castas := 0.25 * nivel_jalea("linaje")
	legado += ganada
	jalea += ganada
	coronas = 0
	coronas_cobradas.clear()
	fundaciones += 1
	migas = conservar_migas
	migas_colonia = 0.0
	niveles.clear()
	_aplicar_herencias()
	var anteriores := reclutadas.duplicate()
	reclutadas.clear()
	for id in anteriores:
		var quedan := floori(int(anteriores[id]) * porcion_castas)
		if quedan > 0:
			reclutadas[id] = quedan
	radio_visto = 0
	_cache_stats.clear()
	guardar()
	migas_cambiaron.emit(migas)
	progreso_cambio.emit()
	return true


## Las "Memorias" del árbol hacen nacer cada colonia con las dietas aprendidas.
func _aplicar_herencias() -> void:
	var dietas := {"herencia_madera": "mordida_madera", "herencia_resistente": "mordida_resistente", "herencia_muros": "mordida_muros"}
	for nodo in dietas:
		if nivel_jalea(nodo) > 0 and nivel_de(dietas[nodo]) == 0:
			niveles[dietas[nodo]] = 1
	_cache_stats.clear()


func nivel_jalea(id: String) -> int:
	return int(niveles_jalea.get(id, 0))


func costo_jalea(id: String) -> int:
	var n: Dictionary = jalea_por_id[id]
	return int(floor(n.costo_base * pow(n.crecimiento, nivel_jalea(id))))


func jalea_desbloqueada(id: String) -> bool:
	var n: Dictionary = jalea_por_id[id]
	return n.requiere_id == "" or nivel_jalea(n.requiere_id) >= n.requiere_nivel


func jalea_al_maximo(id: String) -> bool:
	return nivel_jalea(id) >= int(jalea_por_id[id].nivel_max)


func puede_comprar_jalea(id: String) -> bool:
	return jalea_por_id.has(id) and jalea_desbloqueada(id) and not jalea_al_maximo(id) and jalea >= costo_jalea(id)


func comprar_jalea(id: String) -> bool:
	if not puede_comprar_jalea(id):
		return false
	sumar_estadistica("jalea_gastada", costo_jalea(id))
	jalea -= costo_jalea(id)
	niveles_jalea[id] = nivel_jalea(id) + 1
	if jalea_por_id[id].efecto == "herencia":
		_aplicar_herencias()  # también sirve para la colonia actual
	_cache_stats.clear()
	guardar()
	progreso_cambio.emit()
	migas_cambiaron.emit(migas)
	return true


# =====================================================================
# Estadísticas
# =====================================================================

func estadistica(clave: String) -> float:
	return float(estadisticas.get(clave, 0.0))


func sumar_estadistica(clave: String, cantidad: float = 1.0) -> void:
	estadisticas[clave] = estadistica(clave) + cantidad


func registrar_maximo(clave: String, valor: float) -> void:
	estadisticas[clave] = maxf(estadistica(clave), valor)


# =====================================================================
# Run
# =====================================================================

func iniciar_run() -> void:
	migas_run = 0.0
	comidas_destruidas_run = 0
	partes_destruidas_run = 0
	mejor_combo_run = 0
	ultima_run_fue_record = false
	_inicio_run = estadistica("tiempo_total")


func sumar_migas_run(cantidad: float) -> void:
	migas_run += cantidad


func terminar_run() -> void:
	migas += migas_run
	migas_colonia += migas_run
	sumar_estadistica("migas_totales", migas_run)
	sumar_estadistica("comidas_devoradas", comidas_destruidas_run)
	sumar_estadistica("partes_devoradas", partes_destruidas_run)
	sumar_estadistica("tiempo_en_runs", maxf(0.0, estadistica("tiempo_total") - _inicio_run))
	registrar_maximo("mejor_combo", mejor_combo_run)
	runs_jugadas += 1
	ultima_run_fue_record = runs_jugadas > 1 and migas_run > mejor_run
	mejor_run = maxf(mejor_run, migas_run)
	radio_visto = stat("radio_territorio")
	guardar()
	migas_cambiaron.emit(migas)
	print("[Juego] Run %d terminada: +%s migas (total %s)" % [runs_jugadas, formatear(migas_run), formatear(migas)])


# =====================================================================
# Guardado
# =====================================================================

func guardar() -> void:
	if not guardado_habilitado:
		return
	var archivo := FileAccess.open(RUTA_PARTIDA, FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo guardar la partida (error %d)" % FileAccess.get_open_error())
		return
	archivo.store_string(JSON.stringify(datos_partida(), "\t"))


func datos_partida() -> Dictionary:
	return {
		"version": VERSION_PARTIDA,
		"migas": migas,
		"niveles": niveles,
		"reclutadas": reclutadas,
		"runs_jugadas": runs_jugadas,
		"mejor_run": mejor_run,
		"radio_visto": radio_visto,
		"lugar": lugar_actual, "destinos": lugares_completados, "coronas_cobradas": coronas_cobradas, "hitos": hitos,
		"legado": legado, "coronas": coronas, "fundaciones": fundaciones, "prioridad": prioridad,
		"descubiertos": descubiertos,
		"jalea": jalea, "niveles_jalea": niveles_jalea, "migas_colonia": migas_colonia,
		"estadisticas": estadisticas, "decreto": decreto,
	}


func cargar() -> void:
	if not FileAccess.file_exists(RUTA_PARTIDA):
		return
	var datos = JSON.parse_string(FileAccess.get_file_as_string(RUTA_PARTIDA))
	if typeof(datos) != TYPE_DICTIONARY:
		push_warning("La partida guardada está dañada; se empieza de cero.")
		return
	restaurar_partida(datos)


func restaurar_partida(datos: Dictionary) -> void:
	migas = float(datos.get("migas", 0.0))
	runs_jugadas = int(datos.get("runs_jugadas", 0))
	mejor_run = float(datos.get("mejor_run", 0.0))
	radio_visto = float(datos.get("radio_visto", 0.0))
	lugares_completados = {}
	hitos = {}
	var destinos_guardados = datos.get("destinos", {})
	if destinos_guardados is Dictionary:
		for id in destinos_guardados:
			if Mundos.INFO.has(id) and destinos_guardados[id] == true:
				lugares_completados[id] = true
	# Partidas anteriores a este campo: se toma lo ya completado como cobrado
	# en la colonia actual, así no se puede volver a cobrar lo mismo.
	coronas_cobradas = {}
	var cobradas_guardadas = datos.get("coronas_cobradas", lugares_completados)
	if cobradas_guardadas is Dictionary:
		for id in cobradas_guardadas:
			if Mundos.INFO.has(id) and cobradas_guardadas[id] == true:
				coronas_cobradas[id] = true
	var hitos_guardados = datos.get("hitos", {})
	if hitos_guardados is Dictionary:
		for id in hitos_guardados:
			if HITOS.has(id) and hitos_guardados[id] == true:
				hitos[id] = true
	legado = clampi(int(datos.get("legado", 0)), 0, 1000000)
	jalea = clampi(int(datos.get("jalea", 0)), 0, 100000000)
	migas_colonia = maxf(0.0, float(datos.get("migas_colonia", migas)))
	if int(datos.get("version", 1)) < 4:
		# Antes cada punto de legado daba +10% y no se gastaba. Ahora cada jalea
		# da +3% y además se gasta: se convierte 1 a 3, para que el bonus pasivo
		# quede igual (9% ≈ 10%) y el jugador pueda gastar esa jalea.
		legado *= 3
		jalea = legado
	niveles_jalea = {}
	var jalea_guardada = datos.get("niveles_jalea", {})
	if jalea_guardada is Dictionary:
		for id in jalea_guardada:
			if jalea_por_id.has(id):
				niveles_jalea[id] = clampi(int(jalea_guardada[id]), 0, int(jalea_por_id[id].nivel_max))
	_cache_stats.clear()
	coronas = clampi(int(datos.get("coronas", 0)), 0, 1000000)
	fundaciones = maxi(0, int(datos.get("fundaciones", 0)))
	decreto = str(datos.get("decreto", ""))
	if not decretos_por_id.has(decreto):
		decreto = ""
	lugar_actual = str(datos.get("lugar", "casa"))
	if not destino_desbloqueado(lugar_actual):
		lugar_actual = "casa"
	prioridad = str(datos.get("prioridad", "automatico"))
	if prioridad not in ["automatico", "alimentos", "muebles", "estructuras"]:
		prioridad = "automatico"
	niveles = {}
	var guardados = datos.get("niveles", {})
	if typeof(guardados) == TYPE_DICTIONARY:
		for id in guardados:
			if mejoras_por_id.has(id):
				niveles[id] = clampi(int(guardados[id]), 0, nivel_maximo(id))
	# Las partidas v1 no tienen castas: conservan sus mejoras y empiezan sin reclutas.
	reclutadas = {}
	var castas_guardadas = datos.get("reclutadas", {})
	if typeof(castas_guardadas) == TYPE_DICTIONARY:
		for id in castas_guardadas:
			if castas_por_id.has(id) and castas_por_id[id].comprable:
				reclutadas[id] = clampi(int(castas_guardadas[id]), 0, int(castas_por_id[id].maximo))
	_cache_stats.clear()
	estadisticas = {}
	var guardadas = datos.get("estadisticas", null)
	if guardadas is Dictionary:
		for clave in guardadas:
			if clave in ESTADISTICAS and typeof(guardadas[clave]) in [TYPE_INT, TYPE_FLOAT]:
				estadisticas[clave] = maxf(0.0, float(guardadas[clave]))
	else:
		# Partida anterior a las estadísticas: lo que se sabe de antes.
		estadisticas.migas_totales = migas_colonia
	descubiertos = {}
	var vistos = datos.get("descubiertos", null)
	if vistos is Dictionary:
		for id in vistos:
			if REVELABLES.has(id):
				descubiertos[id] = vistos[id] == true
	else:
		# Partida anterior a la interfaz progresiva: lo que ya correspondía
		# mostrar queda visible sin marcarse como nuevo.
		for id in REVELABLES:
			if _condicion_revelar(id):
				descubiertos[id] = true


func reiniciar_estado() -> void:
	migas = 0.0
	niveles = {}
	reclutadas = {}
	runs_jugadas = 0
	mejor_run = 0.0
	radio_visto = 0.0
	lugar_actual = "casa"
	lugares_completados.clear()
	coronas_cobradas.clear()
	hitos.clear()
	legado = 0
	jalea = 0
	niveles_jalea = {}
	migas_colonia = 0.0
	coronas = 0
	fundaciones = 0
	decreto = ""
	prioridad = "automatico"
	descubiertos = {}
	estadisticas = {}
	_cache_stats.clear()


func borrar_partida() -> void:
	reiniciar_estado()
	if guardado_habilitado and FileAccess.file_exists(RUTA_PARTIDA):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA_PARTIDA))
	print("[Juego] Partida borrada")
	partida_borrada.emit()
	migas_cambiaron.emit(migas)


# =====================================================================
# Utilidades
# =====================================================================

## 1234 -> "1.23K", 5600000 -> "5.60M". Para números chicos con decimales usar formatear_corto.
func formatear(n: float) -> String:
	if n < 1000.0:
		return str(int(floor(n)))
	var exponente := int(floor(log(n) / log(1000.0)))
	var valor := n / pow(1000.0, exponente)
	if valor >= 999.995:
		exponente += 1
		valor /= 1000.0
	if exponente >= SUFIJOS.size():
		var exp10 := int(floor(log(n) / log(10.0)))
		return "%.2fe%d" % [n / pow(10.0, exp10), exp10]
	var texto: String
	if valor >= 100.0:
		texto = str(int(floor(valor)))
	elif valor >= 10.0:
		texto = "%.1f" % (floor(valor * 10.0) / 10.0)
	else:
		texto = "%.2f" % (floor(valor * 100.0) / 100.0)
	return texto + SUFIJOS[exponente]


## Igual que formatear, pero muestra un decimal en números menores a 10 (ej. "+0.7").
func formatear_corto(n: float) -> String:
	if n < 10.0 and absf(n - roundf(n)) > 0.05:
		return "%.1f" % n
	return formatear(n)


# =====================================================================
# Lectura de /datos
# =====================================================================

func _cargar_datos() -> void:
	castas.clear()
	castas_por_id.clear()
	for fila in _leer_csv(RUTA_CASTAS):
		var c := {
			"id": fila.id, "nombre": fila.nombre, "rol": fila.rol,
			"descripcion": fila.descripcion, "habilidad": fila.habilidad,
			"color": Color.from_string(fila.color, Color.WHITE),
			"comprable": fila.comprable == "1",
		}
		for campo in ["velocidad", "dano", "capacidad", "olfato", "escala", "costo_base", "crecimiento", "maximo"]:
			c[campo] = _num(fila[campo])
		castas.append(c)
		castas_por_id[c.id] = c
	stats_base.clear()
	for fila in _leer_csv(RUTA_STATS):
		stats_base[fila.stat] = _num(fila.valor)

	mejoras.clear()
	mejoras_por_id.clear()
	ramas.clear()
	for fila in _leer_csv(RUTA_MEJORAS):
		var m := {
			"id": fila.id,
			"nombre": fila.nombre,
			"rama": fila.rama,
			"descripcion": fila.descripcion,
			"stat": fila.stat,
			"tipo": fila.tipo,
			"valor": _num(fila.valor),
			"costo_base": _num(fila.costo_base),
			"crecimiento": _num(fila.crecimiento),
			"nivel_max": int(_num(fila.nivel_max)),
			"requiere_id": "",
			"requiere_nivel": 0,
			"destino": fila.get("destino", ""),
			"tope_por_destino": int(_num(fila.get("tope_por_destino", ""))),
			"elevable": fila.get("elevable", "") == "1",
			"bonus_cada": int(_num(fila.get("bonus_cada", ""))),
			"bonus_mult": _num(fila.get("bonus_mult", "")) if fila.get("bonus_mult", "") != "" else 1.0,
		}
		var requiere: String = fila.get("requiere", "")
		if requiere != "":
			var partes := requiere.split(":")
			m.requiere_id = partes[0].strip_edges()
			m.requiere_nivel = int(partes[1]) if partes.size() > 1 else 1
		if not stats_base.has(m.stat):
			push_error("Mejora '%s': la stat '%s' no existe en %s" % [m.id, m.stat, RUTA_STATS])
		if m.tipo != "suma" and m.tipo != "multiplica":
			push_error("Mejora '%s': el tipo tiene que ser 'suma' o 'multiplica'" % m.id)
		if m.destino != "" and not Mundos.INFO.has(m.destino):
			push_error("Mejora '%s': el destino '%s' no existe" % [m.id, m.destino])
		mejoras.append(m)
		mejoras_por_id[m.id] = m
		if not ramas.has(m.rama):
			ramas.append(m.rama)
	for m in mejoras:
		if m.requiere_id != "" and not mejoras_por_id.has(m.requiere_id):
			push_error("Mejora '%s' requiere '%s', que no existe" % [m.id, m.requiere_id])
			m.requiere_id = ""

	nodos_jalea.clear()
	jalea_por_id.clear()
	for fila in _leer_csv(RUTA_JALEA):
		var n := {
			"id": fila.id, "nombre": fila.nombre, "descripcion": fila.descripcion,
			"efecto": fila.efecto, "stat": fila.get("stat", ""), "tipo": fila.get("tipo", ""),
			"valor": _num(fila.get("valor", "")), "costo_base": _num(fila.costo_base),
			"crecimiento": _num(fila.crecimiento), "nivel_max": int(_num(fila.nivel_max)),
			"requiere_id": "", "requiere_nivel": 0,
		}
		var requiere: String = fila.get("requiere", "")
		if requiere != "":
			var partes := requiere.split(":")
			n.requiere_id = partes[0].strip_edges()
			n.requiere_nivel = int(partes[1]) if partes.size() > 1 else 1
		if n.efecto not in EFECTOS_JALEA:
			push_error("Jalea '%s': efecto desconocido '%s'" % [n.id, n.efecto])
		if n.efecto == "stat" and not stats_base.has(n.stat):
			push_error("Jalea '%s': la stat '%s' no existe" % [n.id, n.stat])
		nodos_jalea.append(n)
		jalea_por_id[n.id] = n

	decretos.clear()
	decretos_por_id.clear()
	for fila in _leer_csv(RUTA_DECRETOS):
		var d := {"id": fila.id, "nombre": fila.nombre, "descripcion": fila.descripcion, "efectos": []}
		for texto in String(fila.efectos).split(";", false):
			var partes := texto.strip_edges().split(":")
			if partes.size() != 3 or not stats_base.has(partes[0]) or partes[1] not in ["suma", "multiplica"]:
				push_error("Decreto '%s': efecto mal escrito '%s' (stat:suma|multiplica:valor)" % [d.id, texto])
				continue
			d.efectos.append({"stat": partes[0], "tipo": partes[1], "valor": _num(partes[2])})
		decretos.append(d)
		decretos_por_id[d.id] = d

	comidas.clear()
	for fila in _leer_csv(RUTA_COMIDAS):
		comidas.append({
			"id": fila.id,
			"nombre": fila.nombre,
			"forma": fila.forma,
			"color": Color.from_string(fila.color, Color.MAGENTA),
			"vida": _num(fila.vida),
			"recompensa": _num(fila.recompensa),
			"radio": _num(fila.radio),
			"distancia_min": _num(fila.distancia_min),
			"distancia_max": _num(fila.distancia_max),
			"cantidad": int(_num(fila.cantidad)),
			"zonas": fila.get("zonas", ""),
			# Destinos donde aparece ("" = en todos). Cada destino tiene sus comidas.
			"destinos": Array(String(fila.get("destinos", "")).split("|", false)),
		})
	for c in comidas:
		for d in c.destinos:
			if not Mundos.INFO.has(d):
				push_error("Comida '%s': el destino '%s' no existe" % [c.id, d])
	_cache_stats.clear()


## ¿La comida aparece en este destino?
func comida_en_destino(tipo: Dictionary, lugar: String) -> bool:
	return tipo.destinos.is_empty() or lugar in tipo.destinos


## Lee un CSV con encabezado y devuelve una lista de diccionarios (columna -> texto).
## Ignora filas vacías y filas que empiezan con '#'.
func _leer_csv(ruta: String) -> Array[Dictionary]:
	var filas: Array[Dictionary] = []
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		push_error("No se pudo abrir %s (error %d)" % [ruta, FileAccess.get_open_error()])
		return filas
	var encabezado := archivo.get_csv_line()
	for i in encabezado.size():
		encabezado[i] = encabezado[i].strip_edges().trim_prefix("﻿")
	while not archivo.eof_reached():
		var linea := archivo.get_csv_line()
		if linea.is_empty() or (linea.size() == 1 and linea[0].strip_edges() == ""):
			continue
		if linea[0].strip_edges().begins_with("#"):
			continue
		var fila := {}
		for i in encabezado.size():
			fila[encabezado[i]] = linea[i].strip_edges() if i < linea.size() else ""
		filas.append(fila)
	return filas


## Convierte texto a número aceptando coma decimal (Google Sheets en español exporta "1,5").
func _num(texto: String) -> float:
	return texto.strip_edges().replace(",", ".").to_float()

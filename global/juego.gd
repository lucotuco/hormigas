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
const VERSION_PARTIDA := 3
const RUTA_STATS := "res://datos/stats_base.csv"
const RUTA_MEJORAS := "res://datos/mejoras.csv"
const RUTA_COMIDAS := "res://datos/comidas.csv"
const RUTA_CASTAS := "res://datos/castas.csv"

const SUFIJOS: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

# --- Datos de balance (vienen de /datos) ---
var stats_base: Dictionary = {}          # nombre -> valor base
var mejoras: Array[Dictionary] = []      # en el orden del CSV
var mejoras_por_id: Dictionary = {}
var comidas: Array[Dictionary] = []
var ramas: Array[String] = []            # ramas del árbol en orden de aparición
var castas: Array[Dictionary] = []
var castas_por_id: Dictionary = {}

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
var legado := 0
var coronas := 0
var fundaciones := 0
var prioridad := "automatico"

# --- Run en curso ---
var migas_run: float = 0.0
var comidas_destruidas_run: int = 0
var partes_destruidas_run: int = 0
var mejor_combo_run: int = 0
var ultima_run_fue_record := false

## Ponerlo en false evita escribir el archivo de partida (lo usan las pruebas).
var guardado_habilitado := true

var _cache_stats: Dictionary = {}


func _ready() -> void:
	Engine.max_fps = 60
	_cargar_datos()
	cargar()


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

## Valor actual de una estadística: base + mejoras sumadas, por mejoras que multiplican.
func stat(nombre: String) -> float:
	if _cache_stats.has(nombre):
		return _cache_stats[nombre]
	if not stats_base.has(nombre):
		push_error("Stat desconocida: '%s'. Agregala en %s." % [nombre, RUTA_STATS])
		return 0.0
	var valor: float = stats_base[nombre]
	var multiplicador := 1.0
	for m in mejoras:
		if m.stat != nombre:
			continue
		var nivel := nivel_de(m.id)
		if nivel <= 0:
			continue
		if m.tipo == "suma":
			valor += m.valor * nivel
		else:
			multiplicador *= pow(m.valor, nivel)
	var resultado := _aplicar_legado(nombre, valor * multiplicador)
	_cache_stats[nombre] = resultado
	return resultado

func _aplicar_legado(nombre: String, resultado: float) -> float:
	if nombre in ["dano", "multiplicador_migas"]:
		resultado *= 1.0 + legado * 0.1
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
	var valor: float = stats_base[nombre]
	var multiplicador := 1.0
	for m in mejoras:
		if m.stat != nombre:
			continue
		var nivel := nivel_de(m.id) + (mini(cantidad, int(m.nivel_max) - nivel_de(id)) if m.id == id else 0)
		if m.tipo == "suma":
			valor += m.valor * nivel
		else:
			multiplicador *= pow(m.valor, nivel)
	return _aplicar_legado(nombre, valor * multiplicador)


func costo(id: String) -> float:
	var m: Dictionary = mejoras_por_id[id]
	return floor(m.costo_base * pow(m.crecimiento, nivel_de(id)))


func esta_al_maximo(id: String) -> bool:
	return nivel_de(id) >= int(mejoras_por_id[id].nivel_max)


func esta_desbloqueada(id: String) -> bool:
	var m: Dictionary = mejoras_por_id[id]
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
	return _cotizar(m.costo_base, m.crecimiento, nivel_de(id), m.nivel_max, cantidad, esta_desbloqueada(id))


func comprar_lote(id: String, cantidad := 1) -> int:
	var oferta := cotizar_mejora(id, cantidad)
	if not oferta.puede:
		return 0
	migas -= oferta.costo
	niveles[id] = nivel_de(id) + int(oferta.cantidad)
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
		entregadas = int(Mundos.INFO[lugar_actual].coronas)
		coronas += entregadas
	guardar()
	progreso_cambio.emit()
	return entregadas

func fundar_colonia() -> bool:
	if coronas <= 0:
		return false
	legado += coronas
	coronas = 0
	coronas_cobradas.clear()
	fundaciones += 1
	migas = 0
	niveles.clear()
	reclutadas.clear()
	radio_visto = 0
	_cache_stats.clear()
	guardar()
	migas_cambiaron.emit(migas)
	progreso_cambio.emit()
	return true


# =====================================================================
# Run
# =====================================================================

func iniciar_run() -> void:
	migas_run = 0.0
	comidas_destruidas_run = 0
	partes_destruidas_run = 0
	mejor_combo_run = 0
	ultima_run_fue_record = false


func sumar_migas_run(cantidad: float) -> void:
	migas_run += cantidad


func terminar_run() -> void:
	migas += migas_run
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
	coronas = clampi(int(datos.get("coronas", 0)), 0, 1000000)
	fundaciones = maxi(0, int(datos.get("fundaciones", 0)))
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
				niveles[id] = clampi(int(guardados[id]), 0, int(mejoras_por_id[id].nivel_max))
	# Las partidas v1 no tienen castas: conservan sus mejoras y empiezan sin reclutas.
	reclutadas = {}
	var castas_guardadas = datos.get("reclutadas", {})
	if typeof(castas_guardadas) == TYPE_DICTIONARY:
		for id in castas_guardadas:
			if castas_por_id.has(id) and castas_por_id[id].comprable:
				reclutadas[id] = clampi(int(castas_guardadas[id]), 0, int(castas_por_id[id].maximo))
	_cache_stats.clear()


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
	coronas = 0
	fundaciones = 0
	prioridad = "automatico"
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
		mejoras.append(m)
		mejoras_por_id[m.id] = m
		if not ramas.has(m.rama):
			ramas.append(m.rama)
	for m in mejoras:
		if m.requiere_id != "" and not mejoras_por_id.has(m.requiere_id):
			push_error("Mejora '%s' requiere '%s', que no existe" % [m.id, m.requiere_id])
			m.requiere_id = ""

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
		})
	_cache_stats.clear()


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

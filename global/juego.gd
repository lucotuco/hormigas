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

const RUTA_PARTIDA := "user://partida.json"
const VERSION_PARTIDA := 1
const RUTA_STATS := "res://datos/stats_base.csv"
const RUTA_MEJORAS := "res://datos/mejoras.csv"
const RUTA_COMIDAS := "res://datos/comidas.csv"

const SUFIJOS: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

# --- Datos de balance (vienen de /datos) ---
var stats_base: Dictionary = {}          # nombre -> valor base
var mejoras: Array[Dictionary] = []      # en el orden del CSV
var mejoras_por_id: Dictionary = {}
var comidas: Array[Dictionary] = []
var ramas: Array[String] = []            # ramas del árbol en orden de aparición

# --- Partida guardada ---
var migas: float = 0.0
var niveles: Dictionary = {}             # id de mejora -> nivel
var runs_jugadas: int = 0
var mejor_run: float = 0.0
var radio_visto: float = 0.0             # último radio de territorio que vio el jugador

# --- Run en curso ---
var migas_run: float = 0.0
var comidas_destruidas_run: int = 0
var mejor_combo_run: int = 0
var ultima_run_fue_record := false

## Ponerlo en false evita escribir el archivo de partida (lo usan las pruebas).
var guardado_habilitado := true

var _cache_stats: Dictionary = {}


func _ready() -> void:
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
	var resultado := valor * multiplicador
	_cache_stats[nombre] = resultado
	return resultado


func nivel_de(id: String) -> int:
	return int(niveles.get(id, 0))


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
	if not puede_comprar(id):
		return false
	migas -= costo(id)
	niveles[id] = nivel_de(id) + 1
	_cache_stats.clear()
	guardar()
	migas_cambiaron.emit(migas)
	mejora_comprada.emit(id, niveles[id])
	return true


# =====================================================================
# Run
# =====================================================================

func iniciar_run() -> void:
	migas_run = 0.0
	comidas_destruidas_run = 0
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
	var datos := {
		"version": VERSION_PARTIDA,
		"migas": migas,
		"niveles": niveles,
		"runs_jugadas": runs_jugadas,
		"mejor_run": mejor_run,
		"radio_visto": radio_visto,
	}
	var archivo := FileAccess.open(RUTA_PARTIDA, FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo guardar la partida (error %d)" % FileAccess.get_open_error())
		return
	archivo.store_string(JSON.stringify(datos, "\t"))


func cargar() -> void:
	if not FileAccess.file_exists(RUTA_PARTIDA):
		return
	var datos = JSON.parse_string(FileAccess.get_file_as_string(RUTA_PARTIDA))
	if typeof(datos) != TYPE_DICTIONARY:
		push_warning("La partida guardada está dañada; se empieza de cero.")
		return
	migas = float(datos.get("migas", 0.0))
	runs_jugadas = int(datos.get("runs_jugadas", 0))
	mejor_run = float(datos.get("mejor_run", 0.0))
	radio_visto = float(datos.get("radio_visto", 0.0))
	niveles = {}
	var guardados = datos.get("niveles", {})
	if typeof(guardados) == TYPE_DICTIONARY:
		for id in guardados:
			if mejoras_por_id.has(id):
				niveles[id] = mini(int(guardados[id]), int(mejoras_por_id[id].nivel_max))
	_cache_stats.clear()


func reiniciar_estado() -> void:
	migas = 0.0
	niveles = {}
	runs_jugadas = 0
	mejor_run = 0.0
	radio_visto = 0.0
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

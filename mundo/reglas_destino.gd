class_name ReglasDestino
extends Node
## Una regla por escenario. Los encadenamientos se procesan con presupuesto,
## no con llamadas recursivas ni simulaciones de otros destinos.
const DESCRIPCIONES := {
	"casa": "Abrí atajos · el banquito de cartón se puede devorar desde el inicio",
	"restaurante": "Servicio en cadena · hallar comida duplica la carga de frenesí por 8 s",
	"museo": "Vitrinas con secretos · la cubierta se abre al 80% y revela cinco alimentos",
	"obelisco": "Frentes debilitados · cada etapa del monumento aumenta el daño recibido",
	"coliseo": "Efecto dominó · los arcos devorados sacuden hasta dos vecinos",
	"eiffel": "Desarmado por pisos · vaciá la base antes de subir a la siguiente sección",
}
var run: Run
var festin := 0.0
var eventos := 0
var _pendientes: Array[Dictionary] = []
var _marcadas: Dictionary = {}
var _espera := 0.0
const MAX_CADENA := 24

func _ready() -> void:
	set_process(false)

func carga_frenesi() -> float:
	return 10.0 if festin > 0 else 5.0

func factor_dano(parte: PiezaCasa) -> float:
	return 1.0 + parte.etapa * 0.15 if Juego.lugar_actual == "obelisco" and parte.pieza.get("meta", false) else 1.0

func tesoro_abierto() -> void:
	eventos += 1
	if Juego.lugar_actual == "restaurante" or Juego.lugares_completados.has("restaurante"):
		festin = Juego.stat("festin_duracion")
		set_process(true)
		run.hud.mostrar_aviso("¡Servicio en cadena! Frenesí se carga al doble")

func cantidad_tesoro() -> int:
	return (5 if Juego.lugar_actual == "museo" else 3) + int(Juego.stat("tesoros_extra"))

func etapa_alcanzada(parte: PiezaCasa) -> void:
	eventos += 1
	if parte.pieza.get("meta", false):
		run.hud.mostrar_aviso(parte.nombre + " · " + parte.nombre_etapa())
		var r := parte.rect_mundo
		run.efectos.habilidad(r.position, Vector2(r.end.x, r.position.y), Color("f3cf78"))

func parte_devorada(parte: PiezaCasa) -> void:
	var arco: bool = Juego.lugar_actual == "coliseo" and parte.pieza.tipo == "arco"
	var fuerza := 0.6 if arco else Juego.stat("domino")
	if fuerza <= 0 or parte.pieza.pared or _marcadas.size() >= MAX_CADENA:
		return
	var vecinos: Array[PiezaCasa] = []
	for otra in run.comidas.partes:
		if otra != parte and (otra.pieza.tipo == "arco" if arco else not otra.pieza.pared) and not otra.pieza.get("meta", false) and not _marcadas.has(otra.pieza.clave) and otra.disponible() and otra.en_territorio(run.radio_actual) and otra.position.distance_squared_to(parte.position) < 1100 * 1100:
			vecinos.append(otra)
	vecinos.sort_custom(func(a: PiezaCasa, b: PiezaCasa) -> bool: return a.position.distance_squared_to(parte.position) < b.position.distance_squared_to(parte.position))
	for i in mini(2, vecinos.size()):
		if _marcadas.size() >= MAX_CADENA:
			break
		var otra := vecinos[i]
		_marcadas[otra.pieza.clave] = true
		_pendientes.append({"parte": otra, "desde": parte.position, "fuerza": fuerza})
	set_process(true)

func _process(delta: float) -> void:
	if not is_instance_valid(run) or not run.activa:
		_pendientes.clear()
		festin = 0
		set_process(false)
		return
	festin = maxf(0, festin - delta)
	_espera -= delta
	if _espera <= 0 and not _pendientes.is_empty():
		_espera = 0.12
		var pedido: Dictionary = _pendientes.pop_front()
		var parte = pedido.parte
		if is_instance_valid(parte) and parte.disponible():
			# El valor extraído sigue siendo transportable; no se pierde el 65%.
			var extraido: float = parte.morder_en(parte.vida_max * pedido.fuerza, pedido.desde)
			run.comidas.soltar_fragmento(parte.position, extraido, parte.nivel_requerido)
			run.efectos.chispas(parte.position, parte.color, 12)
			run.efectos.habilidad(pedido.desde, parte.position, Color("e4bb85"))
			eventos += 1
	if festin <= 0 and _pendientes.is_empty():
		set_process(false)

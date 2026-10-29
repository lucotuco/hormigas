extends Node
## Alcance inmediato, caché geométrica y recuperación: sin FPS simulados,
## sin monedas inventadas ni cambios en la partida del jugador.
class PiezaContada extends PiezaCasa:
	var consultas_alcance := 0
	func alcanza_desde(pos: Vector2) -> bool:
		consultas_alcance += 1
		return super.alcanza_desde(pos)

var total := 0
var fallas := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Engine.max_fps = 0
	seed(407)
	await probar_alcance_inmediato()
	await probar_alcance_retenido()
	await probar_recuperacion_sin_orden()
	Juego.reiniciar_estado()
	print("Autonomía de casa: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)

func crear() -> Run:
	Juego.reiniciar_estado()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._activa = false
	return run

func agregar_comida(run: Run, pos: Vector2, vida := 100.0) -> Comida:
	var datos: Dictionary = Juego.comidas[0].duplicate()
	datos.vida = vida
	run.comidas._crear(datos, pos, 407)
	return run.comidas.lista.back()

func probar_alcance_inmediato() -> void:
	var run := crear()
	run.comidas._indice.clear()
	var punto := Vector2(-100, -130)
	var alimento := agregar_comida(run, punto)
	var h := run.colonia._nacer("obrera", punto + Vector2(2, 0))
	h._esperando_ruta = true
	var antes := run.cocina.consultas_ruta
	h._pensar()
	verificar(h.comida == alimento and h.estado == Hormiga.Estado.MORDIENDO, "la comida al alcance se trabaja sin caminar hasta su centro")
	verificar(not h._esperando_ruta and run.cocina.consultas_ruta == antes, "la mordida inmediata libera el turno y no solicita una ruta")
	verificar(alimento.trabajadoras == 1 and Juego.migas_run == 0, "se reserva el puesto sin cobrar antes de extraer y transportar")
	var segunda := run.colonia._nacer("obrera", punto)
	segunda._pensar()
	verificar(segunda.comida != alimento and alimento.trabajadoras <= alimento.cupos_trabajo(), "el atajo respeta los cupos de trabajo autónomo")
	h.detener()
	verificar(alimento.trabajadoras == 0, "detener una obrera libera su puesto inmediato")
	run.queue_free()
	await get_tree().process_frame

func probar_alcance_retenido() -> void:
	var run := crear()
	Juego.niveles.mordida_madera = 1
	Juego._cache_stats.clear()
	run.radio_actual = 2000
	var fuente := run.comidas.partes[6]
	var pieza := PiezaContada.new()
	run.comidas.add_child(pieza)
	pieza.iniciar(fuente.pieza.duplicate(true), run.cocina)
	var h := run.colonia._nacer()
	h.position = pieza.punto_mordida(Vector2.ZERO, run.radio_actual)
	h.comida = pieza
	h.estado = Hormiga.Estado.MORDIENDO
	h._reloj_mordida = 1000
	pieza.consultas_alcance = 0
	for i in 120:
		h._morder(1.0 / 60)
	verificar(pieza.consultas_alcance == 1 and h.estado == Hormiga.Estado.MORDIENDO, "120 cuadros quieta comprueban el alcance geométrico una sola vez")
	var previo := pieza.consultas_alcance
	pieza.version_forma += 1
	h._morder(1.0 / 60)
	verificar(pieza.consultas_alcance == previo + 1, "una sección que cambia invalida el alcance retenido")
	h.position += Vector2(0, 0.1)
	previo = pieza.consultas_alcance
	h._morder(1.0 / 60)
	verificar(pieza.consultas_alcance == previo + 1, "cualquier desplazamiento vuelve a comprobar el frente de mordida")
	h.position = Vector2(-500, -200)
	h._morder(1.0 / 60)
	verificar(h.estado == Hormiga.Estado.YENDO_A_COMIDA, "si el material ya no llega a la boca se busca un borde nuevo")
	var otra := PiezaContada.new()
	run.comidas.add_child(otra)
	otra.iniciar(fuente.pieza.duplicate(true), run.cocina)
	h.position = otra.punto_mordida(Vector2.ZERO, run.radio_actual)
	h.comida = otra
	h.estado = Hormiga.Estado.MORDIENDO
	h._morder(1.0 / 60)
	verificar(otra.consultas_alcance == 1 and pieza.trabajadoras == 0, "cambiar de recurso no reutiliza el alcance de la pieza anterior")
	h.carga = 9
	h.position = Vector2(-500, -200)
	h._morder(1.0 / 60)
	verificar(h.estado == Hormiga.Estado.VOLVIENDO and h.carga == 9 and Juego.migas_run == 0, "una obrera alejada con carga vuelve a entregarla sin cobro remoto")
	run.queue_free()
	await get_tree().process_frame

func probar_recuperacion_sin_orden() -> void:
	var run := crear()
	run.comidas._indice.clear()
	var punto := Vector2(-100, -130)
	var primera := agregar_comida(run, punto)
	var segunda := agregar_comida(run, punto + Vector2(30, 0))
	var h := run.colonia._nacer("obrera", punto)
	h._pensar()
	primera.morder(primera.vida)
	h._morder(0.1)
	h._pensar()
	verificar(h.comida == segunda and primera.trabajadoras == 0, "si otra obrera termina el objetivo se reserva el siguiente sin conservar el anterior")
	var estable := h.objetivo
	for i in 20:
		h._pensar()
	verificar(h.comida == segunda and h.objetivo == estable and segunda.trabajadoras == 1, "la reelección conserva un puesto estable en vez de cambiarlo en cada decisión")
	segunda.morder(segunda.vida)
	h._morder(0.1)
	h._pensar()
	verificar(h.comida == null and h.estado == Hormiga.Estado.EXPLORANDO and h.objetivo != Vector2.INF, "agotado el último trabajo cercano vuelve a explorar con destino válido")
	run.queue_free()
	await get_tree().process_frame

func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)

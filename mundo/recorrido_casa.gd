class_name RecorridoCasa
extends Node
## Una sugerencia física a la vez. Cachea referencias al generar: no agrega
## búsquedas a las hormigas, nuevas cerraduras ni recompensas automáticas.
signal etapa_cambio(id: String)
var run: Run
var id_actual := ""
var _silla: PiezaCasa
var _alacena: PiezaCasa
var _paquete: Comida
var _premio: Comida
var _habilitado := false


func iniciar(r: Run) -> void:
	run = r
	_habilitado = Juego.lugar_actual == "casa" and not Juego.lugares_completados.has("casa")
	if not _habilitado:
		return
	for parte in run.comidas.partes:
		if parte.pieza.get("perfil", "") == "silla_inicial":
			_silla = parte
		elif parte.pieza.get("componentes_id", "") == "casa/alacena_cocina":
			_alacena = parte
	for comida in run.comidas.lista:
		if comida.id == CatalogoHallazgos.PREFIJO_ENVOLTORIO + "bolsa_cereal":
			_paquete = comida
			break
	run.comidas.atajo_abierto.connect(_al_abrir_atajo)


## Se consulta con el refresco existente del HUD. Nunca compra ni completa
## una etapa por ver su ficha; los recuerdos vienen del material real.
func meta() -> Dictionary:
	var resultado := _resolver()
	var id: String = resultado.get("id", "")
	if id != id_actual:
		id_actual = id
		etapa_cambio.emit(id)
	return resultado


func _resolver() -> Dictionary:
	if not _habilitado or not is_instance_valid(run) or not run.activa or run.terminada:
		return {}
	if _vivo(_premio):
		return _escena("galletita_atajo", tr("La galletita del atajo"),
			tr("El camino quedó libre. Ahora llevá la comida al nido."), _premio)
	if Juego.stat("materiales") >= 1:
		if _vivo(_silla):
			return _escena("silla_atajo", tr("Abrí un atajo"),
				tr("Desarmá esta silla: hay una galletita detrás."), _silla)
		if _vivo(_alacena) and _alacena.en_territorio(run.radio_actual) \
			and not Juego.tesoro_proyecto_abierto("casa/alacena_cocina"):
			var datos := _escena("hoja_alacena", tr("¿Qué guarda la alacena?"),
				tr("Vaciá una hoja. El hueco y el hallazgo se conservan."), _alacena)
			datos.zona = Rect2(_alacena.rect_mundo.position, _alacena.rect_mundo.size * Vector2(0.5, 1.0))
			return datos
	elif int(Juego.stat("hormigas_iniciales")) + Juego.total_especialistas() >= 2 and _vivo(_paquete) \
		and _paquete.en_territorio(run.radio_actual) and not Juego.hallazgo_casa_abierto("bolsa_cereal"):
		return _escena("primer_paquete", tr("Algo cruje dentro"),
			tr("Abrí la bolsita entre varias hormigas y descubrí el cereal."), _paquete)
	return {}


func _vivo(objetivo) -> bool:
	return is_instance_valid(objetivo) and not objetivo.muerta and objetivo.disponible()


func _escena(id: String, nombre: String, detalle: String, objetivo: Comida) -> Dictionary:
	var zona: Rect2 = objetivo.rect_mundo if objetivo is PiezaCasa else Rect2(objetivo.position - Vector2.ONE * objetivo.radio, Vector2.ONE * objetivo.radio * 2)
	return {"tipo": "escena", "id": id, "nombre": nombre, "detalle": detalle,
		"objetivo": objetivo, "zona": zona, "accion": "mapa", "seccion": "hogar"}


func _al_abrir_atajo(comida: Comida) -> void:
	_premio = comida
	_celebrar_atajo.call_deferred()


func _celebrar_atajo() -> void:
	if not run.activa or run.terminada or not _vivo(_premio):
		return
	run.hud.mostrar_aviso(tr("¡Atajo abierto! Hay una galletita detrás."))
	run.efectos.habilidad(Vector2.ZERO, _premio.position, Color("eac67e"))
	run.efectos.epico(_premio.position, Color("eac67e"), 40)
	Sonido.tocar("crecer", 1.05, 0.0)
	etapa_cambio.emit("atajo_abierto")

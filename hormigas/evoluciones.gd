class_name EvolucionesHormiga
extends RefCounted
## Se desbloquean para siempre; se equipan dos sin costo entre expediciones.
const MAX_EQUIPADAS := 2
const DATOS := {
	"corte": {"nombre": "Corte aserrado", "casta": "carpintera", "unidades": 1, "mandibulas": 4, "detalle": "Corta dos secciones de madera y deja toda la extracción en montones. Sigue trabajando sin volver al nido; combiná con cargadoras que retiren los restos."},
	"contagio": {"nombre": "Nube corrosiva", "casta": "roja", "unidades": 3, "mandibulas": 4, "detalle": "Cada 1.5 s contagia veneno a hasta dos objetivos a menos de 55 unidades."},
	"barrido": {"nombre": "Barrido de restos", "casta": "cargadora", "unidades": 3, "mandibulas": 4, "detalle": "Al levantar un montón recoge hasta dos restos adicionales en un radio de 48."},
	"camada": {"nombre": "Camada real", "casta": "reina", "unidades": 1, "mandibulas": 8, "detalle": "Despliega tres miniobreras por tanda. Conserva los topes de reina y colonia."},
}

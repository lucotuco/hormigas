# Probar la casa hasta la primera fundación

Objetivo: comprobar que alguien entiende y quiere repetir el ciclo, no sólo
que los scripts funcionan. Las pruebas automáticas y el bot no responden eso.

## Qué estamos tratando de mejorar

La referencia de calidad es un recorrido de la casa que se pueda disfrutar y
entender sin conocer sus sistemas. No se busca igualar la cantidad de pantallas
de otro juego ni llenar cada segundo de mensajes. La fantasía que se evalúa es
«una hormiga trae una miga; una colonia termina desarmando una casa».

Durante esta revisión separar estas cuatro preguntas. Una puede fallar aunque
las otras pasen:

| Pregunta | Qué mirar jugando | Qué no demuestra una prueba automática |
|---|---|---|
| ¿Se entiende el trabajo? | El contacto retira una porción, la carga corresponde al hueco y el cobro ocurre al volver. | Conservar masa y dinero no garantiza que se reconozca en pantalla. |
| ¿Se nota una compra? | La persona puede describir el cambio después de usarlo, sin leerle el efecto. | Un aumento de stat o un cartel no garantiza una recompensa perceptible. |
| ¿Hay consecuencias? | La persona encuentra algo, abre un paso o termina una parte reconocible y cambia su plan. | Completar un porcentaje o mostrar partículas no equivale a descubrir contenido. |
| ¿Hay esfuerzo y dominio? | Algo antes costoso se vuelve fluido; luego aparece una posibilidad distinta, no sólo más resistencia. | El promedio de migas/s y el tiempo del bot no describen esa sensación. |

No mostrar esta tabla al participante antes de jugar: condicionaría lo que
busca y las palabras con las que después describe su experiencia.

## Sesión aislada para jugar

1. Abrí el proyecto con Godot **4.7.2**.
2. Abrí `tests/sesion_casa.tscn` y ejecutá esa escena con **F6**, no el juego
   normal con F5. El menú debe indicar que es una sesión de prueba.
3. Jugá normalmente: el ensayo empieza desde cero en memoria. La carga inicial
   de los autoloads no se usa para progresar y se deshabilitan las escrituras
   de partida/configuración antes de permitir interacciones. No borra archivos.
4. **F7** abre/cierra el informe y conserva la pausa que había antes. **F8**
   sigue deteniendo la ejecución desde Godot. F1/F2/F9 no dan dinero ni borran
   durante el ensayo.
5. Si quieren conservar resultados, elegí **Exportar informe JSON** y un archivo
   nuevo. No se exporta automáticamente, no se envía nada y no contiene nombres,
   archivos personales ni la partida completa. Cerrar la ejecución descarta el
   progreso del ensayo. Después F5 vuelve al juego y a la partida normal.

El informe guarda las primeras compras/dietas/hitos/fundación, hasta 256 eventos
y las últimas 32 expediciones. Las pausas no suman tiempo activo. El primer
ingreso se observa a 10 Hz y puede incluir premios o corrosión: **no es una
medición de primera entrega**. El informe v2 también registra por separado la
**primera entrega real**, por la señal que emite el regreso al nido. No atribuye
un premio ni la aparición de comida a una hormiga que todavía no transportó.
Las compras, etapas del recorrido y el atajo se registran por señal; las partes,
paquetes y escondites completos, una sola vez. Las compras incluyen una muestra
de las capacidades reales para compararlas con lo que la persona notó.
No inspecciona cada hormiga ni añade procesos al juego normal. Sólo guarda tres
hitos de entregas por expedición y sus totales; una colonia grande no llena el
informe con miles de eventos. La exportación continúa siendo manual y local.

## Contexto vigente para quien observa

La partida nueva empieza con **una obrera**; Más obreras cuesta inicialmente
12 migas y suma **una por nivel**. La mordida base es de 0,95 s y la expedición
inicial dura 45 s, conservando velocidad, olfato e IA. La comprobación guiada
actual apunta a migas pequeñas existentes, no a la caja grande de cartón. Seis
de las mismas migas nativas se redistribuyen en el acceso al empezar, sin
cambiar cantidad, vida ni recompensa; el piloto histórico siguiente no mide
esa nueva distribución.
Las mediciones del 29/10 guiadas al cartón preceden al bocado local y no
describen el nuevo ritmo. El piloto del 30/10 pagó la segunda hormiga de 12
migas tras cuatro expediciones autónomas (~181 s activos) o tres guiadas a
migas existentes (~137 s), sin regalos. No imponer esos plazos a participantes
ni sugerirles compras. Anotar si reconocen el cambio de una a dos y si el
arranque lento despierta interés o los hace esperar sin propósito.

El piloto del 4/11 con mapa 11 recorrió 24 expediciones desde cero en 26,13 min
simulados: segunda obrera después de tres expediciones, madera a 10,06 min y
primera silla a 11,75 min. Incluye interacción con doradas y amenazas y no
incluye deliberación en tienda. Verifica que se puede recorrer la escena con
ingresos reales, no que una persona vaya a tardar eso o quiera seguir jugando.

El cartón tiene 20 de resistencia y 180 de valor; la primera silla de madera,
280/420. Su resistencia no aumenta la recompensa. Observar si entienden que
las mordidas retiran material, ven salir una muestra en la carga y distinguen
extraer, transportar y cobrar. No exigir que una obrera derrumbe el cartón o
que Memoria sola elimine una celda de silla en la primera expedición.

Los recortes acumulan lo retirado y no deben reaparecer al cambiar de flanco.
El bocado normal retira una porción local de hasta seis unidades de mundo
por lado: fuente, hueco y carga deben mantener la misma escala, sin encoger
la muestra después de quitar un bloque grande. El material retirado viaja
completo; ya no se reparte automáticamente 65/35 entre carga y montones.
La navegación sigue agrupada por celdas: un pequeño mordisco visible no
garantiza un paso transitable. La caja de cartón conserva 110×130 y es un
proyecto para una colonia más capaz, no una fuente de 180 migas instantáneas
para la primera hormiga. El daño parcial del escenario se reinicia en cada
expedición; los componentes terminados se conservan. En la silla inicial,
respaldo/asiento y patas/base tienen marcas completas independientes: quitar
un porcentaje no conserva un porcentaje ficticio de HP. Una vez desarmada toda
la silla, se abre el segmento directo del nido y aparece una galletita nativa
que antes estaba reservada. No es otra recompensa añadida al catálogo ni un
cobro por descubrirla: hay que extraerla y transportarla. El paso y las partes
terminadas sobreviven a fundar, sin otra galletita de premio ni pago repetido.

Esta escena no convierte la casa en una cadena obligatoria de objetivos ni
exige seguir la sugerencia. El paquete, la silla y la hoja de alacena conectan
lo que ya puede hacer la colonia con una consecuencia visible. Observar si la
persona entiende la ventaja del paso o sólo lee el cartel; si una compra le
permite reconocer una posibilidad distinta y si quiere ir a mirar qué había.

Se reutiliza el mismo atlas, sin textura ni cuerpo por bocado. La representación
sigue siendo estilizada, no una simulación volumétrica ni una garantía de
detalle distinguible para cada mordida tardía. Separar problemas observados
de esas limitaciones previstas.

## Cómo observar sin enseñar

Hagan primero 5–10 sesiones con personas que no hayan visto el proyecto.
No explicar controles ni recomendar compras mientras juegan; registrar cada
intervención si de verdad necesitan ayuda. Evitar que todos vean antes una
demostración hecha por ustedes.

Anotar, con permiso para observar su juego:

- Cuándo entienden que la colonia trabaja sola y para qué sirve el llamado.
- Si notan recortes, retazos y fragmentos; si relacionan la carga con lo retirado y quieren probar un mueble nuevo.
- Qué compra eligen, qué creen que cambiará y si después pueden reconocerlo.
- Cuándo no saben qué hacer, esperan sin propósito, piden ayuda o quieren salir.
- Si entienden qué pierden/conservan al fundar y si el regreso se siente más fuerte.
- Si eligen otra expedición por iniciativa propia, sin pedirles que sigan.

Al terminar preguntar sin sugerir respuestas: “¿qué momento recordás?”,
“¿qué cambiarías primero?” y “¿cómo se lo describirías a un amigo?”. El informe
no reemplaza esas respuestas ni registra conversaciones.

Como criterios internos de avance hacia una demo: la mayoría puede identificar
su próximo objetivo y anticipar una compra sin ayuda; reconoce la diferencia
tras fundar; no necesita el llamado para reparar una IA detenida; y puede
recordar un momento propio del juego. Son objetivos de diseño, no porcentajes
de éxito comercial ni resultados ya obtenidos.

### Una hoja por sesión

Usar un identificador local anónimo (por ejemplo, `casa_01`), versión del mapa,
resolución y equipo. No hace falta nombre, correo ni grabación de la persona.
Si se graba la pantalla, pedir permiso y guardar sólo gameplay. El archivo
JSON se exporta únicamente si la persona acepta; no se envía a un servidor.

Anotar cada momento con el tiempo activo visible en el informe:

| Momento | Qué esperaba la persona | Qué reconoció después | Intervención del observador |
|---|---|---|---|
| Primera miga transportada y cobrada | | | |
| Primera compra elegida | | | |
| Primera compra cuyo cambio no notó | | | |
| Primer objeto o parte que quiso terminar | | | |
| Primer descubrimiento o acceso nuevo | | | |
| Primer tramo que sintió fluido | | | |
| Primera espera sin un propósito claro | | | |
| Decisión de repetir, fundar o salir | | | |

No forzar que ocurran todos. Si sale antes, ese punto es un resultado válido;
registrar qué había entendido y qué estaba intentando. Un recorrido observado
no se convierte en una duración comercial ni en un porcentaje de éxito.

Después de cada tanda de cinco sesiones, elegir el problema repetido que más
daña el ciclo central y corregirlo antes de sumar otra mecánica. Comparar una
revisión con la siguiente usando personas nuevas o declarando que ya conocen
el juego. Separar fallas técnicas, falta de claridad y falta de interés: no
tienen necesariamente la misma solución.

## Equipos y rendimiento

Probar también una GPU integrada, una sesión de al menos una hora y repetidos
alt-tab/capturas. Comprobar que pausa, arrastre y feromonas se liberan y reanudan
bien. Mantener el tope de 500 y el presupuesto de seis rutas por cuadro.
Medir cuadro medio/p95/picos con renderer real; headless no mide FPS. No abrir
varios perfiles simultáneamente. Los resultados RTX 3060 son sólo una referencia.

## Después de esta validación

Primero corregir lo observado en este recorrido; después extender aprendizajes
a los destinos tardíos y definir su cierre sin impedir seguir creciendo.
Para una demo pública faltan distribución/exportación, pruebas en otras PCs,
identidad y audio final, página de Steam y revisión humana de traducciones.
Esta herramienta F6 no se presenta como una demo comercial terminada.

Un primer clip debe mostrar gameplay real: migas → recortes de una silla →
compra visible → colonia más capaz. No acelerar la simulación para prometer
tiempos irreales ni usar un render que no exista jugando. La fantasía que se
quiere comunicar es una colonia pequeña que termina desarmando una casa.

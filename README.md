# Hormigas 🐜

Incremental para PC hecho en **Godot 4.7.2**. Guiás a tu colonia manteniendo el clic donde querés reunir hormigas para que se coma todo lo que hay en la casa. Cada run dura unos segundos; con lo recolectado mejorás el hormiguero, el territorio crece y aparece comida más grande (y más lejos).

## Arrancar

1. Instalen **Godot 4.7.2** los dos (la versión estándar, no la .NET). Importante: **la misma versión exacta**, si no el editor reescribe archivos y aparecen conflictos.
2. Cloná el repo y abrí `project.godot` desde Godot (Importar → elegir la carpeta).
3. La primera vez tarda unos segundos en importar los recursos.
4. **F5** para jugar.

## Controles

| Acción | Cómo |
|---|---|
| Atraer las hormigas más cercanas | Mantener clic izquierdo en el destino; moverlo cambia el punto, soltar termina la orden |
| Acercar o alejar el mapa | Rueda del mouse; el zoom apunta al cursor |
| Moverse por el mapa | Arrastrar con botón derecho o central; también WASD o flechas |
| Volver al hormiguero y al encuadre automático | R |
| Ver el plano de la casa completa | H |
| Enfocar el gran objetivo del destino | G o botón Gran objetivo |
| Priorizar alimentos, muebles o estructuras | Botones de la barra inferior; el llamado manual siempre manda |
| Pausa (seguir, configuración, estadísticas, terminar o salir al menú) | Esc |
| Silenciar sonido | M |
| Pantalla completa | F11 |

El juego arranca en el **menú principal** (Jugar o Continuar, Estadísticas,
Configuración y Salir). La configuración (idioma, sonido, volumen, pantalla
completa, temblor de cámara, pausar al cambiar de ventana y borrar la partida)
se guarda aparte de la partida, en `user://ajustes.cfg`. La expedición se pausa
sola cuando la ventana pierde el foco. Al abrir una captura de pantalla o
cambiar de aplicación se sueltan las feromonas y el arrastre de cámara;
al volver, **Seguir** reanuda la misma expedición. Esta pausa se puede
desactivar con **Pausar al cambiar de ventana**.

### Atajos de desarrollo (solo al correr desde el editor)

| Tecla | Efecto |
|---|---|
| F1 | +1000 migas |
| F2 | Migas ×10 |
| F9 | Borrar la partida guardada |

## Estructura

```
res://
  global/        Autoloads, disponibles desde cualquier script
    juego.gd       "Juego": estado, partida guardada, stats, mejoras, lectura de /datos
    sonido.gd      "Sonido": efectos con pool de reproductores
    graficos.gd    "Graficos": atlas generado una sola vez para hormigas, comida y muebles
    ajustes.gd     "Ajustes": configuración del jugador (user://ajustes.cfg)
  hormigas/
    hormiga.gd     Máquina de estados de una hormiga (explorar, responder al llamado, morder, volver)
    colonia.gd     Hace nacer hormigas y ajusta su tamaño al zoom
  mundo/
    run.tscn       Una run completa
    run.gd         Coordina la run: inicio, fin, combos y comida destruida
    comidas.gd     Genera el mapa (siempre igual, semilla fija) y busca comida cercana
    comida.gd      Una comida: vida, grietas, sacudida, dibujo por forma
    feromonas.gd   Punto de atracción activo mientras se mantiene el clic
    plano_casa.gd  Siete ambientes, paredes, puertas, muebles y límites compartidos
    dibujo_casa.gd Ilustración de muebles y detalles de la casa
    cocina.gd     Navegación compartida por grilla, con rutas para caminantes y voladoras
    pieza_casa.gd Muebles y tramos de muro comestibles, con colisión y resistencia
    materiales_casa.gd Etapas, resistencia, recompensas y división de paredes en tramos
    mundos.gd     Seis destinos y sus planos, objetivos y progresión de campaña
    fragmento_casa.gd Montones de fragmentos transportables, sin física individual
    roles_hormiga.gd Afinidades por material, carga y preferencias de las castas
    hormiguero.gd  La entrada del hormiguero en (0, 0)
    niebla.gd      Oscuridad fuera del territorio
    efectos.gd     Partículas, ondas y números flotantes (todo en un nodo)
    camara.gd      Zoom según el territorio + sacudidas
    suelo.gd       Pisos de madera, cerámica y baldosas por ambiente
  ui/
    menu.tscn      ESCENA PRINCIPAL: menú con el destino actual de fondo
    hud.gd         Migas, tiempo, combo, avisos, pausa y panel de fin de run
    ventana_modal.gd  Base de las ventanas (configuración, estadísticas, pausa)
    panel_configuracion.gd / panel_estadisticas.gd
    tienda.gd      El hormiguero de mejoras entre runs: ficha, compras y secciones
    arbol_hormiguero.gd  Vista del hormiguero: arrastrar, zoom y capas de dibujo
    plano_hormiguero.gd  Dónde está cada cámara y por dónde pasan sus túneles
    arte_camara.gd Forma, contenido y rastro de cada rama
    estilo.gd      Colores y helpers de interfaz compartidos
  datos/         Tablas de balance (CSV)
  idiomas/       en.po: el inglés de todos los textos (ver idiomas/LEEME.md)
  sonidos/       Efectos .wav
  tests/         Prueba de humo
```

### Cómo se conectan las piezas

- **`Juego`** (autoload) es la única fuente de verdad: migas, niveles de mejoras y la stat actual de cualquier cosa con `Juego.stat("velocidad")`. Las stats salen de `stats_base.csv` + las mejoras compradas.
- **`run.gd`** es el centro de la run. Las hormigas le avisan con `run.depositar(cantidad)` cuando llegan con comida; las comidas emiten la señal `destruida` y `comidas.gd` la reenvía a la run, que suma bonus, lanza efectos y sacude la cámara.
- Todo cuelga de nodos en el origen y el hormiguero está en (0, 0), así que posición local = posición global.
- La interfaz (HUD y tienda) se arma por código, para no tener que editar escenas a la par.

## Casa y hormiguero

La resolución base del juego es **1920 × 1080**; las ventanas menores escalan
el lienzo, no cambian la resolución de diseño.

### El hormiguero de mejoras

La tienda es un corte de tierra de 1700 × 1900 con la **reina en el centro**
(abre la Jalea real), **Viajes en la boca** y la **sala de Castas** (fichas
completas y evoluciones) en el túnel principal. Alrededor salen siete ramas:
Castas, Colonia, Recolección, Mandíbulas, Feromonas, Tiempo y Territorio, con
89 cámaras: 82 mejoras y las 7 castas que se reclutan. Las ramas se separan y
se vuelven a juntar: las **cámaras compartidas** (borde punteado) piden una
mejora de cada rama, y algunos túneles cruzan de una rama a otra. Cada túnel
que llega a una cámara sale de uno de sus requisitos reales.

- **Pasar el mouse** abre la ficha: nombre, nivel, efecto, el valor antes y
  después, el precio y qué le falta si está cerrada. **Un clic** mejora (o
  recluta, en las castas); clic derecho en una casta abre su ficha completa.
- Se recorre **arrastrando** y con la **rueda**. Al entrar encuadra lo ya
  explorado; la leyenda de arriba a la izquierda encuadra cada rama y cuenta
  cuántas cámaras podés comprar en cada una. "Ver mejora" acerca la cámara.
- Cada rama se reconoce sin leer: forma de la cámara y lo que guarda adentro,
  que crece con el nivel (huevos en Colonia, pilas de migas en Recolección,
  astillas y metal en Mandíbulas, gotas que brillan en Feromonas, reservas
  colgando en Tiempo, tierra y raíces en Territorio, especialistas en Castas).
  Feromonas, Recolección y Tiempo dejan rastro en sus túneles. Los túneles
  hacia una cámara cerrada se van cavando a medida que sube el requisito.
- Las mejoras de destino aparecen como cámaras sin excavar hasta que se
  revelan los viajes. Las castas y las secciones se descubren como antes.

El plano (posiciones y túneles) está en `ui/plano_hormiguero.gd`; el dibujo de
cada rama, en `ui/arte_camara.gd`. El suelo y las cámaras se dibujan una vez
por compra; mover o acercar la vista no redibuja. Veintidós hormigas
decorativas recorren los túneles cavados a 30 Hz, sin IA ni navegación de la run.

Los botones **×1, ×10 y Máx** se comparten entre mejoras y castas.
×10 compra el lote completo (o los niveles restantes hasta el límite); Máx
calcula cuántos podés pagar. El precio suma el costo creciente de cada nivel,
se cobra una sola vez y la vista previa muestra el resultado del lote entero.
El sonido se
puede silenciar y regular desde el pie de la tienda; `M` sigue funcionando.

La casa tiene cocina, comedor, living, pasillo, dormitorio, estudio y baño/lavadero.
Los seis planos tienen más objetos útiles para devorar, sin agrandar zonas vacías:
63 muebles en casa, 57 en restaurante, 37 en museo, 41 en Buenos Aires, 47 en
Roma y 45 en París, incluyendo la periferia. Alrededor del Obelisco hay colectivo, taxi, kioscos y carteles
de la avenida; Roma suma columnas, ánforas y fuente; París, puestos de libros,
cafés, faroles y jardines. Son escenarios estilizados, no recreaciones geográficas.

La estética usa superficies de contraste bajo, sombras de apoyo y acentos
acotados para recompensas, peligro y feromonas. Los avisos aparecen de a uno
en tarjetas compactas; el estado del llamado queda junto a los controles,
fuera del objeto que se está devorando. La corrosión marca la rotura sin teñir
todo el mueble. Las juntas del piso se filtran al alejar la cámara y la textura
sólo aporta relieve suave, evitando el damero de colores del atlas original.

Obelisco, torre, arcos, plantas, sillas e inodoros tienen perfiles de material
ajustados a su dibujo. Los márgenes transparentes ya no bloquean el camino ni
reciben mordidas; los vanos grandes se pueden atravesar. Esos perfiles se
preparan una vez y se recortan al destruir secciones. Se conservan la resistencia
total, las recompensas y los cuatro pisos de la torre. La orientación de las
hormigas apunta al material cercano y se recalcula sólo al cambiar de contacto
o romperse esa pieza.

Mesadas, heladera, cocina, mesas con sillas, sillón, cama, escritorio y sanitarios
dan identidad a cada ambiente. Paredes y puertas organizan los recorridos.
`mundo/plano_casa.gd` centraliza la geometría que comparten dibujo, navegación
y generación de comida. `mundo/cocina.gd` usa grillas A* compartidas y caché de
rutas para rodear muebles y atravesar puertas; las voladoras ignoran los muebles,
pero no atraviesan paredes. La comida se distribuye por ambientes, fuera de obstáculos.
El gran banquete está en el comedor. El territorio inicial es de 620 unidades;
Excavar permite abrir progresivamente el resto de la casa.

Las feromonas son un **llamado al punto actual del cursor**, no un camino.
Al mantener el clic, las 24 hormigas disponibles más cercanas se aproximan;
la mejora Llamado potente aumenta esa cantidad de a tres y Coordinación de a una
(máximo 64 a la vez). **El clic no hace daño**: sólo da una orden a las hormigas.
Las amenazas y premios sí responden al clic. Se conserva la mejora automática
de `main`, pero no vuelve el daño manual sobre alimentos o muebles.
La compra antigua `pisoton` conserva sus niveles como Coordinación; `pisada`
se convierte en Mandíbulas cooperativas (+0,5 de daño por nivel a las hormigas).
Si movés el cursor,
se actualizan el destino y la selección. Al soltar, termina la atracción sin
dejar rastros anteriores. Sobre comida, las hormigas que llegan recolectan.
Las que ya transportan una carga terminan su regreso antes de responder.
No se puede dar órdenes fuera del territorio descubierto. Al abrir un hueco
bajo el cursor, el llamado conserva el mueble hasta terminar de devorarlo.
El contador del llamado diferencia atraídas, trabajando, cargando y buscando ruta.

La cámara empieza encuadrando el territorio. Cuando usás la rueda o movés el
mapa, conserva tu encuadre; `R` recupera la vista automática del hormiguero
y `H` encuadra la casa entera.
Los controles de cámara no dibujan feromonas. El piso usa juntas filtradas para
mantener un patrón estable al cambiar el zoom.

El terreno continúa alrededor del plano anterior: patio/veredas y jardines
jugables, con ocho objetos adicionales por destino y salidas reales desde los
edificios. El área navegable pasa de 7900×5600 a **10300×7400**; el paisaje
lejano sólo completa el encuadre y no simula hormigas ni usa navegación.
Se redistribuyen como máximo seis alimentos existentes, sin retirar los del
arranque ni crear más recompensa alimentaria. Los muebles exteriores sí son
recursos nuevos. Zoom, arrastre, redimensionado y temblor respetan el área visible
completa: no se puede alejar o desplazar la cámara indefinidamente hacia el vacío.

### Los primeros minutos

Las mecánicas aparecen de a una para no abrumar (`Juego.REVELABLES`). Una vez
reveladas quedan visibles para siempre, y lo nuevo se marca con "¡Nuevo!":

| Mecánica | Aparece |
|---|---|
| Compra ×10 / Máx y frenesí | Desde la segunda run |
| Botón y texto del gran objetivo | Desde la tercera run |
| Pestaña Castas | Desde la cuarta run (o al tener una especialista) |
| Barra de prioridades | Al desbloquear la dieta de madera |
| Pestaña Viajes | Al conquistar el primer destino |
| Pestaña Jalea real (árbol de la reina e hitos) | Con el primer hito o la primera corona |

El HUD muestra siempre la **próxima meta** con una barra (`Juego.proxima_meta()`):
primero desarmar un banquito de cartón accesible sin mejoras; luego subir
Mandíbulas fuertes a nivel 4, juntar las migas de cada
dieta, después el gran objetivo y por último el próximo viaje. Las migas de la
run en curso ya cuentan, y avisa cuando alcanza para comprar.

La colonia arranca con 8 obreras y, con la cámara alejada, las hormigas se
dibujan más grandes (`Colonia.ESCALA_EN_PANTALLA`) para que se lea qué hacen.

### De comer migas a devorar la casa

El taller (rama **Mandíbulas**) tiene tres desbloqueos, en orden. Persisten entre
expediciones de la misma colonia; al fundar sólo se conservan con las Memorias
correspondientes:

| Dieta | Qué incorpora | Requisito / costo |
|---|---|---|
| Comida del piso | Los alimentos habituales | Desde el inicio |
| Madera y telas | Sillas, mesas, muebles, sillones, cama y macetas | Mandíbulas fuertes 4; 1.500 migas |
| Materiales resistentes | Electrodomésticos, mesadas y sanitarios | Madera y telas; 450.000 migas |
| Paredes | Muros divididos en tramos de hasta 420 unidades | Materiales resistentes; 12.000.000 migas |

El ritmo inicial es más gradual por los costos de obreras, daño, carga y
multiplicadores, no por empeorar movimiento u olfato. Con el mismo mapa nuevo,
la comparación económica final del bot pasó de 15,83 a 23,87 minutos hasta fundar
(+50,8%); madera, de 6,35 a 8,36. Son minutos activos simulados, sin pensar en
la tienda ni una garantía de duración humana. Memoria y Cuadrilla siguen
costando 3 y 6 jaleas y permiten volver sin repetir el ahorro de madera.
Los niveles y saldos de partidas anteriores no se recobran ni se reinician.

Mantené el clic sobre la pieza: las hormigas se acercan a su **borde accesible**,
la muerden, transportan las migas y vuelven. Los materiales bloqueados no
reciben daño. Sólo las hormigas y su corrosión extraen material de muebles y
muros. Al señalar una pieza, el HUD muestra su fase, las trabajadoras,
su resistencia y la dieta requerida. El daño recorta la silueta junto a la mordida:
cada objeto tiene como máximo 16 celdas lógicas y una máscara de dibujo. Las
celdas agotadas dejan huecos transitables. Al perder soportes, los restos caen
por etapas, sin cientos de cuerpos físicos.

Cada extracción normal entrega 65% del valor a la hormiga y deja 35% en fragmentos;
el material que cae en un derrumbe queda como fragmentos para recoger. Los
montones se agrupan por zona y material, hasta 64 activos, conservando su valor
al fusionarse. No reciben otra vez el multiplicador ni el bonus de destrucción.
Las cargadoras los priorizan y las voladoras no levantan montones pesados.
Con Corte aserrado, la carpintera deja el 100% en montones y sigue cortando:
el transporte queda a cargo de la colonia, sin multiplicar la recompensa.
Alacenas, heladeras, bibliotecas y vitrinas revelan comida al abrirse; hay un
máximo de 24 alimentos ocultos por expedición.

La resistencia escala con el tamaño del objeto. Las mejoras de daño, velocidad,
carga y recolección siguen teniendo efecto sobre estos objetivos. Cada nueva
expedición reconstruye la casa, igual que repone los alimentos; **los desbloqueos
y mejoras sí se guardan**. No se borra el progreso de partidas anteriores.

### Un comportamiento propio por destino

La rama Territorio permite comprar **cinco entradas secundarias**, desde 800
migas y después de madera. Se abren automáticamente al descubrir sus puntos
fijos: primero un acceso por ambiente y luego puntos separados en plazas o
salones grandes. Conquistar la casa agrega un sexto acceso permanente. No se
simulan túneles: las hormigas eligen el punto de entrega más cercano en línea
recta, comprueban su ruta con la cola normal y prueban otro si está aislado.
La selección sólo sucede al iniciar el regreso o fallar una ruta.

Al terminar hay **hasta 6 segundos de retirada**: sólo las hormigas cargadas
regresan; no hay nuevas mordidas, veneno, nacimientos ni cadenas de derrumbes.
El cierre se adelanta si ya entregaron todas. Lo que no llega a tiempo se
informa como carga pendiente y no se cobra. Eiffel extiende el plazo a 10 s.
El resumen muestra ingresos por alimentos/muebles/estructuras, migas por
segundo (incluye la retirada) y porcentaje del gran objetivo. Los mejores
intentos por destino persisten al fundar y se guardan en partidas versión 7.

Si se devora **todo lo disponible para la dieta y el territorio actuales**, la
expedición termina anticipadamente y pasa a la misma retirada. El resumen
distingue **Zona despejada** de **Mapa despejado**: la segunda exige que tampoco
queden materiales bloqueados ni recursos fuera del alcance. El tiempo de limpieza
fecha el último recurso relevante; la entrega final aparece por separado.
No se cuentan pausas ni se cobra carga que no llegó. Los fragmentos, derrumbes,
tesoros pendientes y el botín recuperable de amenazas impiden cerrar antes de tiempo.

El **Archivo de expediciones**, accesible desde Estadísticas y el resultado,
conserva las últimas 128 limpiezas y hasta 1024 marcas por categoría. Sólo compara
la misma dieta, alcance y versión del mapa; las mejoras pueden ser distintas.
Se conserva al fundar y permite exportar un JSON independiente de la partida.
Las partidas viejas cargan sin inventar récords. El contenido ampliado se identifica
como versión de mapa 3, para no comparar el nuevo terreno con planos anteriores.

Los depósitos próximos se agrupan en ventanas de 0,35 s; el total económico
no se limita. El piso tiene menos contraste, parte de la comida forma grupos
junto a muebles y los escondites llevan una señal dorada. Las mordidas de
madera dejan astillas, la corrosión tiñe el material y el piso activo de Eiffel
está marcado. Las habilidades comparten hasta 16 trazos de 0,35 s, con un
intervalo global de 0,08 s, sin nodos ni físicas por efecto.

| Destino | Regla |
|---|---|
| Casa | Banquito de cartón desde el inicio; los huecos abren atajos |
| Restaurante | Un tesoro activa 8 s de carga de frenesí al doble |
| Museo | Las vitrinas exponen cinco alimentos al perder un 20% de resistencia |
| Obelisco | Cada fase del monumento suma un 15% de daño recibido |
| Coliseo | Un arco devorado sacude hasta dos vecinos; la cadena se procesa por turnos, máximo 24 |
| Torre Eiffel | Las mordidas y los puntos de acceso avanzan desde la base hacia los pisos superiores |

No se simulan destinos inactivos. Las reglas usan las mismas piezas, fragmentos
y límites del resto del juego; no agregan física ni enjambres extra.

Cada conquista conserva una adaptación en **todos** los destinos, incluso al
fundar. Sus valores están en `datos/adaptaciones.csv`: casa da un acceso,
restaurante lleva festines de 11 s a otros mapas, museo agrega un alimento por
escondite (mismo máximo de 24), Obelisco sube la corrosión a 30%, Coliseo lleva
golpes de soporte de 10% a muebles vecinos (hasta 24 eslabones) y Eiffel agrega
4 s de retirada. Viajes explica las reglas y premios; Jalea real muestra
compras concretas que alcanzaría a pagar el saldo después de fundar.

### Viajes, grandes objetivos y jalea real

La tienda tiene pestañas **Mejoras**, **Castas**, **Viajes** y **Jalea real**.
Los destinos son casa, restaurante, museo, Obelisco, Coliseo y Torre Eiffel.
Cada uno tiene su propio plano y un gran objetivo: mesa familiar, barra del
chef, escultura, Obelisco, arco imperial y torre. Devorar ese objetivo abre el
destino siguiente y entrega de 1 a 6 coronas. `G` permite localizarlo; la niebla
y los requisitos de material siguen vigentes.

**Fundar colonia** (pestaña Jalea real, con confirmación) reinicia migas,
mejoras y castas y los convierte en **jalea real**: 3 por corona de la colonia
más la raíz cuarta de (migas juntadas en la colonia / 100.000). La jalea se gasta en el
**árbol de la reina** (`datos/jalea.csv`), que es permanente: atajos (nacer con
las dietas aprendidas, conservar migas o castas), poder (daño, migas, obreras,
tiempo) y reglas nuevas (hallazgos compartidos, más niveles de tope, corona doble).
Toda la jalea ganada en la historia da además +3% de daño y migas por punto,
aunque se gaste. Se conservan los destinos visitados, sus adaptaciones y topes,
los hitos, el árbol y el archivo de tiempos. **La colonia nueva vuelve a la casa**
y debe reconquistar cada gran objetivo para abrir el viaje siguiente; haber
visitado un destino no permite saltarse ese recorrido. Cada gran objetivo paga
sus coronas una vez por colonia.

Al fundar se elige un **decreto de la reina** para la colonia nueva
(`datos/decretos.csv`): numerosa, guerrera, recolectora o exploradora, cada uno
con una ventaja y un costo. La **Pisada automática** (taller, desde Mandíbulas cooperativas 2)
pisa sola la comida más cercana al cursor.

### Recorrido pulido hasta la primera fundación

La tienda y el resultado muestran el mismo siguiente paso, con un botón que
acerca la mejora o la sección correspondiente **sin comprar ni viajar**. Las
fichas explican qué cambia en el trabajo y la compra muestra el antes → después.
El resultado mantiene rendimiento, récord y próxima decisión visibles; los
detalles largos tienen scroll, sin esconder los botones.

Tras conquistar la casa por primera vez se ofrece fundar o seguir al restaurante.
No es obligatorio reiniciar. La confirmación permite conservar toda la jalea,
preparar **Memoria de la madera** (3 jaleas) o una **Cuadrilla para la casa**
(6: memoria, cuatro obreras más y un nivel de daño permanente). Se descuentan
sólo las mejoras que falten. El costo completo, saldo y arranque exacto se ven
antes de confirmar; un plan que no alcanza se rechaza entero. No se regala
progreso ni se compra automáticamente al abrir la ventana.

Para probar este recorrido con otra persona desde cero, sin sobrescribir tu
partida, abrí `tests/sesion_casa.tscn` y usá **F6**. **F7** abre un informe local
exportable a pedido; no hay telemetría ni envíos de datos. La guía y los límites
de estas pruebas están en [`docs/PRUEBA_CASA.md`](docs/PRUEBA_CASA.md).

Cada destino conquistado **sube el tope** de las mejoras (`tope_por_destino` en
`mejoras.csv`) y trae **mejoras propias** (marcadas con ✦, columna `destino`).
Mandíbulas fuertes y Mandíbulas cooperativas duplican su stat cada 25 niveles. El diseño
completo y sus razones están en [`docs/DISENO_PROGRESION.md`](docs/DISENO_PROGRESION.md).

Los seis hitos son opcionales y tienen premios visibles en la tienda: primera
silla (+20% daño de carpinteras), primer derrumbe (+20% daño de demoledoras),
cuatro sillas en una run (+2 bocados para cargadoras), primer tesoro (olfato +10),
cocina desmantelada (migas +10%) y primer monumento (migas +15% y corona evolucionada).

Los depósitos cargan el **frenesí**: 20 depósitos activan 6 segundos de velocidad
y ritmo de mordida ×1.5, con descanso para no encadenarlo indefinidamente. Las
mandíbulas crecen visualmente con sus mejoras; buche y legado cambian el abdomen
y las marcas del cuerpo. La reina adquiere una corona especial al conquistar
un monumento.

### Rendimiento

- Arte compartido en un atlas: se genera una vez al abrir el juego y se reutiliza.
  Los cuerpos animan a 12 cuadros por segundo y el movimiento sigue siendo fluido.
- Búsquedas espaciales por sectores para alimento y obstáculos, en vez de recorrer
  todos los objetos por cada decisión de cada hormiga.
- Selección de feromonas con un heap acotado, cada 0,2 segundos, sin ordenar
  toda la colonia. Cursor compartido por suelo/vuelo; anillos a 30 Hz.
- Rutas con una cola justa: hasta seis pedidos por cuadro y un presupuesto
  blando de 1,2 ms. Hasta dos turnos priorizan llamados y retornos; las demás
  conservan su lugar. Mientras esperan pueden continuar su ruta segura anterior.
  Mover unos pocos píxeles no obliga a recalcular; fallos se reintentan cada
  0,5–0,8 s y también tienen caché. Los giros se comprimen y el suavizado tiene
  trabajo acotado, sin probar cada celda contra todo el resto del recorrido.
- Rutas recalculadas al cambiar el objetivo. La grilla se
  prepara conforme crece el territorio; los recortes actualizan sólo su zona,
  con un presupuesto de 384 celdas por cuadro. Las rutas anteriores siguen
  siendo válidas al quitar material, sin forzar a todas las hormigas a recalcular.
- Niebla en una superficie, textos con un tamaño de fuente fijo y efectos limitados.
  Lo que está fuera de pantalla no vuelve a dibujar la animación de sus hormigas.
- El juego normal está limitado a 60 FPS. Un solo atlas compartido de unos
  34 MiB RGBA8 sirve para los seis destinos y tres etapas visuales; sólo el
  escenario activo tiene nodos. Máximos: 64 montones, 600 partículas, 24 ondas
  y 40 textos almacenados (como máximo 10 visibles, 6 al alejar). No se generan
  efectos visuales lejos de cámara. Las cuatro hojas de arte preiluminado son
  recursos fijos compartidos, no una textura ni un emisor por instancia.

El benchmark gráfico usa el renderizador real, la casa completa y grupos de 5,
150 y 500 hormigas; añade una fase de demolición con 500. No guarda la partida;
desactiva VSync y el límite de 60 FPS sólo durante la medición:

```bash
godot --path . --fixed-fps 60 res://tests/perfil_rendimiento.tscn
godot --path . --fixed-fps 60 res://tests/perfil_feromonas.tscn
```

Informa tiempo real por cuadro, percentil 95, peor cuadro y llamadas de dibujo.
Comparar en la misma PC, sin ejecutar dos pruebas gráficas a la vez. No usar
`--headless` para medir el renderizado: sólo sirve para pruebas lógicas.
El segundo benchmark reparte 500 hormigas por toda la casa y mueve el cursor
continuamente entre habitaciones y sobre muebles, con 24 y hasta 64 llamadas.
Ver resultados y límites de la medición en `tests/RENDIMIENTO.md`.

Los efectos actuales se sintetizan en `global/audio_suave.gd`, con ataques y
finales suaves, notas armónicas y límites de superposición. Los WAV originales
se conservan como referencia. No se necesitan recursos externos adicionales.

### Castas y reclutamiento

La pestaña **Castas** permite conocer y comprar siete tipos de
hormiga. Cada unidad comprada sale en todas las expediciones de esa colonia;
al fundar se reinician salvo la porción conservada por Linaje. Se puede reclutar
de a una, diez o el máximo posible.
Los precios crecen por unidad y cada casta tiene un
límite. Las fichas muestran las estadísticas con las mejoras actuales incluidas.

- **Exploradora veloz:** velocidad ×2.2; mordida más débil.
- **Roja:** aplica veneno corrosivo durante 3 s. El daño por segundo equivale al
  80% de su mordida y esas migas se suman automáticamente. Renovar el veneno
  conserva la potencia más fuerte; no acumula daño sin límite. Hace ×2.2 contra
  resistentes y deja corrosión que mejora 20% los ataques del grupo sobre esa pieza.
- **Voladora:** cruza sobre muebles y tiene más velocidad y olfato. Respeta el
  territorio descubierto y usa las puertas para cambiar de habitación. Sólo
  levanta fragmentos de peso 1.
- **Cargadora:** transporta cuatro veces más bocados y muerde más fuerte, pero
  camina más lento. Prioriza fragmentos y levanta hasta peso 4.
- **Reina:** despliega dos miniobreras cada 6 s, hasta 24 por reina y expedición.
  Las minis recolectan, pero no se guardan como unidades permanentes.
- **Carpintera:** ×3 contra madera/telas, ×0.5 contra alimentos; requiere la dieta
  de madera. Funciona bien con cargadoras que retiren los restos.
- **Demoledora:** ×3 contra muros, ×1.5 contra resistentes, ×0.35 contra alimentos;
  requiere paredes. Es lenta y aprovecha la corrosión de las rojas.

En automático, los roles influyen en la búsqueda. Las prioridades de la barra
inferior cambian la preferencia del grupo sin prohibir otros trabajos; mantener
el clic en un objetivo permite dar una orden directa por encima de esa prioridad.

Las hormigas reservan puestos mientras van a trabajar: una miga admite pocas,
un mueble tiene varios frentes. Las exploradoras comparten hasta 24 hallazgos;
una hormiga sin tarea los consulta como máximo cada 0,6 s y a menos de 650 px.
Las reservas se liberan al volver, cambiar de objetivo o terminar la expedición.
No hay búsquedas de todas las hormigas contra todas las demás.

Sin trabajo, reservan destinos de exploración en sectores de 320 px y prefieren
zonas menos visitadas u ocupadas. Los recorridos de hasta unos 1.000 px duran
lo necesario para llegar; no se reinician por esperar turno de navegación.
Así una colonia numerosa se abre por el territorio en lugar de dar pasos
cortos alrededor del nido. El alimento local y el llamado manual mantienen
prioridad sobre la exploración. Si no existe una salida válida, reintenta con
pausa sin conservar el objetivo anterior.

### Evoluciones y equipo

En la ficha de casta se desbloquean cuatro evoluciones persistentes. Se eligen
**hasta dos por expedición**, sin pagar ni perder compras. Al desbloquearlas
se equipan automáticamente si hay lugar. Las hormigas copian ese equipo al nacer.

| Evolución | Requisitos | Cambia el trabajo |
|---|---|---|
| Corte aserrado | 1 carpintera, Mandíbulas 4 | Divide el daño 75/25 entre dos secciones de madera; deja la extracción en montones y sigue cortando sin volver al nido |
| Nube corrosiva | 3 rojas, Mandíbulas 4 | Contagia hasta dos objetivos próximos cada 1,5 s |
| Barrido de restos | 3 cargadoras, Mandíbulas 4 | Recoge hasta dos montones adicionales a menos de 48 px |
| Camada real | 1 reina, Mandíbulas 8 | Tres minis por tanda; mantiene los topes de 24 por reina y 500 en la colonia |

Se conservan al fundar una colonia y al cargar partidas anteriores. La variante
activa usa al menos la primera evolución visual del atlas existente; no carga
texturas adicionales por hormiga.

`datos/castas.csv` define nombres, información, multiplicadores, colores,
precios y límites. Las mejoras generales afectan a todas las castas. Las
partidas anteriores conservan su progreso y comienzan sin especialistas.

## Balance: los CSV de `/datos`

### Arte compartido y ambientes

El mobiliario distingue acabado, color y orientación: sillas tapizadas, vajilla,
utensilios, cajones, textiles y plantas. Los accesorios desaparecen junto al
mueble que los sostiene. Los bancos de plaza conservan las colisiones y valores
de los muebles que reemplazan; césped y arena tienen pisos propios.
La comida respeta los ambientes previstos incluso cuando se agrupa junto a
muebles. El detalle se dibuja una sola vez en un atlas compartido; no agrega
física ni luces dinámicas. Ver `tests/RENDIMIENTO.md` para mediciones y capturas.

La casa usa ahora dibujo cenital por código: madera mate, cerámica marfil,
tapizados apagados, contornos suaves y sombras cortas hacia abajo/derecha.
Comida, repostería y textiles comparten esa paleta; los accesorios se eligen
por ambiente en lugar de repetir platos y floreros en todas las mesas. Todo
se hornea una vez en el atlas. Se conservan los perfiles transitables y las
secciones de destrucción. El Obelisco, los arcos y Eiffel conservan sus imágenes
preiluminadas; los materiales del suelo mantienen un muestreo con mipmaps.
Las fuentes originales, incluso las sustituidas, están documentadas en
`arte/realista/PROCEDENCIA.md`.

Los premios se agrupan por distancia en pantalla y no se dibujan unos encima
de otros; al alejar se omiten los nombres repetidos de alimentos. La señal de
eventos fuera de cámara identifica la amenaza o miga dorada, explica su efecto
y ofrece **Ver**: un clic encuadra el evento sin resolverlo ni dar órdenes a la
colonia. Sólo esas tarjetas capturan el mouse; el resto deja pasar el zoom y
las feromonas. Se actualizan a 10 Hz y reservan la barra inferior.

`tests/revision_estetica.tscn` recorre los seis mapas y los ambientes de la casa.
`tests/revision_realismo.tscn` comprueba con render real los indicadores a
1280×720 y 1000×620, los límites de etiquetas y el recorte de una mesa ilustrada.
`tests/revision_estilo_casa.tscn` captura la casa y cinco ambientes en Full HD.
`tests/revision_claridad.tscn` verifica el clic real de los indicadores, la
separación del tutorial y el modal de fundación al redimensionar.

### Criterios para seguir creciendo

La promesa es visible: de migas a muebles y de muebles a monumentos. Una compra
debe cambiar lo que hace y muestra la colonia, no sólo un número. Se priorizan
autonomía de las hormigas, respuesta a las órdenes, primera media hora y
coherencia artística antes de sumar monedas o destinos.

- La primera silla de madera cercana al nido usa el perfil `silla_inicial`
  (140 de resistencia / 420 de valor, en `stats_base.csv`). Requiere madera,
  pierde secciones y se transporta normalmente. No se facilita el resto de la
  campaña. El HUD permite encontrarla al comprar la dieta; el cartón del
  tutorial ya no cuenta como una silla de madera para los hitos.
- Las fichas de castas explican equipos y limitaciones reales; no agregan un
  multiplicador por juntar dos clases. Las evoluciones siguen siendo dos y
  se pueden cambiar entre expediciones.
- La confirmación de fundar muestra obreras, especialistas, dieta, duración,
  mordida, multiplicador y reservas del arranque real, recalculados al elegir
  decreto y preparación. Sin preparación usa sólo mejoras ya compradas;
  con ella incluye las compras explícitas y su costo. La vista previa nunca
  gasta ni modifica el guardado: se cobra únicamente al confirmar. Pruebas:
  `tests/prueba_claridad.tscn` y `tests/prueba_preparacion_fundar.tscn`.

Antes de extender la campaña: observar 5–10 personas nuevas sin guiarlas.
Registrar cuándo entienden el llamado, cuándo desmontan madera, qué compra
les cambia la experiencia, si comprenden el reinicio y dónde dejarían de jugar.
Además probar sesiones largas, capturas/cambio de ventana y hardware integrado.
Los bots y suites comprueban reglas; no validan diversión ni duración humana.

El balance se edita en CSV que pueden abrir en Google Sheets o Excel.
Los intervalos de las habilidades especiales están junto a su implementación.

| Archivo | Qué define |
|---|---|
| `stats_base.csv` | Valor inicial de cada stat (hormigas, velocidad, daño, duración de la run, radio del territorio…) |
| `mejoras.csv` | Cada mejora: rama (columna del árbol), stat que afecta, si **suma** o **multiplica**, costo base, crecimiento del costo, nivel máximo y requisito (`otra_mejora:nivel`) |
| `comidas.csv` | Cada comida: forma, color, vida, recompensa, tamaño, distancia del hormiguero, cantidad y ambientes preferidos (`zonas`) |
| `castas.csv` | Castas, descripción de habilidades, multiplicadores, color, tamaño, precio y límite de reclutamiento |
| `jalea.csv` | Mejoras permanentes del árbol de la reina, costos y requisitos |
| `adaptaciones.csv` | Beneficios permanentes por conquistar cada destino |

**Flujo recomendado:** suban los CSV a una planilla compartida, balanceen ahí y cuando les guste hagan *Archivo → Descargar → CSV* de cada hoja y reemplacen el archivo. La coma decimal (`1,5`) también se acepta. Una fila que empieza con `#` se ignora.

- Costo de una mejora = `costo_base × crecimiento ^ nivel`.
- Una mejora tipo `multiplica` con valor `1.12` y nivel 3 multiplica la stat por `1.12³`.
- Para agregar una mejora nueva se agrega una fila y su cámara en `ui/plano_hormiguero.gd` (posición y túneles, que salen de sus requisitos); `tests/prueba_nido` avisa si falta. Si afecta una stat nueva, agregala también a `stats_base.csv` y usala en el código con `Juego.stat("nombre")`.
- `rama` dice dónde va la cámara y cómo se ve. Una cámara compartida lleva las dos ramas (`Mandíbulas|Recolección`) y pide una mejora de cada una en `requiere`.

### Medir el ritmo con el bot

`tests/bot_balance.tscn` juega solo, como un jugador activo (actualiza el llamado
dos veces por segundo, atiende eventos sin daño manual a la comida, compra lo más barato y ahorra para
cada dieta), y anota el minuto de juego de cada desbloqueo y de cada destino:

```bash
godot --headless --fixed-fps 60 --path . res://tests/bot_balance.tscn
```

Usa pasos de 1/60 s, `Engine.time_scale = 1` y FPS ilimitados: acelera por
cantidad de cuadros procesados, no agrandando el delta. Con
`BOT_ESTADO=archivo.json` se puede cortar y retomar por tandas; con `BOT_LOG`
también escribe el registro en un archivo. No corre en CI.

**Referencia previa a la integración de menú, eventos y decretos:**

Las mediciones anteriores a esta revisión usaban tiempo ×8 y daño por clic.
No son comparables: cambiaban los presupuestos de navegación y mordida por
segundo simulado. Piloto final de esta revisión (28/10, desde cero, con
dispersión por sectores, entradas, retirada y Corte aserrado continuo, sin
guardado real ni compras prefijadas). Los minutos incluyen la retirada:

| Hito | Momento | Fundaciones |
|---|---|---|
| Mandíbulas fuertes 4 y primera casta | 4,3 min | 0 |
| Madera y telas (900 migas) | 7,3 min | 0 |
| Materiales resistentes (150.000) | 26,1 min | 0 |
| Paredes (4.000.000) y casa conquistada | 33,1 min | 0 |
| Restaurante conquistado | 38,2 min | 0 |
| Primera fundación (+23 jalea) | 38,2 min | 1 |
| Museo conquistado | 58,1 min | 1 |
| Segunda fundación (+48 jalea) | 60,8 min | 2 |

El límite de 65 minutos termina la última expedición en 66,6. Es un piloto,
no una duración certificada de la campaña ni una estrategia óptima: el bot
compra barato y no optimiza su equipo. Falta calibrar los destinos tardíos y
probar con jugadores. La comparación controlada de castas y sus límites está
en `docs/DISENO_PROGRESION.md`.

Los valores tardíos de `main` se conservan; este piloto no mide la versión integrada.

El gran objetivo pide la dieta completa (`PiezaCasa.NIVEL_META`) y su
resistencia se multiplica por `Mundos.vida_meta(destino)` (`vida_meta` en
`mundo/mundos.gd`). Como la casa se reconstruye en cada expedición, es un
chequeo de daño dentro de una sola run. Desde el restaurante, cada destino
está diseñado para pedir nuevas fundaciones; la cantidad debe volver a medirse.

**Calibrar todo de una:** con `BOT_CALIBRAR=1` los destinos después de la casa
arrancan invulnerables; cuando una colonia se traba y decide fundar, el bot fija
la resistencia de ese destino en `FACTOR_CALIBRACION` (1,3)
× el mayor daño que le hizo y la colonia
siguiente lo conquista. Al final imprime `CALIBRADO {...}` con los valores para
`mundo/mundos.gd`.

Para recalibrar un solo destino: copiá el `estado_<destino>.json` que el bot guarda
al conquistar el anterior, poné un `vida_meta.json` junto al estado (por
ejemplo `{"coliseo": 1e30}`) para hacerlo invulnerable, mirá en el registro
el daño por run (`meta X/Y`) y elegí una resistencia entre la meseta de una
colonia y la siguiente.

## Destinos con identidad

Cada destino tiene **sus comidas** (columna `destinos` de `datos/comidas.csv`;
vacía = en todos) y **su amenaza**, que se resuelve a clics y da botín:

| Destino | Comidas propias | Amenaza | Cómo se juega |
|---|---|---|---|
| Casa | las de siempre | Araña | Caza hormigas sueltas; 6 pisotones la vencen |
| Restaurante | ravioles, flan, pizza entera | El mozo | Avisa con su sombra y pisa; 3 clics en la sombra lo hacen tropezar y suelta la bandeja |
| Museo | canapé, bombón, torta de gala | Aspiradora robot | Se traga comida chica y hormigas; romperla (6) devuelve lo tragado |
| Obelisco | alfajor, medialuna, choripán | Palomas | Picotean lo mejor; un clic espanta a cada una |
| Coliseo | aceituna, uvas, pan romano | Gato | Duerme sobre la mejor comida y salta si lo molestan; 4 clics y se va |
| Torre Eiffel | macaron, croissant, baguette | Rata | Corre a robarse lo más rico; 5 clics la atrapan |

Devorar un gran objetivo es el clímax de cada destino (`mundo/conquista.gd`):
cámara lenta, la cámara encuadra el derrumbe, estallidos por todo el mueble,
lluvia de migas y un cartel con las coronas y el destino que se abre. Sin
pantalla (pruebas y bot) no hay cámara lenta.

Además, la **miga dorada** aparece cada tanto: pisala antes de que se apague y
da migas, frenesí o +8 s. Las amenazas llegan desde la sexta expedición y las
migas doradas desde la tercera; una flecha en el borde de la pantalla señala
las que quedan fuera de la vista. Los pisotones automáticos no las resuelven:
son el momento de clickear. Código en `mundo/eventos.gd` y `mundo/evento.gd`;
revisión visual en `tests/revision_eventos.tscn` y `tests/revision_comidas.tscn`.

## Idiomas

Español e inglés. El juego arranca en el idioma del sistema (español si el
sistema está en español; si no, inglés). Los textos se escriben en español con
`tr("…")` y el inglés vive en `idiomas/en.po`; `tests/prueba_idiomas.tscn`
avisa qué falta traducir y revisa que la interfaz en inglés no tenga restos en
español. Detalle en [`idiomas/LEEME.md`](idiomas/LEEME.md).

## Trabajar de a dos con Git

**Reglas:**

1. **Una rama por tarea** (`git checkout -b hormigas-soldado`), y se integra a `main` con un Pull Request que el otro mira.
2. **Nunca editar la misma escena (`.tscn`) a la vez.** Los scripts se combinan bien; las escenas no.
3. **Sí se suben** los `.import` y `.uid` que crea Godot. **No se sube** la carpeta `.godot/` (ya está en `.gitignore`).
4. Antes de abrir un PR, `git pull origin main` y probar que el juego arranca.
5. Si tocan `run.gd` (es el punto donde se cruzan los dos), avísense.

Las tareas y quién hace qué están en [`TAREAS.md`](TAREAS.md).

### Subir el proyecto a GitHub (una sola vez)

1. En GitHub: **New repository** → nombre `hormigas` → **sin** README, sin .gitignore (ya están acá).
2. En la carpeta del proyecto:
   ```bash
   git remote add origin https://github.com/TU_USUARIO/hormigas.git
   git branch -M main
   git push -u origin main
   ```
3. En el repo: **Settings → Collaborators → Add people** y sumá a tu compañero.
4. Tu compañero: `git clone https://github.com/TU_USUARIO/hormigas.git` y abre el proyecto en Godot.
5. Opcional: en la pestaña **Projects** creen un tablero y copien las tareas de `TAREAS.md`.

## Pruebas

Para correr todas las pruebas lógicas de una vez (en Windows, desde Git Bash):

```bash
GODOT=/ruta/a/godot tests/correr_todas.sh
```

GitHub Actions corre lo mismo en cada PR y en cada push a `main` (`.github/workflows/pruebas.yml`);
si el check queda en rojo, no se mergea. Las instrucciones para agentes de IA
(Claude Code y similares) están en `CLAUDE.md`.

### Prueba de humo

Verifica que el juego arranca, que una run se juega entera sin errores, que las mejoras funcionan y que la tienda se arma. No toca tu partida guardada.

```bash
godot --headless --path . res://tests/prueba_humo.tscn
```

Termina con código 0 si todo anduvo. Córranla antes de cada PR.

Regresiones de movimiento (incluye 500 regresos alrededor de un mueble,
llegada rápida, comida en el borde y final de feromonas):

```bash
godot --headless --path . res://tests/prueba_movimiento.tscn
```

Para revisar la presentación con el renderizador real, sin modificar la partida:

```bash
godot --path . res://tests/revision_visual.tscn
```

Genera capturas de las seis cámaras, compras y cocina en `.godot/qa/` y cierra.
La simulación de 500 hormigas es una prueba lógica; no mide FPS de renderizado.

Compras, carga de partidas antiguas, despliegue y habilidades de las castas:

```bash
godot --headless --path . res://tests/prueba_castas.tscn
```

Atracción de las más cercanas, llegada y liberación, recolección y eventos reales de mouse/cámara:

```bash
godot --headless --fixed-fps 60 --path . res://tests/prueba_controles.tscn
```

Regresión de feromonas bajo carga: selección exacta entre 500, clics reales sin
daño, objetivo liberado entre muestreos, destino encerrado y reapertura de paso,
presupuesto real de rutas, turnos justos y llegada de las 64 seleccionadas:

```bash
godot --headless --path . res://tests/prueba_feromonas.tscn
```

Sin `--headless`, también guarda `.godot/qa/feromonas_500.png`. Las pruebas
lógicas antiguas que avanzan cientos de pasos en un único cuadro desactivan
la cuota de rutas; esta regresión mantiene la cuota de producción activada.

Compras por lote, precios acumulados, límites, indicadores de ramas y rutas por los siete ambientes:

```bash
godot --headless --fixed-fps 60 --path . res://tests/prueba_casa_lotes.tscn
```

`tests/revision_mapa.tscn` renderiza la casa completa, un recorrido por sus
ambientes, el llamado y la tienda en distintos tamaños; guarda las capturas
en `.godot/qa/` sin modificar la partida.

Materiales bloqueados, desbloqueos, guardado, destrucción desde el borde,
recompensas, búsqueda espacial y apertura de pasos:

```bash
godot --headless --fixed-fps 60 --path . res://tests/prueba_materiales.tscn
```

`tests/revision_materiales.tscn` captura la silla antes, durante y después de
devorarla, un muro abierto y las nuevas mejoras en dos tamaños de ventana.

Campaña completa, recortes, derrumbes, roles, prioridades, frenesí, guardado,
legado y conservación del valor de fragmentos:

```bash
godot --headless --fixed-fps 60 --path . res://tests/prueba_campana.tscn
```

`tests/revision_campana.tscn` captura los seis escenarios, los nuevos menús y la
confirmación de legado, también en 1000×620. Todas las revisiones desactivan el guardado.

Primeros minutos: mecánicas que aparecen de a una, próxima meta, llamado sin daño y
tamaño de las hormigas en pantalla:

```bash
godot --headless --fixed-fps 60 --path . res://tests/prueba_progresion.tscn
```

IA cooperativa, reservas, cuatro evoluciones, migración del equipo, reglas de
los seis destinos y tutorial completado por ocho obreras con el llamado fijo:

```bash
godot --headless --fixed-fps 60 --path . res://tests/prueba_enjambre.tscn
```

`tests/revision_enjambre.tscn` captura el tutorial, el llamado, las roturas,
las evoluciones en 1280×720 y 1000×620 y las fases de los grandes objetivos.

`tests/prueba_dispersion.tscn` reproduce 40 s con 500 hormigas sin feromonas,
verifica el cambio de objetivos agotados, la exploración y las reservas. Con
renderer real guarda capturas a los 10 y 40 s en `.godot/qa/dispersion_*.png`.

`tests/prueba_rebirth_archivo.tscn`, `prueba_limpieza.tscn` y
`prueba_poblacion.tscn` cubren el reinicio de viajes, archivo/JSON, cierre sin
recursos pendientes y circulación por los mapas ampliados. `revision_nido.tscn`,
`revision_archivo.tscn` y `revision_poblacion.tscn` capturan el árbol, los tiempos
y los seis destinos con el renderer real, sin tocar la partida del jugador.

## Exportar

*Proyecto → Exportar → Agregar → Windows Desktop* (la primera vez Godot pide descargar las plantillas de exportación). Si al exportar faltan los CSV, agreguen `datos/*.csv` en *Recursos → Filtros para exportar archivos que no son recursos*.

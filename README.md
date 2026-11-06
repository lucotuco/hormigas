# Hormigas 🐜

Incremental para PC hecho en **Godot 4.7.2**. Empezás con una sola hormiga y guiás a la colonia manteniendo el clic donde querés reunirla para que se coma lo que hay en la casa. Cada run empieza durando 45 segundos; con lo recolectado mejorás el hormiguero, el territorio crece y aparecen recursos más grandes y lejanos.

## Arrancar

1. Instalen **Godot 4.7.2** los dos (la versión estándar, no la .NET). Importante: **la misma versión exacta**, si no el editor reescribe archivos y aparecen conflictos.
2. Cloná el repo y abrí `project.godot` desde Godot (Importar → elegir la carpeta).
3. La primera vez tarda unos segundos en importar los recursos.
4. **F5** para jugar.

## Controles

| Acción | Cómo |
|---|---|
| Dirigir el trabajo de las hormigas más cercanas | Mantener clic izquierdo: recolectan dentro del círculo; sobre un objeto, lo priorizan; soltar termina la orden |
| Acercar o alejar el mapa | Rueda del mouse; el zoom apunta al cursor |
| Moverse por el mapa | Arrastrar con botón derecho o central; también WASD o flechas |
| Volver al hormiguero y al encuadre automático | R |
| Ver el plano de la casa completa | H |
| Enfocar el proyecto pendiente o el gran objetivo del destino | G o botón del objetivo |
| Colocar una entrada secundaria disponible | N o botón Entrada; clic izquierdo en piso libre confirma; Esc, clic derecho o N cancela |
| Activar Ráfaga cuando esté cargada | E o botón Ráfaga |
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
    colonia.gd     Hace nacer hormigas a escala nativa y oculta las que quedan fuera de cámara
  mundo/
    run.tscn       Una run completa
    run.gd         Coordina la run: inicio, fin, combos y comida destruida
    comidas.gd     Genera el mapa (siempre igual, semilla fija) y busca comida cercana
    comida.gd      Una comida: material comestible, desgaste, sacudida y dibujo por forma
    feromonas.gd   Selección cercana y trabajo compartido en el área del llamado sostenido
    entradas.gd    Accesos secundarios manuales y acceso adelantado de proyecto
    poderes_colonia.gd Ráfaga por entregas y colocación de entradas
    plano_casa.gd  Siete ambientes, paredes, puertas, muebles y límites compartidos
    dibujo_casa.gd Ilustración de muebles y detalles de la casa
    cocina.gd     Navegación compartida por grilla, con rutas para caminantes y voladoras
    pieza_casa.gd Muebles y tramos de muro comestibles, con colisión y resistencia
    mordiscos_material.gd MordiscosMaterial: máscara fina irreversible y porción local retirada
    recorte_bocados.gdshader Máscara compartida de recortes sobre el atlas existente
    materiales_casa.gd Etapas, resistencia, recompensas y división de paredes en tramos
    mundos.gd     Seis destinos y sus planos, objetivos y progresión de campaña
    proyectos_campana.gd Catálogo de proyectos físicos por destino, desde datos/proyectos.csv
    recorrido_destino.gd Progreso de proyectos, premios y objetivo sugerido sin proceso por cuadro
    recorrido_casa.gd Próximo encuentro físico: paquete, silla/atajo y alacena
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
    vista_compra.gd Comparación retenida antes/después con capacidades reales
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
92 cámaras: 85 mejoras y las 7 castas que se reclutan. Las ramas se separan y
se vuelven a juntar: las **cámaras compartidas** (borde punteado) piden una
mejora de cada rama, y algunos túneles cruzan de una rama a otra. Cada túnel
que llega a una cámara sale de uno de sus requisitos reales.

- **Pasar el mouse** abre la ficha: nombre, nivel, efecto, el valor antes y
  después, el precio y qué le falta si está cerrada. **Un clic** mejora (o
  recluta, en las castas); clic derecho en una casta abre su ficha completa.
- Las descripciones van al efecto concreto en una frase breve; no repiten
  explicaciones generales, historia de migraciones ni instrucciones en cada cámara.
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

Los muebles y monumentos tienen perfiles de material ajustados a su dibujo.
`datos/siluetas_muebles.json` conserva el cuerpo opaco de cada acabado y
orientación, separado de su sombra proyectada. El cuerpo completo se ajusta
al rectángulo físico: no queda un reborde dibujado fuera de la zona comestible.
La navegación usa hasta 16 bandas con sus vanos; la máscara de mordida conserva
el contorno fino por filas. Los márgenes transparentes no bloquean el camino ni
reciben mordidas; los vanos grandes se pueden atravesar. Esos perfiles se
preparan una vez y se recortan al destruir secciones. Adaptar el perfil a su
dibujo no cambia la resistencia ni la recompensa asignadas por el balance;
se conservan los cuatro pisos de la torre. La orientación de las
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

Las feromonas son una **orden de trabajo dentro del círculo del cursor**, no
un camino ni un punto donde estacionar hormigas. Al mantener el clic, las
8 hormigas disponibles más cercanas responden;
la mejora Llamado potente aumenta esa cantidad de a tres y Coordinación de a una
(63 con las dos al máximo; el tope técnico es 64). **El clic no hace daño**: sólo da una orden a las hormigas.
Las amenazas y premios sí responden al clic. Se conserva la mejora automática
de `main`, pero no vuelve el daño manual sobre alimentos o muebles.
La compra antigua `pisoton` conserva sus niveles como Coordinación; `pisada`
se convierte en Mandíbulas cooperativas (+0,5 de daño por nivel a las hormigas).
Si movés el cursor, se actualizan el área y la selección. Sobre un objeto
comestible, la orden explícita tiene prioridad sobre el trabajo automático;
sobre suelo, reparte las obreras entre recursos del círculo. Conserva las
reservas útiles y reemplaza un objetivo agotado sin exigir soltar el clic.
Respeta cupos, dietas, peso de la casta y exclusiones de navegación: señalar una
miga llena no roba un puesto. **Un mueble o estructura señalado no tiene cupo**:
mantener el clic sobre el gran objetivo junta a todas las llamadas. El área coincide con el círculo visible,
también al cambiar el zoom; se muestrea una vez cada 0,2 s y se comparte entre
las seleccionadas. Al soltar, termina la orden sin dejar rastros anteriores.
Las que ya transportan una carga terminan su regreso antes de responder.
No se puede dar órdenes fuera del territorio descubierto. Abrir un hueco bajo
el cursor no abandona un frente todavía útil dentro del área.
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
| Néctar, niveles y mutaciones | Después de la primera compra |
| Compra ×10 / Máx y frenesí | Desde la segunda run |
| Botón y texto del gran objetivo | Desde la tercera run |
| Pestaña Castas | Desde la cuarta run (o al tener una especialista) |
| Barra de prioridades | Al desbloquear la dieta de madera |
| Pestaña Viajes | Al conquistar el primer destino |
| Pestaña Jalea real (árbol de la reina e hitos) | Con el primer hito o la primera corona |

El HUD muestra la **próxima meta** (`Juego.proxima_meta()`): primero juntar
migas cercanas para más obreras; subir Mandíbulas fuertes a nivel 3, aprender
Mordida rápida y juntar las migas de cada dieta; después el gran objetivo y
por último el próximo viaje. El cartón queda como proyecto opcional, no obliga
a concentrar la primera obrera allí. Las migas de la
run en curso ya cuentan, y avisa cuando alcanza para comprar.

La colonia nueva arranca con **una obrera**; Más obreras suma **una por nivel**.
La primera cuesta 12 migas y la mordida base deja 0,95 s entre ataques, sin
reducir velocidad, olfato ni calidad de navegación. Cada casta conserva su
**tamaño nativo** al nacer y durante todo el zoom: alejar la cámara no agranda
hormigas, enemigos ni sus hitboxes. El culling y el detalle por distancia se
mantienen. Las colonias con jalea/decreto conservan sus bonus de arranque.

### De comer migas a devorar la casa

El taller (rama **Mandíbulas**) tiene tres desbloqueos, en orden. Persisten entre
expediciones de la misma colonia; al fundar sólo se conservan con las Memorias
correspondientes:

| Dieta | Qué incorpora | Requisito / costo |
|---|---|---|
| Comida del piso | Los alimentos habituales | Desde el inicio |
| Madera y telas | Sillas, mesas, muebles, sillones, cama y macetas | Mandíbulas fuertes 3 + Mordida rápida 1; 700 migas |
| Materiales resistentes | Electrodomésticos, mesadas y sanitarios | Madera y telas; 550.000 migas |
| Paredes | Muros divididos en tramos de hasta 420 unidades | Materiales resistentes; 15.000.000 migas |

**Referencia histórica del 29/10, anterior a los bocados actuales:** aquel
balance aumentó aproximadamente 20–25% los demás precios, la resistencia común
de muebles/muros ×1,6 y la vida de los alimentos
medianos/grandes sin aumentar sus recompensas. Las migas iniciales conservan
3 de vida y 2 de valor; el cartón, 20/180. El primer precio de obrera no sube.
La prueba corta pagó la segunda hormiga tras una expedición guiada o dos
autónomas. El piloto materiales → primera fundación terminó en 35,11 minutos
activos y 27 expediciones, sin contar decisiones de tienda. No es una duración
humana garantizada ni valida el ritmo actual o la campaña tardía.

**Comparación histórica del 28/10, con ocho obreras iniciales:** precios
anteriores/nuevos sobre el mismo mapa dieron 15,83→23,87 minutos hasta fundar
(+50,8%) y 6,35→8,36 para madera. No describe el balance individual actual.
Memoria y Cuadrilla siguen costando 3 y 6 jaleas y evitan repetir el ahorro
de madera. Las partidas anteriores conservan niveles y saldos sin recobros;
la población se recalcula con la nueva base y una obrera por nivel. Ver
`docs/DISENO_PROGRESION.md` para cifras, contexto y límites de los pilotos.

Mantené el clic sobre la pieza: las hormigas se acercan a su **borde accesible**,
la muerden, transportan las migas y vuelven. Los materiales bloqueados no
reciben daño. Sólo las hormigas y su corrosión extraen material de muebles y
muros. Al señalar una pieza, el HUD muestra el porcentaje consumido, las
trabajadoras, la dieta requerida y sus componentes conservados, cuando los hay.
**No hay barras de vida sobre comida, muebles ni enemigos**: el desgaste se
lee en el material ausente; tiempo, compras y frenesí conservan sus indicadores
de interfaz. Cada operación recorta junto a la mordida **una porción sólida de
hasta 6×6 unidades del mundo**, no una franja proporcional a todo el daño.
Excepción: contra un **gran objetivo** (del destino o de un proyecto) el bocado
crece con el daño que no entra en 6×6, hasta 24×24 (`PiezaCasa.lado_para_dano`).
Sin eso, mejorar las mandíbulas casi no servía para tirarlo.
Cada ciclo admite hasta **1 porción al inicio, 2 al aprender madera y 3 al
aprender resistentes o paredes**. Es un máximo, no una extracción garantizada:
se corta antes si falta crédito, contacto, material o espacio en el buche.
Las continuaciones gastan trabajo ya emitido, sin volver a sumar daño ni
veneno. Cada porción llena un lugar del buche y copia su propio tamaño/origen
antes de retirar la siguiente. Así el progreso mejora el flujo sin agrandar
el retazo ni borrar un cuarto de mueble con una astilla. Una máscara fina
irreversible conserva cada recorte, incluso al cambiar de lado. La fuerza paga el trabajo de corte;
únicamente el área desprendida descuenta resistencia y produce valor. El
trabajo menor a un píxel se acumula sin fabricar una carga. La caja grande
requiere muchos viajes, no desaparece un cuarto por una sola astilla.
La navegación conserva hasta 16 celdas lógicas; las cavidades pequeñas no
crean cuerpos físicos. Las mordidas normales tampoco borran automáticamente
el último 8% del mueble. Los eventos de derrumbe siguen siendo otra mecánica.

Cada extracción normal entrega el **100% del valor de esa porción** a la hormiga:
el agujero y la carga corresponden al mismo material. El daño ambiental conserva
su reparto 65/35; el material que cae en un derrumbe queda para recoger. Los
montones se agrupan por zona y material, hasta 64 activos, conservando su valor
al fusionarse. No reciben otra vez el multiplicador ni el bonus de destrucción.
Las cargadoras los priorizan y las voladoras no levantan montones pesados.
La carga muestra hasta **tres retazos por hormiga**, muestreados del material
retirado con su orientación; desaparecen al entregar. Los montones agrupados
usan un aspecto común por material: no guardan una pieza visual por cada
fragmento fusionado. Los retazos reutilizan el mismo atlas y conservan su tamaño
del mundo compensando la escala visual de la hormiga y del atlas. Cada recurso
mordido o consultado para un contacto preciso prepara una máscara R8 retenida;
no se crea textura, nodo ni cuerpo físico por bocado. Es diferida, no se reserva
para todo el mapa al cargar; elegir un puesto puede prepararla antes del primer
bocado. Sólo se sube el desgaste sucio
a 12,5 Hz. La silueta de comidas está prehorneada en `datos/siluetas_comidas.json`,
idéntica con renderer y headless. `tests/exportar_siluetas.tscn` permite obtenerla
de nuevo si cambia el arte. `tests/exportar_material_muebles.tscn` genera los
metadatos del mobiliario (incluir los CSV y ambos JSON en una exportación).
Las bocas trabajan desde aire conectado al exterior, no desde el interior del
cuerpo ni de una cavidad cerrada. La sombra se proyecta desde el material que
queda usando la misma máscara: no cuenta como resistencia ni viaja como carga.
Con Corte aserrado, la carpintera deja el 100% en montones y sigue cortando:
el transporte queda a cargo de la colonia, sin multiplicar la recompensa.
Alacenas, heladeras, bibliotecas y vitrinas revelan comida al abrirse; hay un
máximo de 24 alimentos ocultos por expedición.

La resistencia escala con el tamaño del objeto. Las mejoras de daño, velocidad,
carga y recolección siguen teniendo efecto sobre estos objetivos. Cada nueva
expedición reconstruye la casa, igual que repone los alimentos; **los desbloqueos
y mejoras sí se guardan**. No se borra el progreso de partidas anteriores.

### Un comportamiento propio por destino

La rama Territorio permite comprar **cinco cupos de entradas secundarias**,
desde 1.000 migas y con Explorar la casa 6. Conquistar la casa agrega un sexto
cupo permanente. **Se colocan una vez** con `N` o el botón Entrada: la vista
previa indica si el piso elegido está libre, dentro del territorio y separado
de los accesos existentes. Un intento inválido no consume el cupo. Quedan
guardadas por destino (`Juego.entradas_colocadas`) y se reponen solas en cada
expedición; con `N`, un clic sobre una entrada la levanta para moverla. Las
posiciones que no se pueden activar por cupos, territorio u obstáculos se
conservan; mover una no borra las demás ni cambia su orden. En modo N, las
guardadas inactivas aparecen tenues y pueden moverse si hay un cupo disponible.
El acceso adelantado de
proyecto sigue siendo independiente y automático. Máximo: nido, seis manuales
y uno de proyecto. No se simulan túneles: las hormigas eligen el punto de
entrega más cercano en línea recta, comprueban su ruta con la cola normal y
prueban otro si está aislado. La selección sólo sucede al iniciar el regreso
o fallar una ruta; colocar otro acceso no cambia un retorno en curso. Levantar
uno sí reasigna sus retornos a una entrada vigente, sin perder carga ni ejecutar
sus rutas fuera de la cola normal.

Al terminar hay **hasta 6 segundos de retirada**: sólo las hormigas cargadas
regresan. **El silbato corta la extracción inmediatamente**: cancela crédito
sin retirar, corrosión/erosión en cola, preparaciones, amenazas, poderes y
cadenas de derrumbes; no hay una fase oculta para terminar daño pendiente.
No hay nuevas mordidas ni nacimientos. Sólo se entrega carga ya extraída.
El cierre se adelanta si ya entregaron todas. Lo que no llega a tiempo se
informa como carga pendiente y no se cobra. Eiffel extiende el plazo a 10 s.
El resumen muestra ingresos por alimentos/muebles/estructuras, migas por
segundo (incluye la retirada) y porcentaje del gran objetivo. Los mejores
intentos por destino persisten al fundar y se guardan desde partidas versión 7.

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
Las partidas viejas cargan sin inventar récords. El contenido actual se identifica
como versión de mapa 11, para no comparar estas reglas con planos anteriores.

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
chef, escultura, Obelisco, arco imperial y torre. La casa conserva su recorrido
inicial; los otros cinco destinos suman cuatro proyectos cada uno. Para la
primera conquista hay que terminar los proyectos y el gran objetivo: recién
entonces se abre el siguiente viaje y se entregan de 1 a 6 coronas.

Son **20 proyectos sobre 42 objetos físicos**, no encargos de juntar una cifra:
la cocina y el salón del restaurante, las vitrinas y el archivo del museo,
el kiosco y los vehículos porteños, las ánforas y arcadas romanas, los puestos
de libros y jardines de París. Se pueden hacer en cualquier orden. Viajes
muestra objetos pendientes, premio y progreso; `G` lleva al próximo objetivo
accesible sin mantener el llamado anterior. La niebla y las dietas siguen vigentes.

**Un objeto de proyecto completamente devorado queda terminado** entre
expediciones y fundaciones. Trece muebles concretos tienen además 37 componentes
reconocibles: puertas, estantes, expositores y partes de fuentes. Cada componente
completamente devorado se conserva, incluido su hueco en cuerpo, sombra y
navegación. El daño de un componente sin terminar se reinicia: no se reconstruye
una máscara rota desde un porcentaje de vida. El cartón cercano y la primera
alacena de Casa son descubrimientos opcionales, no proyectos obligatorios.
Cada proyecto paga una sola vez un alijo regional real; el de logística habilita
un acceso adelantado propio, sin consumir los seis accesos normales de mejoras.
Tres proyectos abren nuevas evoluciones.
Después de la conquista histórica, los muebles vuelven como recursos normales,
sin resistencia de misión ni premios de proyecto repetidos.

La partida usa versión 10 y el mapa 11. Los récords nuevos distinguen qué
objetos, componentes y escondites estaban pendientes al iniciar. Las partidas anteriores conservan sus
victorias: los proyectos de destinos ya conquistados se consideran cumplidos,
sin premios retroactivos. Para jugar toda la campaña ampliada hace falta una
partida nueva; no se borra ni se reinicia automáticamente la partida existente.

**Fundar colonia** (pestaña Jalea real, con confirmación) reinicia migas,
mejoras y castas y los convierte en **jalea real**: 3 por corona de la colonia
más la raíz cuarta de (migas juntadas en la colonia / 100.000). Pasados 100,
la parte por migas crece con la raíz cuadrada del resto (`TOPE_SUAVE_JALEA_MIGAS`).
La colonia nueva hereda el 1% de las migas (`MIGAS_HEREDADAS`), y Reservas de
la reina suma un 10% más por nivel. La jalea se gasta en el
**árbol de la reina** (`datos/jalea.csv`), que es permanente: atajos (nacer con
las dietas aprendidas, conservar migas o castas), poder (daño, migas, obreras,
tiempo) y reglas nuevas (hallazgos compartidos, más niveles de tope, corona doble).
Toda la jalea ganada en la historia da además +3% de daño y migas por punto,
aunque se gaste. Se conservan los destinos visitados, sus adaptaciones y topes,
los hitos, los proyectos terminados, el árbol y el archivo de tiempos. **La colonia nueva vuelve a la casa**
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

### Néctar, niveles y mutaciones (la run como roguelite)

Cada entrega real llena la **barra de néctar** (bajo el reloj). Al llenarla la
colonia **sube de nivel**: eclosiona de golpe un 15% de la colonia (al menos
una obrera) y, medio segundo después, la run se pausa para elegir **una de tres
mutaciones** con clic o `1` `2` `3`; `R` revuelve la oferta una vez por run.
Las mutaciones valen sólo en esa expedición: al cobrarla, las stats vuelven a
las de la tienda y nada se guarda.

- Rarezas: común, rara, épica y legendaria (gris, azul, violeta y dorado). La
  rareza multiplica el valor de la fila ×1 / ×1,6 / ×2,5 / ×4 respecto de su
  rareza mínima, y con cada nivel de la run salen mejores rarezas.
- Néctar del nivel *n* = máx(6, hormigas × 1,2) × (1 + 0,8 × *n*): atado a la
  colonia, da 4–7 niveles por run con una obrera o con quinientas.
- Las mutaciones están en `datos/mutaciones.csv` (`efecto`, `valor`,
  `rareza_minima`, `max`). Daño, ritmo, paso y críticos se leen por mordida
  desde `EvolucionRun`; migas, botín, buche y cría van por `Juego.mods_run`.
- Llegar al tope de 500 hormigas convierte la eclosión en "colonia
  desbordada": +5% de daño por cada nivel que ya no puede eclosionar.
- La mitad de las **migas doradas** abren un **cofre**: una mutación extra,
  rara o mejor, sin gastar néctar.
- Pasar 25, 50, 100… hormigas vivas en la run se festeja una vez (cartel,
  onda y temblor); sólo cuenta lo que creció en la expedición.
- Aparece después de la primera compra: las primeras expediciones siguen
  siendo la obrera sola. El bot elige con `BOT_CARTAS=mejor|azar`; sin
  pantalla, las pruebas eligen solas (`EvolucionRun.modo_automatico`).

Pruebas: `prueba_mutaciones`; capturas: `revision_mutaciones`.

**Ráfaga es otro poder, manual y separado del frenesí.** Veinte entregas reales
cargan el botón; `E` activa 8 segundos de daño ×1,75 y ritmo de mordida ×1,25,
sin acelerar el movimiento. El descanso de 30 segundos comienza al activarlo,
no al terminar los ocho segundos. No se acumula ni se extiende; bonos,
destrucciones y corrosión no cuentan como entregas. Se consulta el poder al
emitir la mordida, sin reescribir daño o intervalo base; el veneno emitido
captura el factor una sola vez. Valores en `datos/stats_base.csv`.

### Rendimiento

- Arte compartido en un atlas: se genera una vez al abrir el juego y se reutiliza.
  Los cuerpos animan a 12 cuadros por segundo y el movimiento sigue siendo fluido.
- Búsquedas espaciales por sectores para alimento y obstáculos, en vez de recorrer
  todos los objetos por cada decisión de cada hormiga.
  Los recortes del mobiliario tienen un límite envolvente cacheado: se descartan
  antes de recorrer sus bandas si la consulta queda fuera. Se actualiza al
  cambiar el material, sin simplificar huecos ni ampliar colisiones.
- Selección de feromonas con un heap acotado, cada 0,2 segundos, sin ordenar
  toda la colonia. La consulta espacial del área también es compartida;
  reasignar un trabajo no recorre el mapa por hormiga y por cuadro. Cursor
  compartido por suelo/vuelo; anillos a 30 Hz.
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
- El juego normal está limitado a 60 FPS. Un solo atlas compartido de
  48 MiB RGBA8 sirve para los seis destinos y tres etapas visuales; sólo el
  escenario activo tiene nodos. Máximos: 64 montones, 600 partículas, 24 ondas
  y 40 textos almacenados (como máximo 12 visibles, 8 al alejar). No se generan
  efectos visuales lejos de cámara. El arte se hornea una sola vez; las hojas
  antiguas de muebles y monumentos se cargan sólo si se solicita ese recurso,
  no una textura ni un emisor por instancia.

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
continuamente entre habitaciones y sobre muebles, con 24 y 63 seleccionadas
(máximo comprable). Sus dos últimas fases fuerzan explícitamente el tope
técnico de 64 en el fixture: son estrés sintético, no un nivel comprable.
Ver resultados y límites de la medición en `tests/RENDIMIENTO.md`.

Los efectos actuales se sintetizan en `global/audio_suave.gd`, con ataques y
finales suaves, notas armónicas y límites de superposición. Los WAV originales
se conservan como referencia. No se necesitan recursos externos adicionales.

Las mordidas confirmadas generan golpes y astillas locales; las entregas
convergen hacia la entrada, desde la primera obrera. Destrucción, hitos de
racha, Ráfaga y victoria tienen gestos distintos. Un solo lienzo comparte hasta
600 partículas, 24 ondas, 40 textos y 16 trazos, con puertas y descarte por
cámara. Los acentos no cambian el tamaño físico del bocado ni dan recursos.
Contador y combo usan relojes compartidos, sin crear tweens por depósito.
Cada entrega muestra su ganancia real en la entrada y junto al contador,
incluidos los decimales de la primera obrera. Las tandas se agrupan durante
0,28 s en el mapa y 0,32 s en el HUD; sumar no prolonga el mismo número
indefinidamente ni vuelve a cobrar. Los depósitos conservan 24–26 px en pantalla
y los bonus 32 px, con pop, contorno y sombra, sin agrandar las hormigas.
Se dibujan hasta 12 números sin superponer (ocho con zoom inferior a 0,25).
Las migas con estela viajan al contador en el mismo pool de 40; los hitos de
entregas tienen un anuncio grande, no un multiplicador económico nuevo.
Ganancia y combo se formatean una vez por cuadro, no por hormiga; el cierre
vacía la presentación y rechaza callbacks tardíos.
Ráfaga avisa una vez al cargarse; los sonidos de golpe, racha y poder comparten
el pool de 16 voces. `tests/perfil_estimulos.tscn` exige renderer real y Full HD.
`tests/revision_recompensas_juego.tscn` captura mordida, transporte, entrega,
racha y bonus en una Run real a zoom normal y alejado. Usa cargas físicas y
valor nativo de la comida: las cifras no son premios inventados para la foto.

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

En la ficha de casta se desbloquean siete evoluciones persistentes. Se eligen
**hasta dos por expedición**, sin pagar ni perder compras. Al desbloquearlas
se equipan automáticamente si hay lugar. Las hormigas copian ese equipo al nacer.

| Evolución | Requisitos | Cambia el trabajo |
|---|---|---|
| Corte aserrado | 1 carpintera, Mandíbulas 4 | Deja el material realmente cortado en montones y sigue trabajando sin volver al nido; cada microbocado conserva su frente local |
| Nube corrosiva | 3 rojas, Mandíbulas 4 | Contagia hasta dos objetivos próximos cada 1,5 s |
| Barrido de restos | 3 cargadoras, Mandíbulas 4 | Recoge hasta dos montones adicionales a menos de 48 px |
| Camada real | 1 reina, Mandíbulas 8 | Tres minis por tanda; mantiene los topes de 24 por reina y 500 en la colonia |
| Sondeo de escondites | 1 voladora, Mandíbulas 4 y despensa de servicio | Una extracción real abre antes el tesoro de muebles con escondite, sin borrar el mueble ni duplicar el tesoro |
| Trabajo de cantera | 1 demoledora, Mandíbulas 8 y galería de piedra | Corta piedra/metal de forma continua y deja el material extraído para transportarlo |
| Puente aéreo | 3 voladoras, Mandíbulas 8 y parada porteña | Permite retirar montones pesados de material resistente; no montones de muro |

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
  (280 de resistencia / 420 de valor, en `stats_base.csv`). Requiere madera,
  pierde material y se transporta normalmente: aumentar su vida no aumenta
  su premio. El HUD permite encontrarla al comprar la dieta. El cartón del
  tutorial conserva 20 de resistencia / 180 de valor y no cuenta como silla
  de madera para los hitos.
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

En la campaña por proyectos, el bot sigue el objeto sugerido y
anota por separado objetos, proyectos y conquista real. Comer el monumento
antes de los proyectos no equivale a terminar el destino. El piloto nuevo
es parcial: llegó desde cero a casa y los dos primeros proyectos del
restaurante; todavía no permite afirmar la duración de toda la ampliación.

**Referencia histórica del 28/10, previa al arranque individual y al balance actual:**

Las mediciones anteriores a esta revisión usaban tiempo ×8 y daño por clic.
No son comparables: cambiaban los presupuestos de navegación y mordida por
segundo simulado. Piloto de aquella revisión (28/10, desde cero, con
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

Con `BOT_RUNS_DESTINO=N` la resistencia se fija después de N runs en el destino
(por `BOT_FACTOR`), sin esperar a que la colonia se trabe. **Ojo:** desde los
bocados de la versión 5, un objetivo invulnerable no suelta trozos. Las hormigas
llamadas muerden sin volver nunca al nido, y el daño aplicado
(`trabajo_recibido`) sobreestima lo que una colonia extrae de un objetivo real.
Los valores de la versión 5 se ajustaron a mano con pasadas normales del bot,
mirando `meta X/Y` en cada destino.

El bot ataca el gran objetivo sólo cuando estima que lo puede tirar: escala el
daño de su último intento por la potencia actual (daño × hormigas ÷ intervalo de
mordida) y además reintenta cada 4 runs. Como el mapa se repone, atacar un
objetivo que no cae deja la run sin ingresos.

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
da migas, frenesí, +8 s o (con el néctar a la vista) un cofre de mutación.
Las amenazas llegan desde la sexta expedición y las
migas doradas desde la tercera; una flecha en el borde de la pantalla señala
las que quedan fuera de la vista. Los pisotones automáticos no las resuelven:
son el momento de clickear. Código en `mundo/eventos.gd` y `mundo/evento.gd`;
revisión visual en `tests/revision_eventos.tscn` y `tests/revision_comidas.tscn`.

La amenaza del lugar alterna con cucarachas (casa, restaurante y museo) o
escarabajos (Obelisco, Coliseo y Eiffel), e incorpora encuentros situacionales:
una **avispa** anuncia una pasada sobre una carga en tránsito; una **hormiga
rival** disputa montones reales y trata de escapar con ellos. Golpearlas
interrumpe brevemente su acción y muestra los golpes que faltan. No se agrandan
con el zoom ni se habilita daño manual sobre alimentos.

La primera amenaza llega 6–10 segundos después de comenzar una expedición
que ya tenga desbloqueadas amenazas. La espera siguiente va de 6 a 19 segundos,
según destino y progreso; los encuentros simultáneos crecen de dos a cuatro
grupos, con un máximo duro de **cuatro individuos**. Una bandada usa tres lugares.
Nacen cerca del trabajo visible, con piso libre, separación y aviso, en lugar
de viajar desde una frontera territorial lejana; si no hay piso seguro, no
aparecen. La huida dura hasta cuatro segundos, sin retener un cupo por minutos.
Ritmo y enemigos nuevos se configuran en `datos/ritmo_amenazas.csv` y
`datos/amenazas_activas.csv` (incluir ambos al exportar).

Los avisos de entrada/robo permiten reaccionar antes de la acción. Vencer más amenazas también aporta
botín: estas reglas y los nuevos poderes **sí pueden cambiar los ingresos**,
aunque no se suban precios. Los pilotos viejos no validan la duración actual;
falta medir de nuevo la campaña y observar jugadores.

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

IA cooperativa, reservas, evoluciones, migración del equipo y reglas
de los seis destinos; el tutorial se prueba con una colonia de ensayo y el
llamado fijo, no se presupone que el arranque actual tenga ocho obreras:

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

`tests/prueba_arranque_solitario.tscn` comprueba una sola obrera real y la
segunda pagada con ingresos de hasta tres expediciones guiadas o cinco
autónomas en su escenario controlado, no como promesa humana. `prueba_mordiscos.tscn`
verifica recortes acumulativos, límites y conservación del valor;
`revision_mordiscos.tscn` permite revisar material retirado y carga con el
renderer. Los resultados gráficos y sus límites están en `tests/RENDIMIENTO.md`.

Los proyectos nuevos se cubren en `prueba_proyectos_estado.tscn`,
`prueba_proyectos_mundo.tscn` y `prueba_proyectos_ui.tscn` (progreso, premios,
migración y lectura). `prueba_evoluciones_viaje.tscn` comprueba extracción real,
tesoros y logística sin duplicar valor. `prueba_aire_material.tscn` contrasta el
aire/frontera contra un flood independiente. La revisión visual es
`revision_proyectos.tscn`; el estrés gráfico específico, `perfil_proyectos.tscn`.
Todas desactivan el guardado personal. El perfil usa daño artificial declarado:
no sirve para estimar duración de campaña ni rendimiento habitual.

`prueba_componentes_proyecto.tscn` cubre las partes físicas, su guardado,
escondites y migración. `prueba_acceso_proyecto.tscn` comprueba el acceso propio
y el cap independiente;
`prueba_erosion_presupuestada.tscn` verifica turnos, masa, premios y cierre sin
bloqueo ni tiempo gratuito. Para ver cuerpo/sombra y componentes restaurados,
corran `revision_componentes.tscn` con el renderer real.

La preparación de máscaras de desgaste también comparte presupuesto por
expedición: `prueba_preparacion_mordiscos.tscn` compara el material exacto y el
cierre; `perfil_preparacion_mordiscos.tscn` mide primer contacto con gráficos.
No confundir CPU total repartida con el costo de un solo cuadro.

La casa tiene tres envoltorios pequeños que reservan comida nativa, sin sumar
valor al mapa. Se definen en `datos/hallazgos.csv`; al abrirlos se recuerda el
encuentro y próximas expediciones reponen la comida normal. Se cubren con
`prueba_hallazgos_casa.tscn` y `prueba_arte_hallazgos.tscn`. La presentación de
mordida, levantado y entrega usa el mismo atlas y hasta tres retazos;
`prueba_sensacion_bocado.tscn` verifica que no cambie posición física ni valor,
y `revision_sensacion.tscn` guarda la secuencia y muestras de sonido en QA.

`prueba_area_feromonas.tscn` verifica trabajo en el círculo, prioridad explícita,
reservas, agotamiento, retornos y escala nativa. `prueba_microbocados.tscn`
comprueba tandas de 1/2/3, área/HP/valor conservados, retazos de tamaños distintos,
buche y corte de expedición. `prueba_corte_y_poderes.tscn` cubre entradas
manuales, Ráfaga y cierre sin daño posterior; el perfil gráfico no reemplaza
estas comprobaciones de reglas ni permite prometer duración humana.

`revision_residuos_comida.tscn` revisa los 27 alimentos y tres envoltorios con
renderer real: cuerpo/sombra parciales, ausencia de trazos con la máscara vacía,
detalles conectados, máscaras compartidas/privadas e indicadores sin recortar.
Guarda las comparativas en `.godot/qa/residuos_*.png`, sin tocar la partida.

## Recorrido inicial y compras perceptibles

La primera sugerencia es comprar una segunda obrera. Seis migas existentes se
acercan al nido; conservan cantidad, resistencia, valor y semilla. Cuando la
colonia puede hacerlo, el HUD propone abrir un paquete, desarmar la silla que
abre un atajo o descubrir lo que guarda una hoja de alacena. Son sugerencias
opcionales sobre objetos reales. La silla conserva dos partes completas entre
expediciones; al terminarla libera el camino y una galletita nativa reservada.
Hay que transportarla para cobrarla. Las casas conquistadas no repiten esta
escena ni pierden su progreso.

Las fichas de obreras, carga, carpinteras, madera y entradas comparan antes y
después con los valores reales del lote. El llamado avisa si su capacidad ya
alcanza a toda la población inicial. Son dibujos retenidos, sin otra simulación.
La mordida marca apoyo, tirón y levantado; cada porción mantiene su tamaño real.
Las sillas tienen respaldo, uniones y asiento propios de contornos redondeados;
ya no se dibujan desde las bandas simplificadas de navegación. Sus siete
acabados comparten atlas y material exportado. Las cercanas se hornean a tres
texeles por unidad, sin el margen vacío anterior. Muebles, comida y monumentos
conservan cobertura suavizada en sus contornos, sin usar las bandas de colisión
como dibujo. Pisos y paneles usan menos ruido, bordes finos y sombras cortas.
El empaquetado MaxRects y los márgenes compactos dejan el atlas en
2048×6144 / 48 MiB, por debajo de los 49,5 MiB anteriores. Sólo se calcula al
arrancar; la resolución no cambia con el zoom ni se reduce automáticamente:
hacerlo invalidaría las siluetas comestibles. El presupuesto de autoría se
verifica antes del horneado. No se agregan búsquedas ni efectos por hormiga.

Tras editar arte, `exportar_material_muebles.tscn -- --guardar` y
`exportar_siluetas.tscn -- --guardar` regeneran sus metadatos de autoría en
`datos/`; sin `--guardar` sólo los imprimen. Las revisiones GPU contrastan el
material completo de los 59 acabados y los bordes suavizados, no sólo capturas.

`prueba_recorrido_casa`, `prueba_compras_claras`, `prueba_direccion_material`
y `prueba_registro_percepcion` cubren estas reglas. Sus revisiones gráficas
guardan escenas y fichas reales en `.godot/qa/`. Para una sesión desde cero sin
afectar la partida, ejecutar `tests/sesion_casa.tscn` con F6; el protocolo y el
informe local están explicados en `docs/PRUEBA_CASA.md`.

## Combo y mejoras con efectos propios

En 3/10/25/50/100/250 entregas, el combo golpea enorme en el centro de la
pantalla: sacudida, ondas y destellos, y un vuelo de regreso al contador con
el nuevo color. Dura 1,04 s, sin detener la simulación ni bloquear el mouse.
Cuenta depósitos, no multiplica las migas. Las descargas simultáneas se
agrupan por cuadro; subir de etapa durante el efecto actualiza esa misma
animación sin reiniciarla ni encolar otras. Temblor cero conserva el combo
quieto en el HUD. Pausar congela el efecto; finalizar lo cancela.
No lleva placa ni oscurece el mapa: las letras se separan del fondo con
contorno, sombra corta teñida y su color de etapa.

Tres cámaras opcionales nuevas: **Migas brillantes** (migas +8%, destellos al
entregar), **Mordida chispeante** (daño +8%, corte y chispas al comer) y
**Pulso de la colonia** (+1 s de frenesí, halo en las entradas mientras dura).
Cada una se compra una sola vez; se reinician al fundar, sin borrar recuerdos.
No agregan emisores por hormiga ni agrandan el atlas. Tests dedicados:
`prueba_combo_visual`, `prueba_mejoras_visuales`, `prueba_compras_visuales`;
capturas `revision_combo_visual` y `revision_mejoras_visuales`.

## Regreso desde bordes y pasillos finos

Los puestos junto a muebles pueden tener espacio real para caminar aunque
no quepa una celda conservadora de navegación. En ese caso un enlace local
de hasta dos esquinas conecta el puesto con la misma rejilla, tanto a la
ida como al regreso. Cada tramo comprueba las colisiones normales: no hay
teletransporte, cobros a distancia ni reducción del margen de seguridad.
Conserva la cola compartida de rutas; el caché positivo tiene tope de 128.
`prueba_regreso_bordes` cubre mordidas reales, cargas parciales, feromonas
mantenidas y 500 retornos simultáneos desde estos pasillos.

## Consumo y frentes vivos

El material que falta en el dibujo también falta en la navegación, aunque
queden restos en los cuatro extremos de una celda. La misma máscara R8 y su
árbol de ocupación resuelven huecos, distancias y segmentos; no se reconstruye
una lista de rectángulos por cada bocado ni se agregan cuerpos físicos.

Las portadoras entregan lo recogido cuando pierden el contacto, sin perseguir
otra orilla para completar el buche. Si el frente sigue al alcance, conservan
su capacidad normal. Se ven las tres muestras más recientes, a escala real.
Los puestos laterales se proyectan sobre el contorno vivo con intentos locales
acotados, para no concentrar a todas las trabajadoras en el mismo punto.

La marcha llega al puesto antes de empezar a trabajar (0,25u de tolerancia);
el alcance de adquisición ya no la frena cuatro unidades antes. En una cara
recta el apoyo está a 9u; curvas y esquinas conservan el margen de navegación.
Se retiene la distancia real del apoyo elegido: si ese borde retrocede,
se busca otro puesto o se entrega la carga parcial, en vez de agrandar el alcance.
Si otra boca retira el contacto, se revisa al cambiar la vida del recurso,
sin esperar la siguiente mordida ni la publicación diferida de geometría.
Hasta cuatro lecturas directas de la máscara conservan el apoyo cuando el
corte fue lejos; sólo se busca otra frontera si ese punto dejó de existir.
Los alimentos miran ese contacto, no el centro de una silueta ya agujereada.
El caché de puestos también recuerda su contacto y descarta los apoyos retirados.

Al volver con carga puede desandar el tramo de ida realmente recorrido
mientras espera la ruta global. Sólo reutiliza ese prefijo si sigue sobre
su último segmento; no inventa rectas, no atraviesa muebles ni entrega a
distancia. La cola y sus límites de rutas/tiempo siguen vigentes.

Comer tiene cuatro poses propias: patas apoyadas, cabeza contra el contacto
real y mandíbulas que abren y cierran a dos ciclos visuales por segundo. El
gesto continúa al trabajar material duro, aunque todavía no salga un píxel;
el tirón y la carga sólo aparecen cuando se desprende un trozo real. Esperar
una máscara, seguir el cursor o quedar quieta no muestran esa masticación.
Reutiliza los dos sprites y el tick visual de 12 Hz; no agrega partículas,
tweens, consultas geométricas ni daño desde el dibujo. Al alejarse se omite
el detalle, sin agrandar las hormigas.

Mantener feromonas sobre un mueble conserva la orden cuando se abre un hueco
bajo el cursor. Salir de su huella, apuntar a otro recurso o soltar reemplaza
esa orden. La hormiga igualmente debe llegar al material para morderlo.

El veneno queda en una mancha de contacto inicial de hasta 32×32 unidades;
no sigue avanzando por toda una mesa desde una roja quieta. Cada servicio
retira una porción de hasta 16 unidades. Agotar la mancha cancela ese origen,
sin convertir crédito pendiente en dinero. Manchas, fragmentos y números se
ubican junto al material retirado. Hasta 64 contactos recordados por recurso.

Regresiones específicas: `prueba_ciclo_consumo`, `prueba_geometria_material`,
`prueba_geometria_veneno`, `prueba_erosion_presupuestada` y
`prueba_frente_mesa`. La última se puede ejecutar con renderer real a
1920×1080 para guardar capturas en `.godot/qa/mesa_*`; acelera daño y viajes
del fixture, no estima el ritmo ni la duración de una partida humana.

## Exportar

*Proyecto → Exportar → Agregar → Windows Desktop* (la primera vez Godot pide descargar las plantillas de exportación). Si al exportar faltan los CSV, agreguen `datos/*.csv` en *Recursos → Filtros para exportar archivos que no son recursos*.

# Diseño de la progresión: de la casa a la Torre Eiffel

## El problema

Con el balance anterior, un jugador activo compraba **todas** las mejoras y
castas antes del minuto 60. Después de la casa no quedaba en qué gastar: los
cinco destinos siguientes caían en una run cada uno y el juego terminaba
en ~1 hora. Fundar una colonia era opcional y daba poco (+10% por corona),
así que nadie lo hacía.

Un incremental dura porque siempre hay **una capa nueva cerca** y **algo en
qué gastar**. Lo lento tiene que venir de sumar capas, no de esperar más.

## Las tres capas

```
 Migas  ──►  mejoras (topes que suben con cada destino, hitos cada 25 niveles)
   │
   ▼ gran objetivo
 Coronas ──► fundar colonia ──► Jalea real ──► árbol de la reina (permanente)
   │                                 │
   ▼                                 ▼
 Destinos ──► suben topes y traen mejoras propias      bonus pasivo por jalea ganada
```

### 1. Migas (la run)

- **Topes que suben con los destinos.** Cada mejora tiene su nivel máximo
  base (`nivel_max`) y suma `tope_por_destino` niveles por cada destino
  conquistado en la partida. Los destinos conquistados no se pierden al
  fundar, así que el techo sólo crece.
- **Hitos de nivel.** Algunas mejoras (`bonus_cada`, `bonus_mult`) multiplican
  su stat cada N niveles: Mandíbulas fuertes y Mandíbulas cooperativas duplican el daño
  cada 25 niveles. Esos saltos se anuncian en la tarjeta ("hito en nivel 25").
- **Mejoras de destino.** Cada destino agrega mejoras propias a las ramas del
  hormiguero (columna `destino`). Se ven bloqueadas ("Se descubre en el
  restaurante") desde que se revela la pestaña Viajes: así la meta de viajar
  está a la vista.

### 2. Coronas → Jalea real (el prestigio)

Fundar una colonia reinicia migas, mejoras y castas, y convierte lo logrado en
**jalea real**:

```
jalea al fundar = 3 × coronas de esta colonia + ⌊ (migas juntadas en la colonia / 100.000) ^ ¼ ⌋
```

- Las coronas premian conquistar; las migas premian empujar aunque estés
  trabado. Así siempre conviene fundar cuando te estancás, aunque no hayas
  conquistado nada nuevo.
- La jalea **se gasta** en el árbol de la reina (`datos/jalea.csv`), que es
  permanente.
- Además, toda la jalea ganada en la historia (`Juego.legado`) da un **bonus
  pasivo** de +3% de daño y migas por punto, aunque la hayas gastado. Gastar
  nunca se siente como perder.

El árbol de la reina mezcla tres tipos de premio:

| Tipo | Ejemplos | Para qué |
|---|---|---|
| Atajos | Memoria de la madera / del metal / de la piedra (empezar con la dieta aprendida), Reservas de la reina (conservar % de migas), Linaje (conservar % de castas) | Que cada colonia nueva arranque más arriba y la primera hora no se repita igual |
| Poder | Mandíbulas de jalea, Despensa real, Obreras reales, Reloj de arena | Multiplicadores que hacen viable el destino siguiente |
| Nuevas reglas | Cámaras más hondas (+5 niveles de tope), Guardia de la reina (+1 pisotón automático por segundo desde el comienzo de cada colonia), Corona doble | Cambian cómo se juega, no sólo los números |

#### Decretos de la reina: una decisión por colonia

El árbol solo era una lista de compras: el bot compraba lo más barato y llegaba
igual. Ahora, al fundar, se elige **un decreto** que rige toda la colonia nueva
(`datos/decretos.csv`). Cada uno tiene una ventaja y un costo, y sirve para
otro plan:

| Decreto | Ventaja | Costo | Para qué |
|---|---|---|---|
| Numerosa | +50% obreras, +2 crías cada 10 s | muerden 25% más lento | Más daño sostenido: grandes objetivos |
| Guerrera | Pisotón ×3, mordidas ×1.5 | 30% menos obreras | Jugar activo; las comidas caen rápido |
| Recolectora | Migas ×2 | 15 s menos por expedición | Juntar migas (y jalea por migas) |
| Exploradora | Territorio +35%, velocidad +25%, olfato +30% | mordidas 25% más débiles | Llegar lejos con pocas mejoras |

La primera colonia no tiene decreto. La ventana de fundar propone el decreto
vigente, para que repetir sea un clic.

#### Pisada automática

Una mejora barata del taller (Pisada automática, desde Mandíbulas cooperativas 2) suma 0,5
pisotones por segundo sobre la comida más cercana al cursor, hasta 3 por
segundo. Se conserva esta mecánica de `main`; el clic manual no daña alimentos,
sólo interactúa con amenazas y premios. La Guardia de la reina hace lo mismo desde el comienzo de
cada colonia.

### 3. Destinos

Cada gran objetivo es un chequeo de daño **dentro de una sola run** (la casa se
reconstruye en cada expedición). Su resistencia (`vida_meta` en `mundo/mundos.gd`)
conserva los valores más recientes de `main`. El piloto de abajo precede a la
integración de eventos, decretos y esos valores; no mide la versión integrada. El ciclo buscado es
**conquistar → fundar → volver más fuerte**; los tiempos tardíos deben recalibrarse
con el bot corregido antes de afirmar una duración de campaña.

## Ritmo (jugador activo, medido con el bot)

El bot anterior usaba `Engine.time_scale = 8`, mordidas limitadas por cuadro y
seis rutas por cuadro. Eso le daba ocho veces menos oportunidades por segundo
simulado y distorsionaba la progresión; además hacía daño por clic. Sus tiempos
de campaña de ~10,7 h no son una medición válida de esta revisión.

Ahora avanza pasos de 1/60 s, tiempo ×1 y FPS ilimitados. Un piloto desde cero
(28/10, límite de 65 minutos, termina la última run en 66,6, sin partida prefijada,
con la IA, entradas y Corte continuo actuales) obtuvo, incluyendo la retirada:

| Hito | Minuto | Fundaciones |
|---|---:|---:|
| Mandíbulas 4 / primera casta | 4,3 | 0 |
| Madera (900 migas) | 7,3 | 0 |
| Resistentes (150.000 migas) | 26,1 | 0 |
| Paredes (4.000.000 migas) / casa conquistada | 33,1 | 0 |
| Restaurante conquistado | 38,2 | 0 |
| Primera fundación (+23 jalea) | 38,2 | 1 |
| Museo conquistado | 58,1 | 1 |
| Segunda fundación (+48 jalea) | 60,8 | 2 |

No es una predicción de cuánto tarda un jugador ni una calibración de todos
los destinos. El bot compra barato, ahorra dietas y sostiene el llamado; no
optimiza el equipo de evoluciones. Se repite con `tests/bot_balance.tscn`.
La semilla inicial es fija, pero la admisión temporal de rutas puede variar con
el equipo: los resultados no son una promesa de tiempos exactos.

## Comportamientos y sinergias, sin costo cuadrático

- Cuatro evoluciones persistentes, dos equipadas gratis entre expediciones.
  Cambian una conducta (dos cortes, contagio acotado, barrido o camada), no sólo
  multiplican números. Sus requisitos se muestran en la ficha de casta.
- Los hallazgos compartidos son una memoria de 24 objetivos; consulta cada
  0,6 s sólo cuando falla el olfato local. Las reservas de trabajo evitan
  amontonar toda la colonia en una miga, sin colisiones entre hormigas.
- El tutorial tiene un banquito de cartón de 20 de vida y 180 de valor:
  ocho obreras pueden mostrar mordidas y derrumbe antes de comprar madera.
- Cada destino tiene una regla sobre el mismo sistema: festín, vitrinas,
  fases vulnerables, dominó limitado o desmontaje desde la base.
- Se mantiene el reinicio del mapa en cada expedición. Las reglas no guardan
  mundos en segundo plano; las evoluciones desbloqueadas sí persisten al fundar.

## Logística, claridad y ritmo (28/10)

La madera baja de 3.000 a **900 migas** para que el primer material nuevo
aparezca antes. No se bajaron las resistencias tardías ni se agregaron monedas.
El tutorial de cartón sigue accesible desde el inicio. La nueva mejora Entradas
secundarias cuesta 800 inicialmente (×4 por nivel), con cinco niveles y una
sexta entrada permanente por conquistar la casa. Se habilita después de madera.

Los accesos se colocan una vez por escenario en puntos libres, separados y
deterministas. Primero se cubren ambientes; plazas y salones grandes reciben
puntos adicionales. Sólo abren dentro del territorio. Al regresar se elige por
distancia euclídea entre hasta siete puntos; la navegación normal confirma el
camino y descarta una entrada si falla. No se garantiza el trayecto de menor
longitud global ni se ejecutan búsquedas fuera del presupuesto de rutas.

La retirada dura hasta seis segundos, diez con la adaptación de Eiffel.
Las hormigas que ya regresaban conservan su ruta y posición en la cola;
no se solicitan cientos de rutas nuevas al cambiar de fase.
No genera recursos: sólo entrega cargas ya extraídas. Un regreso inaccesible
no prolonga el cierre ni cobra mágicamente; se informa lo que quedó en camino.
Migas/s incluye el tiempo de retirada y el desglose conserva los materiales
originales incluso al fusionar montones. Los acumuladores usan flotantes de
64 bits, no vectores de precisión simple. Récords de producción y daño máximo
por destino sobreviven a fundar; el daño físico del mapa se sigue reiniciando.

Las seis conquistas conceden adaptaciones permanentes, definidas en
`datos/adaptaciones.csv`: acceso, festín, hallazgos, corrosión, soportes y
retirada. Modifican el escenario activo, sin simular los anteriores. El dominó
heredado usa la misma cola limitada a 24 eslabones del Coliseo, con golpes del
10% fuera de los arcos del Coliseo. El premio por hallazgos conserva el máximo
de 24 alimentos ocultos. La vista previa de jalea muestra opciones alcanzables
individualmente y aclara que no constituye una compra conjunta.

El piso, marcas de materiales, señales de escondites y trazos de habilidades
usan el atlas/shader y efectos compartidos. Ninguna mejora requiere física por
fragmento ni aumentar el límite de 500 hormigas. Los objetivos de acercamiento
se conservan hasta cambiar de recurso o geometría, reduciendo cambios de ruta.

Las pruebas y mediciones gráficas están en `tests/RENDIMIENTO.md`.

### Primera demostración de madera y claridad de decisiones (28/10)

El piloto anterior no daba órdenes hacia madera: después del cartón dirigía a
comida hasta poder atacar el gran objetivo. Por eso la separación entre comprar
madera (7,3 min) y registrar una segunda pieza (~20 min) no demuestra por sí sola
que una persona tarde eso en desmontar un mueble.

Se ajusta sólo la silla cercana `mueble:6` de la casa, perfil `silla_inicial`:
140 de resistencia y 420 de valor en `stats_base.csv`, frente a 700/2100. Mantiene
la proporción de tres migas por daño, dieta, geometría, secciones y transporte.
El resto del mobiliario y las resistencias tardías no cambian. El HUD ofrece
ver esa silla tras comprar madera. El cartón no concede los hitos de sillas de
madera; las partidas anteriores conservan los hitos ya ganados.

`tests/prueba_primera_madera.tscn` compara ambas resistencias con semilla 417,
ocho obreras, Mandíbulas 4, madera aprendida y el mismo llamado. Muestra el
primer recorte antes de los 15 segundos y desmontaje dentro de una expedición.
Última medición integrada local: primera sección ~14,1 → ~2,4 s; desmontaje
~41,7 → ~8,2 s. El presupuesto temporal de rutas puede variar las trayectorias.
La primera entrega sigue alrededor de 3,6 s: se acorta el desmontaje, no se
inventa una mejora de transporte. El valor potencial es 525 de madera contando
el bonus de destrucción de 25%; la extracción debe transportarse para cobrarla.
En esa ejecución se entregaron 312,6 dentro de la expedición. No es un tiempo
previsto para una persona ni una garantía de cobrar todo el recurso.

Las fichas explican las parejas existentes (extracción/carga, corrosión/daño,
alcance/atajos). Es una ayuda para experimentar, no prueba de balance de todas
las castas. La vista previa de fundación muestra el arranque exacto con cada
decreto, herencias compradas y legado nuevo, sin asumir compras de jalea. Se
verifica contra una fundación real para los cuatro decretos y sin mutaciones.
La sensación de avance tras el primer reinicio sigue pendiente de playtest.

### Especialistas que cambian el trabajo

Corte aserrado reparte el mismo daño entre dos secciones de madera, pero ahora
deja también su porción de la extracción en montones y continúa trabajando.
No multiplica el recurso ni lo acredita: la colonia debe transportarlo.
Esto permite combinar carpinteras productoras con cargadoras y Barrido.

`tests/comparar_castas.tscn` compara una expedición con presupuesto de 1.200,
las mismas mejoras base, semilla y órdenes sobre madera. Resultado local:

| Compra | Gasto | Migas entregadas | Piezas destruidas | Migas/s |
|---|---:|---:|---:|---:|
| 28 obreras | 1.145 | 6.825 | 3 | 103,3 |
| 24 obreras + carpintera + cargadora | 1.076 | 7.235 | 4 | 109,5 |

El equipo mixto entrega aproximadamente 6% más, con menos gasto y una pieza
adicional. Es una prueba de esa sinergia en ese escenario, no evidencia de
que todas las castas estén balanceadas ni de que sea siempre la mejor compra.

## Preguntas abiertas

- **Campaña tardía.** Volver a medir desde el restaurante hasta la Torre
  Eiffel con paso correcto y sin daño por clic antes de tocar sus resistencias.
- **¿El árbol tiene decisiones?** El bot compra siempre lo más barato y llega
  igual. Conviene probar si un jugador que prioriza poder sobre atajos
  termina mucho antes; si no hay diferencia, el árbol es una lista de
  compras y no una elección.
- **Primera fundación.** Se propone tras conquistar la casa, sin cerrar el
  restaurante. Hay que mirar con gente real si se entiende qué cambia al
  fundar y si prefieren hacerlo o seguir viajando.

### Eventos incorporados desde main


Con la misma comida y los muebles de la casa reacomodados, los destinos se
sentían iguales (es la queja más común contra Idle Ants, el juego de celular
con la misma idea). Ahora cada destino trae tres comidas propias y una amenaza
con su propia regla. Las amenazas cumplen dos funciones:

- **Una decisión en la run.** Clickear la amenaza o seguir guiando a la colonia.
  La mejora automática no las resuelve, así que el jugador que mira la pantalla
  gana más que el que la deja sola.
- **Riesgo en un género tranquilo.** Perder hormigas o una comida grande duele
  un poco, pero vencerlas paga un botín (12% de lo juntado en la run, o lo que
  la amenaza se había llevado ×1,5).

La miga dorada es el estímulo corto clásico de los incrementales (la galleta
dorada de Cookie Clicker): aparece cerca de lo que se mira y dura 9 s.

## Reconquista, limpieza y hormiguero completo (28/10)

Se separan dos progresos de viaje. `lugares_completados` es histórico y sigue
otorgando adaptaciones y topes. `coronas_cobradas` pertenece a la colonia actual:
para viajar se necesita haber conquistado todos los destinos anteriores en esa
colonia. Fundar borra sólo este segundo recorrido y vuelve a casa. Los campos
antiguos se cargan con sus valores conocidos, sin borrar descubrimientos ni
inventar limpiezas. Las mejoras que requieren un destino se habilitan al reabrirlo.

Los planos conservan límites, metas, resistencia y tutorial, pero pasan a tener
55/49/29/33/39/37 muebles (casa a París). Se agregan objetos característicos,
no nuevas simulaciones ni mapas inactivos. Sólo diez alimentos chicos aumentan
entre 11% y 15%; el catálogo pasa de 1347 a 1438 unidades (+6,8%), que no es
el conteo final de cada escenario. No se aumenta el valor ni la vida de los
grandes objetivos. El piloto corto de aquella revisión, 13,4 minutos simulados desde cero,
llega a Mandíbulas 4 a los 4,4 min y madera a los 7,5 min. No alcanza fundación
ni valida la duración de la campaña, especialmente tras la reconquista nueva.
Es una referencia histórica; el piloto hasta fundar se documenta más abajo.

Cada 0,5 s se comprueba si queda comida, fragmentos o material permitido dentro
del territorio. La salida inicial, expansión del alcance, derrumbes, cadenas y
botín recuperable no se toman como limpieza. Tampoco se confunde un recurso
sin ruta o con sus puestos ocupados con un recurso inexistente. Al agotarse lo
disponible se inicia la retirada normal. La marca fecha el último cambio
relevante (o el fin del botín), no el siguiente chequeo ni el regreso al nido.
Cambios fuera de alcance o sobre materiales bloqueados no mueven ese reloj.
Se guarda sólo cuando el cierre normal termina; salir antes no crea una marca.

“Zona despejada” permite que queden materiales todavía bloqueados o recursos
lejanos; “Mapa despejado” exige que no quede nada en el escenario. Ambos tienen
categorías separadas por destino, dieta, alcance redondeado a una unidad y
versión del contenido (2 en esa revisión; 3 tras ampliar la periferia). No se pretende una tabla competitiva:
las compras y el poder de la colonia pueden diferir. Se conservan 128 registros
recientes y 1024 mejores contextos; la interfaz construye como máximo ocho
tarjetas a la vez. El JSON exportado contiene sólo ese archivo, no la partida.
Los datos se validan al cargar, y el guardado sube a versión 7.

El hormiguero representa las mejoras existentes, no agrega multiplicadores:
31 cámaras agrupadas en seis ramas con conexiones de requisito reales. Al
comprar crecen cámaras/túneles y aparece decoración acotada. Las cuatro secciones
se mantienen en un corte completo; la ficha de compra es flotante y cerrable.
Fondo retenido, hormigas decorativas compartidas y sin IA de expedición.

## Pulido del primer recorrido (28/10, posterior a requisitos múltiples)

No se modifican costos, resistencia, cantidad de hormigas ni valores tardíos.
La mejora se concentra en continuidad de trabajo, claridad y uso de las
ventajas permanentes. Un recurso que ya llega a la boca no necesita otra ruta;
una trabajadora mordiendo quieta reutiliza la comprobación de alcance hasta
que cambia su pieza, versión geométrica o posición. Se mantienen las cuotas.

La próxima meta incluye una acción/id de interfaz, sin ejecutar la decisión.
Tras la primera conquista de casa propone fundar, pero el restaurante sigue
abierto. No se añade una barrera de prestigio ni se regalan memorias. La
ventana permite elegir compras explícitas al confirmar: memoria (3 de jalea)
o cuadrilla (memoria + obreras reales + mandíbulas de jalea, 6). También se
puede conservar toda la jalea y elegir después. Los planes alcanzan niveles
mínimos y no vuelven a cobrar los ya aprendidos.

La cotización es pura, acotada a doce compras y atómica: un requisito, máximo
o saldo inválido rechaza el conjunto antes de reiniciar. La vista previa usa
el mismo contexto de niveles de jalea que el resultado real; el legado suma
toda la jalea ganada aunque se gaste. Reservas y Linaje comprados en ese acto
no actúan retroactivamente sobre la colonia que ya termina. El guardado sigue
en versión 7; no necesita campos nuevos. Se corrige también una duplicación
visual: la meta no vuelve a sumar migas_run que ya fueron acreditadas al saldo.

### Medición del pulido anterior, no duración prometida

El bot ahora registra compras al comprarlas, no al cerrar la siguiente run.
Se conserva la política original por cercanía; `BOT_ORDEN=materiales` es una
política distinta: cartón → silla de madera → material recién aprendido → meta.
`BOT_FUNDAR_CASA=1` elige fundar tras casa. No hay daño manual ni tiempo ×8.
Piloto final, semilla 417, ×1 y 1/60, IA actual y sin guardado personal:

| Suceso | Minuto activo de expediciones |
|---|---:|
| Madera comprada | 6,24 |
| Primera silla | 6,38 |
| Resistentes comprados | 11,80 |
| Paredes compradas | 14,38 |
| Gran mesa devorada | 15,18 |
| Cierre / primera fundación, 7 jaleas | 16,93 |

Los minutos no incluyen pensar en la tienda. La política original de cercanía
de una pasada previa llegó al primer reinicio después del restaurante a los
25,0 min; no es una comparación A/B aislada con esa tabla. Orden de trabajo,
semilla temporal y admisión de rutas pueden cambiar resultados. Los pilotos
anteriores de 38 min no describen esta versión integrada.

Dos retornos desde **el mismo snapshot real** de casa y las mismas 7 jaleas,
con decreto Numerosa y sus hitos/adaptaciones, sin compras ficticias:

| Preparación | Jalea restante | Primera silla | Primera expedición | Segunda expedición |
|---|---:|---:|---:|---:|
| Memoria, costo 3 | 4 | 29,8 s | 742 migas · 15,5/s | 3906 migas · 66,8/s |
| Cuadrilla, costo 6 | 1 | 23,0 s | 1176 migas · 20,5/s | 7456 migas · 103,7/s |

La segunda expedición incluye compras hechas con ingresos reales de la primera;
no es sólo el efecto aislado del plan. No asegura esos tiempos para todos los
decretos ni muestra que la opción más cara sea siempre mejor. Ambas variantes
ya pueden comer y transportar madera al regresar. `BOT_INICIO` permite leer
un snapshot sin sobrescribirlo; los resultados van a una ruta QA distinta.

`comparar_planes_casa` estudia tres semillas con presupuesto 2400. Las medias
fueron 82,5 / 104,8 / 98,8 migas/s para obreras / corte / corte+barrido, pero
el gasto efectivo fue 1785 / 2395 / 2235 y no hubo ganador universal. No justifica
prometer +27%, ni reemplaza sesiones humanas. No se ajustó balance con esa muestra.

La prueba jugable aislada y el protocolo están en `docs/PRUEBA_CASA.md`.

## Inicio más gradual y periferia jugable (28/10, revisión posterior)

El pedido nuevo es alargar moderadamente el recorrido y sostener el crecimiento
por más tiempo. Se ajustan sólo nueve filas de `mejoras.csv`: obreras 8→12,
mandíbulas 12→18, cooperativas 10→15, buche 30→40, recolección 100→135
(crecimiento 1,9→2), huevos 5000→7500 y dietas 900→1500 / 150K→450K /
4M→12M. Se conservan efectos, topes, resistencia de objetos, ocho obreras,
velocidad, olfato, mordida y castas. No se vuelve torpe a la IA para frenar ingresos.
Las Memorias y Cuadrilla cuestan lo mismo; cargar una partida no cobra diferencias
por niveles anteriores ni elimina compras.

`tests/medir_ritmo_casa.tscn` permite comparar economía con `RITMO_BASELINE=1`:
repone los precios anteriores sólo en memoria antes de lanzar el bot. No usa
una partida con compras prefijadas ni revierte archivos. Control y candidato
final comparten los hashes de plano, mundos, comidas, IA y estado global;
semilla 417, paso 1/60, tiempo ×1, política materiales y fundar tras la casa.

| Hito | Precios anteriores sobre el mapa ampliado | Nuevos precios |
|---|---:|---:|
| Mandíbulas 4 | 3,28 min | 5,36 min |
| Madera | 6,35 min | 8,36 min |
| Resistentes | 11,96 min | 17,91 min |
| Paredes | 14,41 min | 22,35 min |
| Primera fundación | 15,83 min / 14 expediciones | 23,87 min / 19 expediciones |

Esta comparación definitiva se repitió después de los ahorros de geometría y
veneno y del límite del llamado. También coinciden las huellas de Comida,
PiezaCasa, feromonas, CSV y bot entre ambos pilotos. El reinicio tarda 50,8%
más en esa estrategia; la madera, aproximadamente 32%. La primera especialista
sigue cerca de 3,3 minutos en ambos: no se esconden los roles para alargarla.
Tras aprender madera, el primer recorte de silla pasó de 7,2 a 5,2 s y el
desmontaje de 9,6 a 7,4 s: la mayor duración no viene de volverla torpe.
Ambos pilotos produjeron once jaleas; pagaron Cuadrilla por seis y quedaron cinco.
Son muestras sintéticas, sin tiempo de decisiones en tienda; el presupuesto
temporal de rutas puede cambiar trayectorias. No validan diversión humana ni
la duración tardía. Una pareja anterior al último pulido dio +25,5%; no se
mezcla con esta medición ni se promete un porcentaje exacto a cada persona.
Los pilotos anteriores de 16,93 y 38 minutos también quedan históricos.

### Terreno cercano y paisaje lejano

Los seis destinos conservan su interior y gran objetivo. La navegación pasa
de 7900×5600 a 10300×7400 (+30,4% de ancho, +32,1% de alto y aproximadamente
72% más de superficie).
Un cinturón cercano contiene ocho muebles reales y como máximo seis alimentos
trasladados desde fuera del arranque (hasta 5% del total). Se conservan cantidad
y valor alimentario, el azar de colocación interior y los recursos hasta 900.
Los muebles sí agregan resistencia y valor al mapa. Casa, restaurante y museo
tienen cuatro aperturas hacia el exterior; las plazas pierden su muro rectangular.

Más allá hay contexto dibujado y retenido, sin recursos, colisiones ni A*:
el fondo no extiende el grafo a sus 15600×9200. Ese ancho decorativo permite
encuadrar el terreno completo en 16:9. La cámara calcula su mínimo según el
viewport, limita toda su extensión visible (incluido el temblor) y reacciona
al redimensionar. Los límites se cachean por expedición, sin recorrer muebles
por cuadro. No hay texturas por instancia ni aumento del atlas compartido.

La versión de contenido sube a 3 para separar récords de limpieza con esta
geometría; el formato de partida sigue en 7 y conserva el archivo histórico.

## Qué se puede tocar sin programar

- `datos/mejoras.csv`: columnas nuevas `destino`, `tope_por_destino`,
  `elevable` (le afecta Cámaras más hondas), `bonus_cada`, `bonus_mult`.
  `requiere` acepta varias condiciones (`buche:2|veloz:1`); una condición puede
  ser una mejora (su nivel) o una casta (unidades reclutadas). Lo mismo en
  `datos/castas.csv`.
- Stats que antes eran constantes y ahora puede mover una mejora (en
  `stats_base.csv` conservan el valor de siempre): `frenesi_duracion` (6 s),
  `frenesi_ritmo` (×1,5), `bonus_destruir` (25% del valor al destruir),
  `botin_eventos` (12% de la run por amenaza o miga dorada),
  `intervalo_doradas` (×1 sobre la espera entre doradas),
  `fuerza_especialistas` (×1 al daño de las castas que se reclutan) y
  `limite_castas` (+0 unidades por casta).
- `datos/jalea.csv`: el árbol de la reina. Los nodos con `efecto = stat`
  funcionan como mejoras (stat, tipo, valor); el resto tiene un efecto
  especial programado en `Juego` (ver `EFECTOS_JALEA`).
- `mundo/mundos.gd`: `vida_meta` y `coronas` de cada destino.
- `Juego.JALEA_POR_CORONA`, `Juego.DIVISOR_JALEA_MIGAS`, `Juego.BONUS_LEGADO`.

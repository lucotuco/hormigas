# Diseño de la progresión: de la casa a la Torre Eiffel

> Extracción vigente: la revisión «Bocado local y carga de la porción real»
> del 30/10 reemplaza los recortes por frentes del 29/10. Se conserva el
> arranque individual, pero los pilotos anteriores —incluido el de 35,11
> minutos— son históricos: no predicen ni validan el ritmo de esta revisión.

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

## El hormiguero ramificado (29/10)

La tienda pasa a ser el hormiguero del lienzo de diseño: la reina en el centro,
Viajes en la boca y siete ramas que se separan y se vuelven a juntar. Para
llenarlo, `mejoras.csv` pasa de 31 a 82 filas y las castas se vuelven una rama.

**Cómo se ordenan.** El anillo de una cámara es su momento en la partida:

| Anillo | Precio base | Para qué |
|---|---|---|
| 1 (sale de la reina) | 10–40 | Las raíces de siempre: obreras, mandíbulas, buche, llamado, reservas, territorio, veloz |
| 2–3 | 15–6.000 | Primeras decisiones de la casa: madera, frenesí, retirada, escondites, castas |
| 4 | 4.000–600.000 | Entre madera y paredes: daño, población, derrumbes, especialistas |
| 5–6 y el fondo | 10⁶ en adelante | Casi todas con `destino` (24 nuevas): cada viaje trae cámaras propias en qué gastar |

Las 51 nuevas reparten sus efectos entre stats que ya existían y las siete que
el PR anterior volvió stats (frenesí, bonus al destruir, botín, doradas, fuerza
y límite de castas). Muchas tienen efectos acotados por diseño: los derrumbes
en cadena siguen limitados a 24 eslabones y los escondites a 24 alimentos. Las
**compartidas** (`rama = A|B`) piden una mejora de cada rama: son las que hacen
que las ramas se crucen.

**Requisitos que cambian para que los túneles sean reales:**

- Madera pide además Mordida rápida 1 (y Acero, Mordida rápida 1). La meta de
  los primeros minutos queda: Mandíbulas 4 → Mordida rápida → migas para madera.
- Mandíbulas cooperativas pide Mandíbulas 1 y Buche 1 (es la cámara que une
  Mandíbulas con Recolección); Recolección eficiente pasa por ella.
- Buche y Explorar la casa ya no piden nada: son raíces de su rama.
  Entradas secundarias pide Explorar la casa 6 en vez de madera (abrir otro
  ambiente es lo que la hace útil).
- Coordinación pide Antenas 1; Segundo aire, Vuelta a casa 1.
- Las castas se reclutan en cadena: veloz → roja → cargadora → voladora → reina;
  carpintera pide cargadora (y madera) y demoledora, carpintera y reina (y paredes).
- Las diez mejoras de destino que ya existían piden una cámara de su rama,
  además de su destino.

**Medición.** Bot con `BOT_ORDEN=materiales`, semilla 417, paso 1/60.
El mismo `main` dio 41,9 y 37,4 minutos de campaña en dos corridas seguidas:
la admisión de rutas por tiempo hace que haya ±3 minutos de ruido, así que
sólo se compara contra ese rango.

| Hito | `main` (dos corridas) | Con el hormiguero |
|---|---:|---:|
| Mandíbulas 4 | 4,2 – 5,5 | 5,4 – 5,6 |
| Madera | 7,5 – 8,9 | 8,7 – 10,1 |
| Resistentes | 15,6 – 17,0 | 16,9 – 17,9 |
| Paredes | 19,1 – 20,8 | 20,0 – 21,1 |
| Casa conquistada | 20,7 – 22,3 | 21,5 – 22,1 |
| Museo | 29,9 – 32,7 | 34,0 |
| Coliseo | 31,0 – 34,9 | 34,9 |
| Torre Eiffel (fin) | 37,4 – 41,9 | 40,3 |

(Los dos primeros valores de cada fila del hormiguero son el piloto de casa
`medir_ritmo_casa` y la campaña larga.) La primera versión de los datos llegaba
a la Torre en 35,5 minutos: el frenesí, el límite de castas y los derrumbes
en cadena pegaban fuerte en la segunda colonia. Se bajaron (en la casa el frenesí
llega a ×1,8 y 9 s; el límite de castas a +2; cada golpe en cadena, 3–4%) y las mejoras del anillo 4 se
encarecieron ×3 para que lleguen después de madera, no antes.

Lo que sigue pendiente, y no viene de este cambio: en el bot la campaña
completa ya duraba ~42 minutos con el `main` anterior. Museo, Obelisco y
Coliseo caen en una run cada uno después de una fundación. Las cámaras de
destino dan dónde gastar en ese tramo, pero hace falta recalibrar `vida_meta`
de esos destinos para que cada uno pida su propia colonia.

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

## Arranque con una sola obrera (29/10, revisión posterior)

El nuevo pedido cambia la escala de la colonia, no la calidad de sus
decisiones. Se empieza con **una obrera**; Más obreras suma **una** por nivel.
La primera compra conserva el precio de 12 migas: es la excepción al aumento
de costos, para que ganar una segunda trabajadora no requiera decenas de
expediciones. Su crecimiento sigue siendo ×1,55 y se mantienen los topes.
No se compensa con nacimientos gratuitos, daño por clic ni ingreso automático.

La mordida base pasa de 0,6 a **0,95 segundos**, conservando un punto de daño.
La velocidad 95, olfato 45, territorio 620, capacidad uno y expedición de
45 segundos no cambian. Los tiempos de decisión, navegación y admisión de
rutas tampoco se usan para desacelerar el juego. Las mejoras de velocidad y
frecuencia siguen haciendo crecer esas capacidades.

Las demás mejoras cuestan aproximadamente **20–25% más**. Algunos ejemplos:
Mandíbulas 18→22, Buche 40→50, Madera 1500→1800, Resistentes 450K→550K y
Paredes 12M→15M. No cambian los requisitos, los hitos multiplicativos ni los
efectos de las otras mejoras. Los precios y las reglas de las castas y la
jalea se conservan; también Memoria por tres y Cuadrilla por seis.

Para que los objetos duren y se pueda leer el trabajo de corte, la resistencia
de muebles y muros se multiplica por **1,6**, sin multiplicar su recompensa.
Se aplica una sola vez antes del perfil inicial y del tutorial. La primera
silla tiene **280 de vida y 420 de valor**, frente a 140/420: ya no mantiene
la antigua proporción de tres migas por daño. El cartón conserva 20/180.
Los alimentos medianos/grandes ganan entre 33% y 50% de vida, manteniendo
su recompensa, cantidad y distribución. Cereal y aceituna suben menos; las
migas de arranque conservan sus tres de vida y dos de valor. No se añaden
instancias, física por fragmento, recursos nuevos ni un mapa en segundo plano.

Una partida existente conserva dinero, niveles, castas, jalea e historial sin
cobros retroactivos. Los niveles se evalúan con el nuevo balance: ocho niveles
de Más obreras ahora son nueve obreras totales sin otros bonus, no el antiguo
total de veinticuatro. No hay una migración que regale niveles para mantener
la población previa. Las colonias fundadas conservan las Memorias y los
beneficios comprados; la Cuadrilla con Numerosa arranca con siete obreras
efectivas, frente a una desde cero.

La validación de aquella revisión separó tres preguntas. `prueba_arranque_solitario` simuló las
primeras expediciones sin ingresos prefijados, sola y guiada con el llamado,
y exigía poder pagar la segunda obrera en una o dos expediciones con el recorte anterior.
`prueba_primera_madera` usa explícitamente ocho obreras después de siete
niveles comprados y observa recorte, persistencia del resto y transporte;
no lo presenta como la colonia inicial. `prueba_primer_retorno` compara los
planes reales desde el mismo saldo, sin exigir que aprender madera derrumbe
la silla de inmediato. Las tablas anteriores de 21–24 minutos no calibran
este arranque. Las mediciones siguientes se hicieron después de integrar
los recortes y las cargas reales, con paso 1/60, ×1 y guardado personal
deshabilitado. Ninguna de estas pruebas demuestra diversión humana.

### Primera validación del arranque individual (histórica, 29/10)

Las cuatro suites específicas reúnen 91 verificaciones, sin fallos en una
pasada headless aislada. Con semilla 417, sin ingresos prefijados ni compras
automáticas, la segunda obrera se pudo pagar con 12 migas al terminar la
segunda expedición autónoma (~91,15 s activos; ingresos 8,07 y 8,60) o la
primera guiada al **centro del cartón** (~45,25 s; ingreso 35,10). La primera
entrega ocurrió alrededor de 5,87 y 7,18 s respectivamente. Esas mediciones
no incluyen pensar en la tienda y no aseguran que todas las personas sigan
la misma ruta o consigan el mismo ingreso.

La prueba de madera con ocho obreras compradas y Mandíbulas 4 mostró un
recorte de la silla inicial a ~6,2 s, primera entrega a ~4,13 s y 241,8 migas
de madera entregadas al cierre. A los cinco segundos conservaba 248 de sus
280 de vida; terminó con 32, sin derrumbarse de golpe. Una silla estándar
de 1120 de vida mostró su primer recorte completo a ~19,17 s con la misma
colonia. Los umbrales comprueban avance visible, persistencia y transporte,
no exigen volver al antiguo derrumbe dentro de una expedición.

Desde la misma fixture de primera fundación y siete jaleas, Cuadrilla pagada
por seis produjo ~313,66 migas, de las cuales ~111,23 fueron madera realmente
transportada; Memoria por tres produjo ~205,55 y ~14,06 de madera. Ambos usan
Numerosa, que aporta crías durante la expedición. Memoria sola dañó la silla
sin agotar una celda entera; no se presenta ese daño parcial como una pieza
devorada. Son comparaciones del primer regreso, no un ganador universal.

### Piloto hasta la primera fundación con el balance individual (histórico, 29/10)

Una pasada de `tests/medir_ritmo_casa.tscn`, semilla 417, política materiales,
`BOT_FUNDAR_CASA=1`, `BOT_RETORNO=0` y `BOT_JALEA=retorno`, terminó en
**35,11 minutos activos y 27 expediciones**. Comenzó desde cero, sin un
snapshot de compras previas. Se conservaron las huellas de las tres tablas,
IA, piezas, comidas y estado global entre el inicio y el cierre. No se usó
el modo `RITMO_BASELINE`, que sólo repone precios históricos y ya no
representaría por sí solo un control del antiguo arranque de ocho obreras.

| Suceso | Minuto activo de expediciones |
|---|---:|
| Cartón terminado | 1,89 |
| Primera especialista | 3,28 |
| Mandíbulas 4 | 7,41 |
| Madera comprada | 15,28 |
| Primer recorte / transporte de madera | 15,36 / 15,37 |
| Primera silla de madera terminada | 15,47 |
| Resistentes comprados | 29,22 |
| Paredes compradas | 33,31 |
| Gran mesa devorada | 33,73 |
| Cierre / primera fundación | 35,11 |

La colonia ganó diez jaleas, pagó Cuadrilla por seis y conservó cuatro.
La primera especialista aparece antes que la dieta de madera; el aumento
del tiempo no depende de esconder todos los roles hasta el minuto quince.
La silla del piloto cayó unos 11,1 segundos después de iniciar la expedición
posterior a la compra de madera: esa colonia ya tenía ocho obreras, mejoras
y especialistas, no era la única hormiga con que se empieza. El cierre incluye
las entregas y la retirada, no el tiempo de pensar y comprar en la tienda.

Este piloto describe una estrategia automática que compra por precio y ahorra
para dietas; no valida todas las rutas de compra ni promete treinta y cinco
minutos a una persona. La cola de navegación con presupuesto temporal puede
variar las trayectorias. No se compara su duración como un A/B aislado con las
tablas anteriores, que tenían otra población, resistencia, árbol y transporte.
La campaña posterior y las sesiones humanas siguen pendientes de validación.

### Mordida por frentes y carga representativa (histórico, 29/10)

Cada celda física mantiene cuatro frentes visuales que sólo pierden material.
El daño quita una franja en el lado atacado y la hormiga conserva una región
del mismo atlas para mostrar lo que transporta, con un tirón breve hacia la
boca. Al cambiar de lado no se mueve el agujero acumulado. Comidas y muebles
usan el mismo principio, sin cuerpos físicos por fragmento ni imágenes por
mordida. Las 16 celdas físicas y la cuota de navegación no aumentan.

La muestra visual está acotada a tres retazos por hormiga; no representa una
simulación volumétrica ni cambia el valor de la carga. Se mantienen el reparto
65/35, los montones de Corte continuo y la acreditación separada de veneno y
bonus de destrucción. Un mueble no entra en derrumbe automático hasta quedar
con un 8% de su resistencia; los restos finales caen de a una celda cada 0,35 s.

Las 82 descripciones de mejora ocupan como máximo 45 caracteres. Las fichas
conservan efecto, antes/después, costo y requisitos, sin el segundo párrafo de
ayuda. La versión de contenido pasa a **4** para no comparar récords del nuevo
ritmo/resistencia con los anteriores; el historial y la partida se conservan.

Las mediciones gráficas Full HD y sus límites están en `tests/RENDIMIENTO.md`.

## Bocado local y carga de la porción real (30/10)

La revisión anterior acumulaba daño visual por frentes, pero seguía pudiendo
retirar una franja grande con una mordida y achicar después la muestra cargada.
Validar daño, monotonía e ingresos no demostraba igualdad de tamaño entre lo
retirado, el hueco y la carga. Esa limitación invalida presentar los 35,11
minutos o las primeras expediciones guiadas al cartón como tiempos del sistema
nuevo; se conservan arriba como historial, no se extrapolan.

El bocado normal se limita ahora a una porción local de **hasta seis unidades
de mundo por lado**. La región aceptada de la fuente, el hueco que deja y la
muestra que viaja deben conservar su escala real. El daño alto no autoriza
vaciar varias celdas para mostrar luego una carga pequeña. Sólo el material
efectivamente retirado descuenta resistencia y produce valor; la extracción
normal viaja completa con la hormiga, sin el antiguo reparto automático 65/35.
Esto no agrega recompensas: una porción no se vuelve a pagar al transportarla
ni por cambiar de representación. Las rutas especiales de montones, corrosión
y derrumbe deben mantener su propia conservación del valor.

El cartón conserva su rectángulo de 110×130, 20 de vida y 180 de valor. No se
convierte en una caja diminuta ni en una fuente de dinero regalado: requiere
hacer crecer la colonia, no mantener una hormiga arrancando bloques enormes.
El desgaste del mapa sigue reiniciándose entre expediciones. Un chip máximo de 6×6 ocupa sólo el
0,252% de ese rectángulo; no es lógico cobrar por un daño entero si no se
retiró el material que ese daño representaba. Endurecer únicamente el cartón
o encoger virtualmente la carga tampoco corrige esa correspondencia.

Por eso el arranque guiado de `prueba_arranque_solitario` apunta a **migas
pequeñas ya generadas dentro del territorio** y cambia de objetivo al
agotarlas. No crea alimentos, no los acerca, no daña por script ni acredita
premios antes de entregarlos. Conserva la garantía de una sola obrera real.
El criterio acordado para esta revisión es poder pagar la segunda trabajadora
con ingresos de hasta cinco expediciones autónomas (cuatro minutos activos)
o tres guiadas, con primera entrega antes de diez segundos, sin simular saldos
ni dar dinero. Se acepta explícitamente un arranque más lento: no se promete
conservar las una o dos expediciones de la geometría anterior. La medición
se realizó después de corregir contacto, raster, agotamiento y reparto de HP
por área; los resultados siguientes no se extrapolan a la campaña.

El bot adopta esa misma preferencia antes de aprender materiales. En modo
`materiales`, una dieta aprendida conserva su orden explícita; los grandes
objetivos mantienen prioridad cuando se pueden trabajar. El cartón deja de
atraer toda la colonia mientras haya alimentos accesibles. Cambia la política
inicial respecto de los pilotos anteriores: no se deben presentar como una
comparación A/B que sólo haya variado la geometría. La campaña y el retorno
tras fundar requieren nuevas mediciones; no se asignan tiempos por estimación.

### Medición del primer ingreso y de la segunda obrera (30/10)

Con semilla 417, paso 1/60 y tiempo ×1, `prueba_arranque_solitario` pasó sus
25 verificaciones y `prueba_ritmo_economia`, las 36. Ambas terminaron sin errores
ni guardado personal. Todas las expediciones usaron una sola obrera real; la
compra se hizo al cierre con el saldo obtenido, no con ingresos prefijados.

| Arranque | Ingresos sucesivos | Compra de la segunda obrera | Tiempo activo acumulado |
|---|---|---|---:|
| Autónomo | 1,9063 · 4,9891 · 4,5910 · 1,9063 | Expedición 4; paga 12 de un saldo de 13,3927 | 181,00 s |
| Guiado a migas existentes | 5,6250 · 4,3750 · 5,0000 | Expedición 3; paga 12 de un saldo de 15,0000 | 136,62 s |

Las primeras entregas quedaron entre 5,87–5,90 s en autonomía y 1,80–1,87 s
en la guía. Se señalaron ocho migas reales entre las tres expediciones guiadas,
cambiando al agotarlas. La guía no crea ni mueve recursos, no extrae por script
y no aumenta su valor. El primer precio sigue siendo 12 y el siguiente 18;
no se introdujo un descuento para maquillar los nuevos bocados.

Son resultados de una pasada sintética y no una promesa de tiempo humano.
No incluyen pensar en la tienda. La navegación con presupuesto temporal puede
variar trayectorias e ingresos, aunque la semilla sea la misma. No validan
la duración hasta madera, la primera fundación ni los destinos posteriores:
el piloto de 35,11 minutos pertenece exclusivamente a la física anterior.

El contenido se identifica ahora con **versión de mapa 5**, para separar
récords de esta extracción/ritmo de los frentes de la versión 4. El formato
de guardado no cambia y se conserva el archivo histórico de expediciones.

### Campaña completa con la extracción de la versión 5 (30/10, tarde)

Dos pasadas de `bot_balance` (`BOT_ORDEN=materiales`, política de fundación
por defecto) sobre `main` con la presión de amenazas de #15. Minutos de juego
activo del bot; no incluyen la tienda.

| Hito | Pasada A | Pasada B |
|---|---:|---:|
| Primera casta | 7,3 | 7,5 |
| Mandíbulas 4 | 15,0 | 17,4 |
| Madera | 36,9 | 41,9 |
| Resistentes | 50,0 | 69,2 |
| Muros | 55,8 | 74,7 |
| Casa conquistada | 61,7 | 89,7 |
| Restaurante → fundación 1 | 67,7 | 93,0 |
| Museo → fundación 2 | 91,2 | 124,2 |
| Obelisco | 111,3 | 146,4 |
| Coliseo | 114,0 | 150,6 |
| Torre Eiffel | 117,9 | ~173 |

Lo que muestran las dos pasadas:

- **La primera casa es casi todo el juego.** En la pasada A, 47 de las 70
  expediciones son de la primera casa. Antes de la madera, una expedición deja
  entre 5 y 370 migas. Las tres primeras dejan 5 migas cada una.
- **Con los materiales la economía explota.** Por expedición: 264K, 786K,
  3,3M, 18M, 30M, 449M y 6,7B. La meta de la casa (4,75M) se pasa en tres
  expediciones. El restaurante cae en dos.
- **Desde la segunda colonia, cada destino dura una expedición.** El
  restaurante, el museo, el Obelisco, el Coliseo y la Torre Eiffel caen en una
  sola vuelta cada uno. Al final se cobran 197Qa por expedición.
- **Por qué pasa:** el multiplicador de migas y el daño se apilan de forma
  multiplicativa entre ramas. Eso da ~1,6·10⁵ en migas, y varios ×16 en daño
  (Acero, Titanio, Legión). En cambio, el `factor` de los destinos crece de 1
  a 11 y la `vida_meta` no acompaña. Los topes de nivel dejan los costos
  fijos mientras el ingreso sigue creciendo, así que al final el bot compró
  casi todo al máximo.
- **El llamado base era de 24.** Con 24 alcanzaba a toda la colonia de la
  primera casa (≤ 24 hormigas hasta el minuto ~55). Por eso Llamado potente,
  la primera mejora sin requisitos, y Coordinación no hacían nada en esa
  etapa. Además, con las dos al máximo se llegaba a 79 y el tope es 64: los
  últimos 15 niveles de Coordinación no hacían nada. Ahora el base es 8: el
  máximo da 63, y cada nivel cuenta desde la primera expedición. La pasada de
  control llegó a la madera en el minuto 38,7, dentro del ruido.

### Rebalance de la campaña (30/10, noche)

Pedido: que el principio cueste, que después se sienta el despegue y que el
resto del juego no caiga en dos expediciones. Se probaron 17 variantes con el
bot (dos en paralelo). Esto es lo que quedó.

**Arranque.** La madera cuesta 700 (antes 1800) y pide Mandíbulas 3 (antes 4).
La gran mesa de la casa baja de 1000 a 600 de `vida_meta`. Con 1000, la colonia
podía trabarse varias expediciones después de comprar los muros: una pasada
fundó con 3 de jalea y su segunda colonia tardó 30 minutos en volver. Sólo
abaratar la madera (1100) no movía nada, porque el bot llega a ahorrar recién
cuando lo más barato cuesta lo mismo que una expedición. Bajar el crecimiento
de precios de las mejoras básicas tampoco cambió la madera.

**Bola de nieve.** Se moderaron los multiplicadores más fuertes: Recolección
eficiente ×1,15 → ×1,12, Huevos dorados ×1,5 → ×1,4, Acero ×1,5 → ×1,4,
Titanio ×2 → ×1,75, Legión ×1,6 → ×1,45, Haute cuisine ×2 → ×1,75 y Corazón
×1,5 → ×1,4. Con la mitad de ese recorte (×1,10, ×1,3, ×1,5…) el restaurante
quedaba imposible y la colonia fundaba con 9 de jalea. Con este, el ingreso del
restaurante pasa de ~10B a 0,3–2B por expedición y crece por precio, no de un
salto.

**Grandes objetivos** (`vida_meta`): restaurante 1500 (igual), museo
950 → 28.500, Obelisco 7.200 → 600.000, Coliseo 2,3e5 → 1,5e8 y Torre Eiffel
4,8e7 → 1,2e10. Las memorias de la reina bajan: metal 10 → 5 y piedra
30 → 12. Así la segunda y la tercera vuelta a la casa duran 4 y 1–2
expediciones.

**El bot.** Ahora ataca el gran objetivo sólo cuando estima que lo puede tirar
(ver README). Antes atacaba siempre: como el mapa se repone, se quedaba sin
ingresos y fundaba trabado. El modo de calibración por runs (`BOT_RUNS_DESTINO`)
quedó, pero con los bocados de la versión 5 sobreestima: un objetivo
invulnerable no suelta trozos y las hormigas muerden sin volver. Por eso los
valores se ajustaron a mano.

| Hito (minutos de bot) | Antes (A / B) | Ahora (f4 / f3) |
|---|---:|---:|
| Madera | 36,9 / 41,9 | 18,8 / 18,6 |
| Casa | 61,7 / 89,7 | 50,1 / 52,4 |
| Restaurante | 67,7 / 93,0 | 59,2 / 65,0 |
| Museo | 91,2 / 124,2 | 107,8 / 96,0 |
| Obelisco | 111,3 / 146,4 | 114,6 / 119,2 |
| Coliseo | 114,0 / 150,6 | 139,8 / 149,3 |
| Torre Eiffel | 117,9 / ~173 | 152,6 / 166,7* |

\* La pasada f3 se midió con 1,5e10. En el minuto 166,7 le hizo a la Torre
15,5Qa de 15,6Qa, se quedó a un 0,6% y fundó una cuarta vez. Por eso quedó
1,2e10 (12,5Qa): con ese valor cae en esa expedición, y f4 también la tira.

Expediciones en cada destino nuevo, contando todas las colonias hasta tirarlo:
restaurante 3–4, museo 3–5, Obelisco 2, Coliseo 3–4 (con una fundación en el
medio) y Torre Eiffel 3 o más. Antes era 1 en cada uno desde el museo. El bot
funda 3 veces: al llegar al restaurante, al museo y al trabarse en el Coliseo.

Pendiente:

- **La primera vuelta a la casa sigue larga:** 10–11 expediciones, unos 18
  minutos. Con 5 de jalea por corona y Reservas a 2 bajaba, pero rompe el
  diseño del primer retorno (7 de jalea, Cuadrilla 6) que cubren
  `prueba_primer_retorno` y `prueba_preparacion_fundar`. Queda para hablarlo.
- **La Torre Eiffel pide una colonia con ~300–400 de legado.** Cerca de
  1,2e10 se decide por pocas expediciones: si una colonia queda corta,
  funda una cuarta vez (unos 15–20 minutos más).
- **Desde el Obelisco el ingreso se despega del daño:** hay expediciones de
  Sx, pero el daño al objetivo sigue en Qa. La jalea por migas (raíz cuarta)
  sigue el ingreso y la cuarta fundación puede dar decenas de miles.

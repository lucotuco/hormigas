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
- **Restaurante.** Es donde se pretende enseñar la primera fundación. Hay que mirar con gente
  real si se entiende que conviene fundar o si parece que el juego se trabó.

### Eventos incorporados desde main


Con la misma comida y los muebles de la casa reacomodados, los destinos se
sentían iguales (es la queja más común contra Idle Ants, el juego de celular
con la misma idea). Ahora cada destino trae tres comidas propias y una amenaza
con su propia regla. Las amenazas cumplen dos funciones:

- **Una decisión en la run.** Clickear la amenaza o seguir pisando comida. La
  pisada automática no las resuelve, así que el jugador que mira la pantalla
  gana más que el que la deja sola.
- **Riesgo en un género tranquilo.** Perder hormigas o una comida grande duele
  un poco, pero vencerlas paga un botín (12% de lo juntado en la run, o lo que
  la amenaza se había llevado ×1,5).

La miga dorada es el estímulo corto clásico de los incrementales (la galleta
dorada de Cookie Clicker): aparece cerca de lo que se mira y dura 9 s.

## Qué se puede tocar sin programar

- `datos/mejoras.csv`: columnas nuevas `destino`, `tope_por_destino`,
  `elevable` (le afecta Cámaras más hondas), `bonus_cada`, `bonus_mult`.
- `datos/jalea.csv`: el árbol de la reina. Los nodos con `efecto = stat`
  funcionan como mejoras (stat, tipo, valor); el resto tiene un efecto
  especial programado en `Juego` (ver `EFECTOS_JALEA`).
- `mundo/mundos.gd`: `vida_meta` y `coronas` de cada destino.
- `Juego.JALEA_POR_CORONA`, `Juego.DIVISOR_JALEA_MIGAS`, `Juego.BONUS_LEGADO`.

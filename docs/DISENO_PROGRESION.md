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
  su stat cada N niveles: Mandíbulas fuertes y Pisotón duplican el daño
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

Una mejora barata del taller (Pisada automática, desde Pisotón 2) suma 0,5
pisotones por segundo sobre la comida más cercana al cursor, hasta 3 por
segundo. Así, horas de clic seguido no son obligatorias: clickear suma, pero
el juego avanza igual. La Guardia de la reina hace lo mismo desde el comienzo de
cada colonia.

### 3. Destinos

Cada gran objetivo es un chequeo de daño **dentro de una sola run** (la casa se
reconstruye en cada expedición). Su resistencia (`vida_meta` en `mundo/mundos.gd`)
está calibrada para que a partir del restaurante haga falta fundar al menos
una vez. El ritmo lo marca el ciclo **conquistar → fundar → volver más fuerte**.

### 4. Destinos con identidad

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

## Ritmo (jugador activo, medido con el bot)

| Hito | Buscado | Medido | Fundaciones |
|---|---|---|---|
| Madera | ~10 min | ~10 min | — |
| Casa conquistada (sin fundar) | ~50 min | ~45 min | 0 |
| Restaurante | 1,5–3 h | ~3,5 h | 2 |
| Museo | — | ~4,75 h | 4 |
| Obelisco | — | ~6,5 h | 8 |
| Coliseo | — | ~7,8 h | 10 |
| Torre Eiffel | 10–20 h | ~10,7 h | 12 |

Un jugador real pisa menos que el bot (3 por segundo) y no compra perfecto,
así que la campaña real debería estar más cerca de 12–15 h.

La medición completa está en el README (sección del bot de balance) y se rehace
con `tests/bot_balance.tscn`, que también funda y compra jalea.

## Preguntas abiertas

- **El final se estira.** Del Coliseo a la Torre Eiffel van casi 3 h (dos
  colonias, de 90 y 45 minutos), contra 17–25 minutos por colonia en el Obelisco. La jalea crece rápido, pero el
  bonus de legado es aditivo (+3% por punto) y ya no hay destino nuevo que
  suba topes. Si se siente pesado: una mejora de destino propia de la Torre
  que multiplique, o un hito del árbol que escale con la jalea gastada.
- **¿El árbol tiene decisiones?** El bot compra siempre lo más barato y llega
  igual. Conviene probar si un jugador que prioriza poder sobre atajos
  termina mucho antes; si no hay diferencia, el árbol es una lista de
  compras y no una elección.
- **Restaurante.** Pide la primera fundación pasada la hora y media; es el
  momento en que el jugador aprende la capa nueva. Hay que mirar con gente
  real si se entiende que conviene fundar o si parece que el juego se trabó.

## Qué se puede tocar sin programar

- `datos/mejoras.csv`: columnas nuevas `destino`, `tope_por_destino`,
  `elevable` (le afecta Cámaras más hondas), `bonus_cada`, `bonus_mult`.
- `datos/jalea.csv`: el árbol de la reina. Los nodos con `efecto = stat`
  funcionan como mejoras (stat, tipo, valor); el resto tiene un efecto
  especial programado en `Juego` (ver `EFECTOS_JALEA`).
- `mundo/mundos.gd`: `vida_meta` y `coronas` de cada destino.
- `Juego.JALEA_POR_CORONA`, `Juego.DIVISOR_JALEA_MIGAS`, `Juego.BONUS_LEGADO`.

# Tareas

Reparto propuesto:

- **A — Hormigas:** todo lo que se mueve. Carpeta `hormigas/` y `mundo/feromonas.gd`.
- **B — Mundo y meta-juego:** el mapa, la comida, la interfaz, el balance y el guardado. Carpetas `mundo/` (salvo feromonas), `ui/`, `datos/`, `global/`.
- `mundo/run.gd` es compartido: avisen antes de tocarlo.

Pueden copiar esta lista a un tablero de GitHub Projects.

---

## Paso 1 — Prototipo

- [x] Hormigas que salen del hormiguero y exploran
- [x] Llamado al mantener clic: se acercan las hormigas disponibles más cercanas, sin rastros
- [x] Comida con vida que se agrieta al morderla
- [x] Las hormigas llevan la comida al hormiguero y vuelven a la misma comida (filas de hormigas)
- [x] Contador de migas
- [ ] **Los dos:** jugar y ajustar hasta que guiar hormigas sea divertido (velocidad, olfato, cuántas responden al llamado)

## Paso 2 — Loop completo

- [x] Temporizador por run
- [x] Panel de fin de run
- [x] Tienda con árbol de mejoras (18 mejoras en 6 ramas, las bloqueadas en sombra)
- [x] Comprar mejoras y castas en cantidades ×1, ×10 o Máx, con indicadores de disponibilidad por rama
- [x] Guardado y carga automáticos
- [x] Clic exclusivamente para llamar; compras de Pisotón migradas a daño de hormigas sin perder niveles
- [x] Mecánicas que aparecen de a una (frenesí, castas, prioridades, viajes, legado)
- [x] Próxima meta siempre visible en el HUD, con barra y aviso cuando alcanza
- [x] Hormigas más grandes en pantalla y 8 obreras iniciales
- [x] Menú principal, pausa con Esc, configuración (idioma, volumen, pantalla completa, temblor) y estadísticas
- [x] Todo el juego en español e inglés (idiomas/en.po)

## Paso 3 — El jugo

- [x] Números flotantes, partículas, onda expansiva al destruir comida
- [x] Migas que vuelan hasta el contador
- [x] Cámara que tiembla según el tamaño de lo destruido
- [x] Sonido de depósito que sube de tono con el combo
- [x] Cámara lenta al terminar la run, cuenta regresiva con tic
- [x] **A:** patas animadas y llegada estable, sin orbitar objetivos
- [x] **B:** efectos suaves y armónicos con control de volumen (síntesis procedural)
- [ ] **B:** explorar arte y audio grabado según la dirección artística final
- [ ] **B:** música de fondo
- [ ] **B:** sprites para las comidas

## Paso 4 — El mapa que se expande

- [x] Territorio circular con niebla; lo de afuera se ve en sombra
- [x] La cámara se aleja cuando crece el territorio, con animación al empezar la run
- [x] Comida más grande y valiosa cuanto más lejos
- [x] **B:** muebles, paredes y puertas con navegación compartida y rutas distintas para voladoras
- [x] **B:** siete ambientes con identidad y muebles: cocina, comedor, living, pasillo, dormitorio, estudio y baño/lavadero
- [x] **B:** gran banquete fijo sobre un plato para descubrir al explorar
- [x] **B:** zoom con rueda, desplazamiento libre, retorno al hormiguero y vista de la casa completa
- [x] **A:** atracción al punto mantenido, selección por cercanía y cancelación al soltar
- [x] **A:** clic sólo para dar órdenes; antiguo Pisotón convertido a Coordinación sin perder niveles
- [x] **B:** progresión por materiales: alimentos → madera/telas → resistentes → paredes
- [x] **A+B:** devorar muebles y muros desde sus bordes; destrucción que libera colisiones y abre atajos
- [x] **A+B:** recortes localizados, soportes y derrumbes por etapas, con fragmentos agrupados y transportables
- [x] **B:** comida escondida en muebles y frenesí por depósitos

## Paso 5 — Contenido

- [x] **A:** siete castas con roles, carpintera y demoledora, corrosión compartida y prioridades de trabajo
- [x] **A:** evolución visual de mandíbulas, abdomen y corona de la reina
- [x] **A:** cuatro evoluciones de comportamiento; dos equipadas gratuitamente y conservadas al fundar
- [x] **A:** puestos de trabajo, hallazgos compartidos y continuidad del llamado sobre huecos
- [x] **A:** exploración por sectores, destinos estables y prueba de dispersión sin feromonas con 500 hormigas
- [x] **B:** banquito inicial y seis reglas de destino con procesos acotados
- [ ] **A:** castas de combate y vuelo hacia superficies elevadas
- [x] Una amenaza por destino: araña, mozo, aspiradora, palomas, gato y rata (mundo/eventos.gd)
- [x] Comidas propias en cada destino y miga dorada
- [ ] **A:** humano con insecticida (¿amenaza de la casa avanzada?)
- [x] **A:** atlas compartido, búsqueda espacial, navegación incremental y benchmark gráfico con 5/150/500 hormigas
- [x] **A:** cola justa de rutas con prioridad manual, caché de fallos, giros comprimidos y prueba de cursor móvil con 500 hormigas
- [ ] **Los dos:** probar rendimiento en otras PCs y balancear los tiempos de desbloqueo y resistencia de materiales
- [x] **B:** prestigio con confirmación (fundar colonia → legado; conserva destinos e hitos)
- [x] **B:** hitos opcionales con premios permanentes explícitos
- [x] **B:** seis destinos con objetivos: casa, restaurante, museo, Obelisco, Coliseo y Torre Eiffel
- [x] **B:** árbol de mejoras como hormiguero en corte con seis cámaras interactivas
- [x] Bot de balance con paso 1/60 y tiempo ×1; piloto final con retirada: madera 7,3 min, paredes/casa 33,1, restaurante 38,2; comparación controlada de castas (ver limitaciones en diseño)
- [x] Puestos de trabajo estables durante el acercamiento; regresos alternativos si una entrada queda aislada
- [x] Hasta seis entradas secundarias por destino, sin simulación subterránea y con navegación compartida
- [x] Retirada acotada, desglose de ingresos y récords por destino persistentes
- [x] Seis adaptaciones permanentes de viaje y vista previa de compras con jalea
- [x] Piso menos contrastado, alimentos agrupados, señales de escondites y habilidades con efectos acotados
- [x] Regresiones de logística y benchmark de 500 hormigas en los seis destinos
- [ ] Recalibrar la campaña tardía: los tiempos anteriores con tiempo ×8 y daño por clic ya no son válidos
- [x] Progresión larga: jalea real y árbol de la reina, topes por destino, mejoras de cada viaje, hitos cada 25 niveles (docs/DISENO_PROGRESION.md)
- [x] Tope de 500 hormigas y runs de hasta ~3,5 min
- [x] Decretos de la reina: al fundar se elige uno de cuatro (numerosa, guerrera, recolectora, exploradora)
- [x] Pisada automática temprana (y la Guardia de la reina la da desde el comienzo de cada colonia)
- [ ] **Los dos:** jugar varias colonias y ver si los decretos se sienten distintos
- [x] Campaña más corta: ~3 h 53 min de bot (4,5–5,5 h para una persona), una fundación por destino desde el museo
- [ ] **B:** pasar los CSV a una planilla compartida

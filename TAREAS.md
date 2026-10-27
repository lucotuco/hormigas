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
- [x] Pisotón: el clic sobre comida pega al instante; mantenerlo sigue llamando hormigas
- [x] Mecánicas que aparecen de a una (frenesí, castas, prioridades, viajes, legado)
- [x] Próxima meta siempre visible en el HUD, con barra y aviso cuando alcanza
- [x] Hormigas más grandes en pantalla y 8 obreras iniciales
- [ ] **B:** pantalla de título
- [ ] **B:** menú de pausa con volumen

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
- [ ] **A:** castas de combate y vuelo hacia superficies elevadas
- [ ] **A:** enemigos: araña que caza hormigas sueltas, humano con insecticida
- [x] **A:** atlas compartido, búsqueda espacial, navegación incremental y benchmark gráfico con 5/150/500 hormigas
- [x] **A:** cola justa de rutas con prioridad manual, caché de fallos, giros comprimidos y prueba de cursor móvil con 500 hormigas
- [ ] **Los dos:** probar rendimiento en otras PCs y balancear los tiempos de desbloqueo y resistencia de materiales
- [x] **B:** prestigio con confirmación (fundar colonia → legado; conserva destinos e hitos)
- [x] **B:** hitos opcionales con premios permanentes explícitos
- [x] **B:** seis destinos con objetivos: casa, restaurante, museo, Obelisco, Coliseo y Torre Eiffel
- [x] **B:** árbol de mejoras como hormiguero en corte con seis cámaras interactivas
- [x] Bot de balance (tests/bot_balance.tscn) y primera hora calibrada: madera ~10 min, paredes ~42, casa ~50
- [ ] **Los dos:** decidir cómo progresan los destinos 2 a 6: hoy todo se maximiza antes del minuto 60 y cada destino cae en una run
- [ ] **B:** pasar los CSV a una planilla compartida

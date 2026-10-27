# Tareas

Reparto propuesto:

- **A — Hormigas:** todo lo que se mueve. Carpeta `hormigas/` y `mundo/feromonas.gd`.
- **B — Mundo y meta-juego:** el mapa, la comida, la interfaz, el balance y el guardado. Carpetas `mundo/` (salvo feromonas), `ui/`, `datos/`, `global/`.
- `mundo/run.gd` es compartido: avisen antes de tocarlo.

Pueden copiar esta lista a un tablero de GitHub Projects.

---

## Paso 1 — Prototipo

- [x] Hormigas que salen del hormiguero y exploran
- [x] Rastro de feromonas con el mouse que las hormigas siguen
- [x] Comida con vida que se agrieta al morderla
- [x] Las hormigas llevan la comida al hormiguero y vuelven a la misma comida (filas de hormigas)
- [x] Contador de migas
- [ ] **Los dos:** jugar y ajustar hasta que guiar hormigas sea divertido (velocidad, olfato, cuánto dura el rastro)

## Paso 2 — Loop completo

- [x] Temporizador por run
- [x] Panel de fin de run
- [x] Tienda con árbol de mejoras (15 mejoras en 6 ramas, las bloqueadas en sombra)
- [x] Guardado y carga automáticos
- [ ] **B:** pantalla de título
- [ ] **B:** menú de pausa con volumen

## Paso 3 — El jugo

- [x] Números flotantes, partículas, onda expansiva al destruir comida
- [x] Migas que vuelan hasta el contador
- [x] Cámara que tiembla según el tamaño de lo destruido
- [x] Sonido de depósito que sube de tono con el combo
- [x] Cámara lenta al terminar la run, cuenta regresiva con tic
- [ ] **A:** hormiga en pixel art con patas animadas
- [ ] **B:** reemplazar los sonidos generados por sonidos de verdad
- [ ] **B:** música de fondo
- [ ] **B:** sprites para las comidas

## Paso 4 — El mapa que se expande

- [x] Territorio circular con niebla; lo de afuera se ve en sombra
- [x] La cámara se aleja cuando crece el territorio, con animación al empezar la run
- [x] Comida más grande y valiosa cuanto más lejos
- [ ] **B:** muebles y obstáculos (patas de mesa, la heladera) que las hormigas rodean
- [ ] **B:** zonas con identidad: debajo de la mesada → cocina → living
- [ ] **B:** la meta visible: algo enorme en el fondo del mapa desde el primer segundo

## Paso 5 — Contenido

- [ ] **A:** castas: soldados (pelean), cargadoras (llevan más), voladoras (llegan a la mesada)
- [ ] **A:** enemigos: araña que caza hormigas sueltas, humano con insecticida
- [ ] **A:** rendimiento: probar con 500 hormigas; si se pone lento, dibujarlas todas desde un solo nodo o con MultiMesh
- [ ] **B:** prestigio con la reina (fundar nueva colonia → bonus permanentes)
- [ ] **B:** árbol de mejoras dibujado como hormiguero en corte
- [ ] **B:** pasar los CSV a una planilla compartida y balancear la primera hora de juego

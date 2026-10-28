# Tareas

## Hormiguero, viajes y archivo — 28/10

- [x] Volver a casa al fundar y reabrir viajes en orden por colonia; preservar descubrimientos, adaptaciones, topes e hitos históricos.
- [x] Árbol de pantalla completa: 31 cámaras individuales en seis ramas, túneles por requisitos y cuatro secciones integradas.
- [x] Desarrollo visual del hormiguero por compras y ficha contextual, sin reconstruir la interfaz por cuadro.
- [x] Poblar los seis mapas y sumar objetos característicos de Buenos Aires, Roma y París con atlas/perfiles compartidos.
- [x] Cierre automático al consumir lo disponible, sin ignorar fragmentos, derrumbes, tesoros ni botín recuperable.
- [x] Archivo paginado de tiempos, mejores marcas por contexto y exportación JSON; compatible con partidas anteriores.
- [ ] Validar con personas el ritmo de reconquista tras fundar y la lectura del árbol completo; no confundir una prueba automática corta con balance de campaña.

## Prioridad de producto y dirección visual — 28/10

Promesa: empezar juntando migas y terminar viendo una colonia devorar lugares
reconocibles. Mantener crecimiento incremental y automatización útil. La casa
cenital ilustrada es la referencia de paleta, materiales, escala y luz para
evitar una mezcla de imágenes con estilos incompatibles.

- [x] Recuperar trabajo cercano cuando el llamado queda sobre suelo/comida agotada; no reservar muebles que ya caen.
- [x] Conservar puestos de trabajo hasta cambiar de objetivo o SU geometría, no por cualquier rotura del mapa.
- [x] Primera silla de madera accesible, premio proporcional y paso contextual con botón para encontrarla.
- [x] Separar los hitos de silla de madera del banquito de cartón inicial; conservar premios ya guardados.
- [x] Mostrar compañeros, utilidad y limitaciones en fichas de castas, sin sinergias numéricas inventadas.
- [x] Mostrar el arranque real de la próxima colonia al elegir decreto, sin simular compras futuras.
- [x] Unificar mobiliario doméstico, textiles y repostería en dibujo cenital horneado; audio más corto y amortiguado.
- [x] Avisos de amenazas con contexto y acción Ver; clic de cámara separado del llamado.
- [ ] Probar la primera media hora con 5–10 personas que no conozcan el juego; observar sin explicarles los controles.
- [ ] Medir equipos/decretos distintos con personas; una prueba de carpintera+cargadora no valida todas las combinaciones.
- [ ] Validar primera fundación y campaña tardía con el balance integrado, sin reutilizar duraciones antiguas.
- [ ] Probar GPU integrada y sesiones largas con alt-tab/capturas; conservar topes y presupuestos actuales.
- [ ] Preparar demo y presentación de Steam después de validar ese recorrido; definir cierre de campaña y audio final.

## Integración y estética — 28/10

- [x] Integrar menú, idiomas, eventos y decretos de main sin perder IA ni logística; publicar en main sin sobrescribir historial.
- [x] Renovar mobiliario, materiales de piso, textiles y luz estática en el atlas compartido.
- [x] Respetar color/orientación/acabado de cada mueble; deduplicar instancias del atlas.
- [x] Bancos en la plaza, cartón reconocible en el tutorial, arena y césped sin baldosas.
- [x] Mantener la comida en su ambiente también al agruparla junto a muebles.
- [x] Verificar 18 suites, capturas de ambientes y rendimiento de los seis destinos con 500 hormigas.

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
- [x] Tienda con árbol de mejoras (31 mejoras en 6 ramas, las bloqueadas en sombra)
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
- [x] **B:** prestigio con confirmación (fundar colonia → legado; vuelve a casa y conserva descubrimientos e hitos)
- [x] **B:** hitos opcionales con premios permanentes explícitos
- [x] **B:** seis destinos con objetivos: casa, restaurante, museo, Obelisco, Coliseo y Torre Eiffel
- [x] **B:** árbol de mejoras como hormiguero de pantalla completa, con cámaras subdivididas y desarrollo visual
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
- [ ] Volver a medir duración total: las antiguas 3 h 53 min de bot y estimaciones humanas no validan el balance integrado actual.
- [ ] **B:** pasar los CSV a una planilla compartida

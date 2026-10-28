# Arte preiluminado

## Uso actual tras la unificación cenital (28/10)

El mobiliario doméstico, plantas, cerámica, textiles y repostería ahora se
dibujan por código en `mundo/dibujo_casa.gd` / `global/graficos.gd`, horneados
una sola vez en el atlas compartido. Los originales de muebles/detalles se
conservan para trazabilidad y revisión de perfiles; se cargan sólo al
consultarlos, no al iniciar una partida. Los monumentos conservan la hoja de
destinos y el suelo usa materiales con relieve atenuado. No se generaron
imágenes nuevas para esta revisión. El registro de abajo describe la primera
incorporación, no la lista actual de regiones dibujadas.

## Registro de la primera incorporación

Generado con la herramienta integrada `image_gen` el 2026-10-28. Los originales se copiaron al proyecto sin editar. Muebles, materiales y destinos: 1254 × 1254 cada uno. Detalles: 1536 × 1024. Los recortes se definen en `mundo/arte_casa.gd`; los muebles se hornean en el atlas compartido una sola vez. Los pisos usan un único muestreo filtrado con mipmaps. No hay luces 3D ni física adicional.

La hoja de detalles no entregó transparencia utilizable: sólo se usan regiones rectangulares interiores de las alfombras, lavabo y cartón, nunca su fondo ni la estatua. Los intentos de extracción y estatua individual fueron descartados y no se incluyen como dependencias del juego.

## Detalles

```text
One production game sprite sheet, 3 columns by 2 rows, exactly six isolated objects, transparent background. Landscape canvas 1536x1024. One complete object inside each equal cell with transparent padding, no object crossing cell boundaries. Top row left to right: 1) rectangular antique Persian woven rug, faded terracotta, muted cream and sage floral border, realistic fine wool fibers and short tassels, overhead 90 degree flat view. 2) rectangular natural oatmeal linen rug with subtle woven geometric border, overhead flat view. 3) rectangular slate blue gray woven wool bedroom rug, subtle cream stitched border, overhead flat view. Bottom row left to right: 4) horizontal white ceramic bathroom washbasin with silver faucet on pale sage vanity, top-down overhead view, NO floor or wall; 5) classical ivory marble female statue on a square stone pedestal, full height, softly elevated frontal orthographic view, no backdrop; 6) small closed brown cardboard carton, packing tape across top, slightly crushed corner, top-down view, no lettering. Realistic 3D-rendered tactile materials, warm natural upper-left light, restrained elegant color palette, softly baked ambient occlusion and contact shadows. NOT flat vector shapes, NOT pixel art, no text, no watermarks. These are sprites for a realistic miniature home game. Rugs must be rectangular axis aligned with no perspective distortion. Each isolated silhouette completely transparent outside object.
```

## Muebles

```text
Production game sprite sheet, 4 columns by 4 rows, exactly 16 isolated objects on genuinely transparent background, square 2048x2048 canvas. Each object centered in its equal 512x512 cell with at least 40 pixels empty padding, no grid lines or labels. Strict orthographic overhead 90 degree top-down camera, NOT isometric, all rectangular edges parallel to image edges. Realistic lovingly art-directed miniature home furniture, photorealistic materials with wood grain, fabric weave, soft rounded bevels, ambient occlusion and subtle baked soft contact shadow below-right. Warm natural daylight upper-left, restrained warm oak, sage upholstery, ivory ceramics. Rich tactile realistic 3D-rendered look, NOT flat vectors, NOT pixel art. Row1 left-right: (1) horizontal oak dining table with four ivory plates and small centerpiece, no chairs (2) horizontal sage three-seat fabric sofa with cushions and back at top (3) double bed with blue-gray quilt, two cream pillows and wood headboard at top (4) horizontal wooden desk with laptop, notebook and small lamp. Row2: (5) individual square wooden dining chair with sage seat and back at top (6) lush green potted plant in terracotta round pot, overhead foliage (7) horizontal oak coffee table with book and ceramic mug (8) horizontal freestanding white bathtub with pale blue interior and silver faucet. Row3: (9) horizontal pale stone kitchen counter with inset stainless sink and faucet (10) horizontal white cooker with four black gas burners (11) horizontal oak bookshelf filled with varied muted books seen from overhead with slight front lip (12) horizontal oak park bench with visible weathered wood slats and dark metal frame, no background. Row4: (13) small ivory bathroom toilet with cistern at top (14) square washing machine white with circular top-loading glass lid (15) sage upholstered single armchair with cream pillow, back at top (16) horizontal kitchen worktop with pale stone surface, cutting board, knife, vegetables and jar. Every object wholly inside its own cell, clear silhouettes, consistent light and scale within each cell, no attached floors or rooms, no people, no text, no watermarks.
```

## Materiales

```text
Production game environment MATERIAL TEXTURE ATLAS, square image, four equal square quadrants filling the entire canvas edge to edge with no padding, no labels, no borders. Top left quadrant: warm ivory limestone kitchen floor, large square stone tiles, subtle porous natural mottling and narrow warm gray grout, 4 by 4 tiles. Top right quadrant: warm medium honey oak plank floor with authentic detailed natural wood grain and gently worn satin finish, horizontal staggered long boards, 8 rows. Bottom left: pale celadon sage bathroom square ceramic tile floor with delicate glaze, 8 by 8 tiles, thin grout. Bottom right: outdoor warm pale gray limestone pavement, subtly varied cut stone square slabs 4 by 4, slightly weathered. Strict 90 degree overhead flat orthographic photorealistic surface scan, no objects, no furniture, no directional shadows, even diffuse light. Restrained natural contrast, absolutely no dark dirty stains. Each quadrant is a seamless repeating material with matching edges. Realistic high quality materials for an elegant miniature home game, not vector art, not pixel art. No text, no watermarks.
```

## Destinos y mobiliario complementario

```text
Production game sprite sheet on genuinely transparent background. Exactly 9 separate sprites, regular 3 columns by 3 rows, square canvas 1536x1536. One sprite centered in each equal square cell with clear empty padding, no borders or labels, nothing crosses cells. Rich realistic miniature diorama 3D-rendered materials, tactile natural wood, cream limestone, bronze iron, ambient occlusion, subtle soft contact shadows cast below-right, light from upper left. Rows left to right: Row1 (1) iconic Buenos Aires obelisk, elegant tall slender warm ivory stone tapering shaft with pyramidal point and tiny dark door at bottom, upright front elevation with slight visible right side, NOT a generic square pillar (2) recognizable full Eiffel tower, intricate brown iron lattice with four splayed feet and arch, entire height visible, frontal very slightly elevated orthographic view (3) weathered Roman stone arch ruin, double arch with thick travertine pillars and layered cornice. Row2 (4) overhead top-down wooden wardrobe cupboard with natural oak surfaces, double doors and brass handles visible on short front lip (5) overhead top-down ivory refrigerator with rounded corners, handles and slight front face (6) overhead top-down long low walnut television console with a black flat screen rising along its back edge. Row3 (7) overhead top-down horizontal oak sideboard cabinet with paneled doors and subtle brass fittings (8) overhead top-down square bedside table with small cream lampshade and book (9) overhead slightly elevated view of a museum glass display case on a walnut plinth containing a small ivory classical bust. Objects aligned to canvas axes, no isometric rotation. Baked realistic dimensional lighting, not vectors, not flat icons, not pixel art. All transparent isolated cutouts, no floor, no ground plane, no extra scenery, no text or watermark. The furniture belongs in a warm sage and oak home game; monuments belong to its travel maps.
```

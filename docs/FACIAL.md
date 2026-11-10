# Reconocimiento facial para marcar asistencia

Estado: **fase 1 implementada en el backend** (consentimiento, enrolamiento y PIN). Pendiente: comparación facial (fase 2) y app Flutter.

**Decisiones tomadas:**
- Motor en el dispositivo (ML Kit + TFLite); el rostro no sale del teléfono.
- Prueba de vida activa (gesto aleatorio).
- Respaldo: PIN personal del empleado (método `pin`). Hay que crear esta función (hoy no existe).

Decidido: **solo embeddings, sin fotos de evidencia**, ni siquiera temporales.

El rostro es un dato biométrico sensible (Ley 29733 de Perú). Antes de activarlo en producción hace falta consentimiento expreso, inscripción del banco de datos ante la ANPD y revisión legal.

## Objetivo

Confirmar que quien marca es el empleado registrado, sin que el rostro sea una contraseña que se pueda robar, y con un método alternativo siempre disponible.

## Flujos

### Enrolamiento (una vez por empleado)

1. El empleado da su consentimiento en la app (texto claro, finalidad, derechos ARCO, plazo de conservación).
2. La app toma 3 a 5 capturas guiadas (de frente, con leve giro) y pasa la prueba de vida.
3. La app calcula un **embedding** (vector numérico de ~128–512 valores) por captura y lo envía al backend. La foto no sale del teléfono.
4. El backend guarda el embedding **cifrado** (AES-256-GCM, clave en variable de entorno o gestor de secretos) y la fecha de consentimiento.

### Marcación

1. La app abre la cámara frontal, detecta el rostro y ejecuta la prueba de vida.
2. Calcula el embedding en el dispositivo.
3. Envía `POST /attendance` con `method: "face"` y el embedding (nunca la imagen).
4. El backend compara por similitud coseno contra las plantillas del empleado. Si supera el umbral, registra la marcación; si no, responde `403` con la opción de método alternativo.

## Motor de reconocimiento (decidido: en el dispositivo)

| Opción | Cómo | Pros | Contras |
|---|---|---|---|
| **A. En el dispositivo** (recomendada) | ML Kit para detectar rostro y puntos; modelo de embeddings (MobileFaceNet/ArcFace) en TFLite | Imagen y rostro no salen del teléfono; sin costo por uso; funciona offline | Más trabajo de integración; precisión depende del teléfono y la luz |
| **B. Servicio gestionado** (AWS Rekognition, Azure Face) | La app envía la imagen; el servicio compara | Más preciso y rápido de integrar; liveness incluido en algunos | Las imágenes salen del país (exige evaluación bajo la Ley 29733); costo por uso |

**Recomiendo A**: minimiza datos biométricos fuera del teléfono. La precisión se valida en piloto con empleados reales.

## Prueba de vida (decidido: activa)

Sin prueba de vida, una foto impresa o una pantalla pueden engañar al sistema.

- **Activa** (recomendada): pedir un gesto aleatorio (parpadear o girar la cabeza). ML Kit entrega probabilidad de ojos abiertos y ángulos de la cabeza. Barata y eficaz contra fotos; no detiene un video grabado de antemano.
- **Pasiva** (modelo anti-spoofing): más robusta, requiere otro modelo y más pruebas.

## Backend

Implementado en `backend/src/face/`: `FaceStore` (puerto), adaptadores TypeORM y Turso, cifrado AES-256-GCM y endpoints `/face/*` (ver [API.md](API.md)).

Variables nuevas: `FACE_ENCRYPTION_KEY` (obligatoria para inscribirse) y `FACE_EMBEDDING_DIM` (128 por defecto).

- Nuevo puerto `FaceTemplateStore` (`employeeId`, `embeddingEncrypted`, `consentAt`, `createdAt`), con adaptador Turso y TypeORM como el resto.
- `AttendanceMethod` ya incluye `'face'`; la marcación lo registra.
- Umbral configurable (`FACE_MATCH_THRESHOLD`) y registro de intentos fallidos (sin imagen).
- Endpoints propuestos:
  - `POST /face/enroll`: guarda plantillas (solo el propio empleado, con consentimiento).
  - `DELETE /face/enroll`: el empleado borra sus plantillas (derecho de cancelación).
  - `POST /attendance` con `method: "face"` y `embedding`.

## Fallback (decidido: PIN)

Siempre debe existir un método alternativo. Decidido: PIN personal del empleado, registrado como método `pin`. Requiere: crear el PIN al enrolarse, guardarlo con hash (bcrypt, como las claves) y limitar intentos fallidos. La solicitud manual a RRHH (`manual`) queda como respaldo del respaldo.

## Privacidad y retención

- **Sin fotos.** Solo embeddings cifrados, nunca imágenes guardadas.
- **Decidido: sin fotos de evidencia.** Solo embeddings cifrados. Si RRHH necesita verificar una marcación, usa el método alternativo (PIN o solicitud manual), no una foto.
- Borrado automático de plantillas al terminar la relación laboral.
- Transparencia: el empleado ve cuándo se usó su rostro.

## Calidad y equidad

- Metas a definir con datos del piloto: tasa de falsos rechazos (FRR) y falsas aceptaciones (FAR).
- Probar con distintos tonos de piel, iluminación y edades antes de activarlo para todos.
- Un falso rechazo nunca debe bloquear a alguien: siempre hay alternativa.

## Pruebas

- **Emulador:** sirve para la lógica (flujos, API, errores), pero su cámara no permite evaluar precisión ni prueba de vida real.
- **Teléfono real:** imprescindible para precisión, luz y liveness.
- **Pruebas automáticas:** compara embeddings con vectores fijos y umbrales; el backend se prueba con embeddings de ejemplo.

## Fases propuestas

1. ✅ Consentimiento, plantillas cifradas y PIN (backend, con pruebas unitarias y e2e en sql.js y Turso).
   Pendiente: la app debe mostrar el consentimiento y enviar los embeddings.
2. Enrolamiento con prueba de vida activa en teléfono real.
3. Marcación facial con umbral y fallback.
4. Piloto con 10–20 empleados, medir FRR/FAR.
5. Ajustes y decisión de liveness pasiva.

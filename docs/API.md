# API de MarcaYa

Base: `http://localhost:3001` en desarrollo. Todo es JSON. Excepto `POST /auth/login`, todas las rutas exigen `Authorization: Bearer <token>`.

## Roles

`employee`, `manager`, `hr`, `admin`. Las rutas de RRHH (`/employees*` y `GET /attendance`) solo admiten `hr` y `admin`; con otro rol responden `403`.

## Autenticación

### `POST /auth/login`

```json
{ "email": "ana@empresa.pe", "password": "..." }
```

Respuesta `200`: `{ "accessToken": "<jwt>", "employee": { ... } }`. El token dura 8 horas. Credenciales inválidas o empleado inactivo: `401`.

### `GET /auth/me`

Devuelve el empleado de la sesión. Lo usa la app para restaurar la sesión al abrirse. Token vencido: `401`.

## Empleados (RRHH y admin)

| Método y ruta | Descripción |
|---|---|
| `GET /employees` | Lista de empleados |
| `POST /employees` | Crea un empleado: `email`, `password` (mín. 8), `fullName`, `documentId?`, `role?` (por defecto `employee`) |
| `PATCH /employees/:id` | Actualiza datos; por ejemplo `{ "active": false }` desactiva y bloquea el ingreso |

Un correo repetido responde `409`. El hash de la clave nunca se devuelve.

## Marcaciones

### `POST /attendance`

El empleado marca su propia entrada o salida.

```json
{ "type": "in", "latitude": -12.0464, "longitude": -77.0428, "embedding": [128 números] }
```

El método depende de lo que llega:

| Campos | Método | Validación |
|---|---|---|
| solo `type` (y ubicación) | `app` | ninguna biométrica |
| `embedding` | `face` | comparación coseno contra las plantillas del empleado; `403` si no coincide o si no tiene rostro registrado |
| `pin` | `pin` | PIN de respaldo; `403` si es incorrecto |

No se pueden enviar `embedding` y `pin` juntos (`400`). Con geocerca activa, las marcaciones `app`, `face` y `pin` exigen ubicación dentro del radio.

- `type`: `in` o `out`.
- `latitude` y `longitude`: opcionales, pero se envían juntas (si no, `400`).
- La hora la fija el servidor.

Respuestas:

| Código | Cuándo |
|---|---|
| `201` | Marcación registrada (`type`, `occurredAt`, `method`, `latitude`, `longitude`) |
| `400` | Datos inválidos |
| `403` | Geocerca activa y no hay ubicación, o está fuera del radio |
| `409` | La secuencia no corresponde (entrada sin salida previa, o salida sin entrada) |

### `GET /attendance/today`

Estado del día del empleado: `{ events, checkedIn, nextAction, workedSeconds }`. Si hay una entrada abierta, `workedSeconds` cuenta hasta el momento de la consulta.

### `GET /attendance/me?from=AAAA-MM-DD&to=AAAA-MM-DD`

Marcaciones propias en un rango de días locales. Sin parámetros, devuelve hoy.

### `GET /attendance?from=&to=&employeeId=` (RRHH y admin)

Marcaciones de todos o de un empleado, con `employeeName`. El rango máximo es de 62 días; fechas inválidas o rango invertido responden `400`.

## Dispositivos y notificaciones push

Requieren la configuración de Firebase descrita en [FCM.md](FCM.md). Sin credenciales, los envíos responden `503`.

| Método y ruta | Rol | Descripción |
|---|---|---|
| `POST /devices` | cualquiera | Registra el token FCM del dispositivo: `{ "token": "<token>", "platform": "android" }`. Responde `204`. Si el token ya existía (aunque fuera de otro empleado) se reasigna al actual |
| `DELETE /devices/:token` | cualquiera | Quita el dispositivo del empleado. `204` |
| `POST /notifications/test` | cualquiera | Envía una notificación de prueba a los dispositivos propios. Responde `{ "devices", "sent", "failed" }` |
| `POST /notifications/send` | `hr`, `admin` | `{ "employeeId", "title", "body" }`: envía a todos los dispositivos de un empleado. Otros roles: `403` |

Los tokens que FCM rechaza como inválidos se eliminan automáticamente tras el envío.

## Reconocimiento facial (propio empleado)

Solo el empleado gestiona su propio rostro. Nunca se reciben ni guardan imágenes: el teléfono envía embeddings.

| Método y ruta | Descripción |
|---|---|
| `GET /face/status` | `{ currentConsentVersion, consented, consentVersion, templates, pinSet }` |
| `POST /face/consent` | `{ "version": "2026-11-v1" }`. Debe ser la versión vigente (`409` si no). Requerido antes de inscribirse |
| `POST /face/enroll` | `{ "embeddings": [[...128 números], ...], "pin": "1234" }`. Entre 3 y 5 embeddings; reemplaza los anteriores y define el PIN de respaldo (4–6 dígitos, guardado con hash). `403` sin consentimiento vigente |
| `DELETE /face/enroll` | Revoca el consentimiento y borra las plantillas (cancelación). El PIN se conserva |

Los embeddings se guardan cifrados con AES-256-GCM usando `FACE_ENCRYPTION_KEY` (32 bytes en base64). Sin esa variable, el enrolamiento responde `503`. La dimensión esperada es `FACE_EMBEDDING_DIM` (128 por defecto).

## Reglas

- **Días en hora de Lima:** los límites de cada día usan `APP_TZ_OFFSET_MINUTES` (por defecto `-300`).
- **Una sola marcación a la vez por empleado:** las peticiones simultáneas se serializan, así que dos toques seguidos no duplican.
- **Geocerca:** se activa definiendo `OFFICE_LAT` y `OFFICE_LNG` (radio `OFFICE_RADIUS_M`, por defecto 150 m). Solo aplica a marcaciones hechas desde la app; los futuros terminales de la oficina no la usan.
- **Método de la marcación:** cada evento guarda `method` (`app` hoy; `face`, `fingerprint`, `pin`, `qr`, `manual` reservados) y `deviceId`, para integrar rostro y dispositivos IoT sin cambiar el modelo.

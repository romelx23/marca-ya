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
{ "type": "in", "latitude": -12.0464, "longitude": -77.0428 }
```

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

## Reglas

- **Días en hora de Lima:** los límites de cada día usan `APP_TZ_OFFSET_MINUTES` (por defecto `-300`).
- **Una sola marcación a la vez por empleado:** las peticiones simultáneas se serializan, así que dos toques seguidos no duplican.
- **Geocerca:** se activa definiendo `OFFICE_LAT` y `OFFICE_LNG` (radio `OFFICE_RADIUS_M`, por defecto 150 m). Solo aplica a marcaciones hechas desde la app; los futuros terminales de la oficina no la usan.
- **Método de la marcación:** cada evento guarda `method` (`app` hoy; `face`, `fingerprint`, `pin`, `qr`, `manual` reservados) y `deviceId`, para integrar rostro y dispositivos IoT sin cambiar el modelo.

# Sistema de diseño MarcaYa

Fuente: prototipo "MarcaYa: app de asistencia" (Claude Design). Oscuro es el tema principal; el claro usa los mismos colores de marca.
La app Flutter y el panel Vue comparten estos tokens. Si cambias uno, cámbialo en ambos sitios.

| Token | Oscuro | Claro | Flutter (`AppPalette` / `AppColors`) | Panel (`admin/src/style.css`) |
|---|---|---|---|---|
| Marca · índigo | `#6C63FF` | `#6C63FF` | `AppColors.indigo` | `--primary` (`oklch(.62 .2 277)` oscuro / `oklch(.55 .22 277)` claro) |
| Marca · menta | `#4EE3B5` | `#4EE3B5` | `AppColors.mint` | `--chart-1` |
| Fondo | `#0A0B14` | `#EEF0FB` | `palette.bg` | `--background` |
| Resplandor del fondo | índigo 14 % sobre el fondo | `#F8F9FF` | `palette.glow` | `body` (radial-gradient) |
| Texto atenuado | `#9A9CB5` | `#6B6E8A` | `palette.textMuted` | `--muted-foreground` |
| Tarjeta (degradado) | blanco 6 % → 2 % | `#FFFFFF` → `#F7F8FF` + sombra | `palette.cardTop/cardBottom/cardShadow` | `[data-slot=card]` |
| Borde | blanco 7 % | índigo 10 % | `palette.border` | `--border` |
| Campo | blanco 5 % | `#FFFFFF` | `palette.fieldFill` | `[data-slot=input]` |
| Pista del anillo | blanco 6 % | índigo 10 % | `palette.track` | — |

## Reglas
- Degradados suaves en 135° (arriba-izquierda → abajo-derecha): botones índigo `#8B84FF → #5B52F0`, botón de marcar menta `#7CF5D2 → #3FD9AB`, avatares y logo índigo → menta.
- Resplandor (sombra de color) bajo los botones principales; en claro, sombras suaves azul marino (`#282C64` al 8 %).
- Radios: tarjetas 18–20 px, campos y botones 14–16 px, avatares circulares.
- Segundos del reloj en menta; estados positivos ("En turno") en menta.
- Tipografía: Manrope en la app, Geist en el panel (pendiente unificar).
- Movimiento: duraciones 200 / 450 / 900 ms con `easeOutCubic` (`Motion` en Flutter).

## Selección de tema
- Flutter: `ThemeMode.system` por defecto; el botón de tema alterna (no se guarda entre sesiones todavía).
- Panel: se guarda en `localStorage` (`marcaya.theme`); sin valor usa el del sistema.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores de marca: iguales en modo oscuro y claro.
class AppColors {
  static const indigo = Color(0xFF6C63FF);
  static const mint = Color(0xFF4EE3B5);
}

class Motion {
  static const fast = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 450);
  static const slow = Duration(milliseconds: 900);
  static const curve = Curves.easeOutCubic;
}

/// Tokens que cambian con el tema. Los mismos nombres existen como variables CSS en el panel (admin/src/style.css).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.glow,
    required this.textMuted,
    required this.cardTop,
    required this.cardBottom,
    required this.border,
    required this.fieldFill,
    required this.track,
    required this.cardShadow,
  });

  final Color bg;

  /// Color del resplandor del centro del fondo.
  final Color glow;
  final Color textMuted;
  final Color cardTop;
  final Color cardBottom;
  final Color border;
  final Color fieldFill;

  /// Pista del anillo de progreso.
  final Color track;
  final List<BoxShadow> cardShadow;

  static final dark = AppPalette(
    bg: const Color(0xFF0A0B14),
    glow: Color.alphaBlend(
      AppColors.indigo.withValues(alpha: .14),
      const Color(0xFF0A0B14),
    ),
    textMuted: const Color(0xFF9A9CB5),
    cardTop: Colors.white.withValues(alpha: .06),
    cardBottom: Colors.white.withValues(alpha: .02),
    border: Colors.white.withValues(alpha: .07),
    fieldFill: Colors.white.withValues(alpha: .05),
    track: Colors.white.withValues(alpha: .06),
    cardShadow: const [],
  );

  static final light = AppPalette(
    bg: const Color(0xFFEEF0FB),
    glow: const Color(0xFFF8F9FF),
    textMuted: const Color(0xFF6B6E8A),
    cardTop: Colors.white,
    cardBottom: const Color(0xFFF7F8FF),
    border: AppColors.indigo.withValues(alpha: .10),
    fieldFill: Colors.white,
    track: AppColors.indigo.withValues(alpha: .10),
    cardShadow: [
      BoxShadow(
        color: const Color(0xFF282C64).withValues(alpha: .08),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      cardTop: Color.lerp(cardTop, other.cardTop, t)!,
      cardBottom: Color.lerp(cardBottom, other.cardBottom, t)!,
      border: Color.lerp(border, other.border, t)!,
      fieldFill: Color.lerp(fieldFill, other.fieldFill, t)!,
      track: Color.lerp(track, other.track, t)!,
      cardShadow: t < .5 ? cardShadow : other.cardShadow,
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

ThemeData _build(Brightness brightness, AppPalette palette) {
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  final isDark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.indigo,
        brightness: brightness,
      ).copyWith(
        primary: AppColors.indigo,
        secondary: isDark ? AppColors.mint : const Color(0xFF1FB88E),
        surface: isDark ? const Color(0xFF14162A) : Colors.white,
      );
  return base.copyWith(
    scaffoldBackgroundColor: palette.bg,
    colorScheme: scheme,
    textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: isDark ? Colors.white : const Color(0xFF14162A),
      displayColor: isDark ? Colors.white : const Color(0xFF14162A),
    ),
    extensions: [palette],
  );
}

ThemeData buildDarkTheme() => _build(Brightness.dark, AppPalette.dark);
ThemeData buildLightTheme() => _build(Brightness.light, AppPalette.light);

/// Modo de tema elegido. Por defecto sigue al sistema; no se guarda entre sesiones.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: 'Cambiar tema',
      icon: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        color: context.palette.textMuted,
      ),
      onPressed: () => ref.read(themeModeProvider.notifier).state = isDark
          ? ThemeMode.light
          : ThemeMode.dark,
    );
  }
}

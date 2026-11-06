import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../application/attendance_controller.dart';
import '../data/attendance_repository.dart';

const _workday = Duration(hours: 8);
const _weekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];
const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String _dateLabel(DateTime d) {
  final w = _weekdays[d.weekday - 1];
  return '${w[0].toUpperCase()}${w.substring(1)}, ${d.day} de ${_months[d.month - 1]}';
}

String _clock(int seconds) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(seconds ~/ 3600)}:${two(seconds % 3600 ~/ 60)}:${two(seconds % 60)}';
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );
  Timer? _tick;
  bool _busy = false;

  @override
  void dispose() {
    _tick?.cancel();
    _ring.dispose();
    super.dispose();
  }

  /// El reloj solo corre mientras hay una entrada abierta.
  void _syncTicker(bool running) {
    if (running && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running) {
      _tick?.cancel();
      _tick = null;
    }
  }

  Future<void> _mark() async {
    if (_busy) return;
    setState(() => _busy = true);
    final sweep = _ring.forward(from: 0);
    final error = await ref.read(attendanceControllerProvider.notifier).mark();
    await sweep;
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(attendanceControllerProvider);
    _syncTicker(day.valueOrNull?.checkedIn ?? false);
    final employee = ref.watch(authControllerProvider).valueOrNull?.employee;
    final name = employee?.firstName ?? '';
    final fullName = employee?.fullName ?? '';
    final p = context.palette;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1.1,
            colors: [p.glow, p.bg],
          ),
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dateLabel(DateTime.now()),
                      style: TextStyle(color: p.textMuted),
                    ).animate().fadeIn(duration: Motion.medium),
                    Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Hola, $name',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const ThemeToggleButton(),
                            _Avatar(fullName),
                            IconButton(
                              tooltip: 'Cerrar sesión',
                              icon: Icon(Icons.logout, color: p.textMuted),
                              onPressed: () => ref
                                  .read(authControllerProvider.notifier)
                                  .logout(),
                            ),
                          ],
                        )
                        .animate()
                        .fadeIn(duration: Motion.medium)
                        .slideY(begin: .2, curve: Motion.curve),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: day.when(
                            loading: () => const CircularProgressIndicator(),
                            error: (e, _) => _LoadError(
                              message: e is ApiException
                                  ? e.message
                                  : 'No se pudo cargar tu jornada',
                              onRetry: () => ref
                                  .read(attendanceControllerProvider.notifier)
                                  .reload(),
                            ),
                            data: _buildMarker,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarker(AttendanceDay day) {
    final p = context.palette;
    final worked = day.workedAt(DateTime.now());
    final dayProgress = (worked / _workday.inSeconds).clamp(0.0, 1.0);
    final firstIn = day.firstIn;
    final remaining = _workday.inSeconds - worked;
    final clock = _clock(worked);
    final base = clock.substring(0, clock.length - 2); // "HH:MM:"
    final seconds = clock.substring(clock.length - 2);
    final colors = day.checkedIn
        ? const [Color(0xFF7CF5D2), Color(0xFF3FD9AB)]
        : const [Color(0xFF8B84FF), Color(0xFF5B52F0)];
    final glow = day.checkedIn ? AppColors.mint : AppColors.indigo;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _busy ? null : _mark,
          child: AnimatedBuilder(
            animation: _ring,
            builder: (context, child) => CustomPaint(
              painter: _RingPainter(_busy ? _ring.value : dayProgress, p.track),
              child: Container(
                width: 260,
                height: 260,
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: Motion.medium,
                  curve: Motion.curve,
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: glow.withValues(alpha: .35),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    day.checkedIn ? 'Marcar salida' : 'Marcar entrada',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF06231B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ).animate().scale(duration: Motion.slow, curve: Curves.elasticOut),
        const SizedBox(height: 28),
        Text(
          'HORAS TRABAJADAS HOY',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.5,
            color: p.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: base),
              TextSpan(
                text: seconds,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          key: const Key('worked-clock'),
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          remaining > 0
              ? 'Faltan ${_short(remaining)} de ${_workday.inHours}h'
              : 'Jornada completa',
          style: TextStyle(color: p.textMuted),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _StatCard('Entrada', firstIn == null ? '—' : _hm(firstIn)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                'Salida est.',
                firstIn == null ? '—' : _hm(firstIn.add(_workday)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                'Estado',
                day.checkedIn
                    ? 'En turno'
                    : (worked > 0 ? 'Salió' : 'Sin marcar'),
                valueColor: day.checkedIn
                    ? Theme.of(context).colorScheme.secondary
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _short(int seconds) =>
    '${seconds ~/ 3600}h ${(seconds % 3600 ~/ 60).toString().padLeft(2, '0')}m';

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, {this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.cardTop, p.cardBottom],
        ),
        border: Border.all(color: p.border),
        boxShadow: p.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: p.textMuted)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join();
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B84FF), Color(0xFF4EE3B5)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: .15),
          width: 2,
        ),
      ),
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFFF6B6B)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t, this.trackColor);
  final double t;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..color = trackColor;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [Color(0xFF6C63FF), Color(0xFF5AA9F0), Color(0xFF4EE3B5)],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect);
    final r = rect.deflate(7);
    canvas.drawArc(r, 0, math.pi * 2, false, track);
    if (t > 0) {
      canvas.drawArc(r, -math.pi / 2, math.pi * 2 * t, false, arc);
      // Perilla luminosa al final del progreso.
      final a = -math.pi / 2 + math.pi * 2 * t;
      final knob = r.center + Offset(math.cos(a), math.sin(a)) * r.width / 2;
      canvas.drawCircle(
        knob,
        13,
        Paint()
          ..color = AppColors.mint.withValues(alpha: .35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(knob, 8, Paint()..color = const Color(0xFFE8FFF7));
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.t != t || old.trackColor != trackColor;
}
